import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:isar_community/isar.dart';

import '../../core/logging/sync_incident_service.dart';
import '../models/category.dart';

import '../models/expense.dart';

final _syncIncidentService = SyncIncidentService();

class ExpenseRepository {
  ExpenseRepository(
    this._isar,
    this._userId, {
    this.firestore,
    this.cloudSyncEnabled = false,
  });

  final Isar _isar;
  final String _userId;
  final FirebaseFirestore? firestore;
  final bool cloudSyncEnabled;

  bool get _canSync => firestore != null && cloudSyncEnabled;

  CollectionReference<Map<String, dynamic>> get _remoteCollection {
    return firestore!.collection('users').doc(_userId).collection('expenses');
  }

  CollectionReference<Map<String, dynamic>> get _remoteCategories {
    return firestore!.collection('users').doc(_userId).collection('categories');
  }

  DateTime _coerceDate(Object? value, {required DateTime fallback}) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }
    return fallback;
  }

  Future<List<Expense>> getAll() async {
    await _pullFromRemoteIfAvailable();
    return _isar.expenses
        .filter()
        .userIdEqualTo(_userId)
        .sortByOccurredAtDesc()
        .findAll();
  }

  Future<void> _pullFromRemoteIfAvailable() async {
    if (!_canSync) return;
    try {
      final remoteItems = await _remoteCollection.get();
      final local = await _isar.expenses
          .filter()
          .userIdEqualTo(_userId)
          .findAll();
      final localByRemoteId = <String, Expense>{
        for (final item in local)
          if (item.remoteId != null && item.remoteId!.isNotEmpty)
            item.remoteId!: item,
      };

      final categories = await _isar.categorys
          .filter()
          .userIdEqualTo(_userId)
          .findAll();
      final localCategoryByRemoteId = <String, Category>{
        for (final c in categories)
          if (c.remoteId != null && c.remoteId!.isNotEmpty) c.remoteId!: c,
      };

      final seenRemoteIds = <String>{};
      final upserts = <Expense>[];
      for (final doc in remoteItems.docs) {
        final remoteId = doc.id;
        final data = doc.data();
        seenRemoteIds.add(remoteId);
        final existing = localByRemoteId[remoteId];
        final target = existing ?? Expense()
          ..userId = _userId;
        target.remoteId = remoteId;
        target.amount = (data['amount'] as num?)?.toDouble() ?? 0;
        target.currency = (data['currency'] as String?) ?? 'USD';
        target.occurredAt = _coerceDate(
          data['occurred_at'],
          fallback: existing?.occurredAt ?? DateTime.now(),
        ).toLocal();
        target.note = data['note'] as String?;
        target.isRecurring = data['is_recurring'] as bool? ?? false;
        final remoteCategoryId = data['category_remote_id'] as String?;
        target.categoryId = remoteCategoryId == null
            ? null
            : localCategoryByRemoteId[remoteCategoryId]?.id;
        upserts.add(target);
      }

      final staleIds = local
          .where(
            (item) =>
                item.remoteId != null && !seenRemoteIds.contains(item.remoteId),
          )
          .map((item) => item.id)
          .toList();

      await _isar.writeTxn(() async {
        if (upserts.isNotEmpty) {
          await _isar.expenses.putAll(upserts);
        }
        if (staleIds.isNotEmpty) {
          await _isar.expenses.deleteAll(staleIds);
        }
      });
    } catch (error) {
      await _syncIncidentService.add(
        entity: 'expense',
        operation: 'pull',
        stage: '_pullFromRemoteIfAvailable',
        error: error,
      );
      // Keep local-only behavior if sync is unavailable.
    }
  }

  Future<Expense?> getById(int id) async {
    final e = await _isar.expenses.get(id);
    if (e == null || e.userId != _userId) return null;
    return e;
  }

  Future<int> put(Expense e) async {
    e.userId = _userId;
    final localId = await _isar.writeTxn(() => _isar.expenses.put(e));
    if (!_canSync) return localId;

    try {
      String? remoteCategoryId;
      final localCategoryId = e.categoryId;
      if (localCategoryId != null) {
        final category = await _isar.categorys.get(localCategoryId);
        if (category != null && category.userId == _userId) {
          if (category.remoteId == null || category.remoteId!.isEmpty) {
            final remoteCategory = await _remoteCategories.add({
              'name': category.name,
              'icon_key': category.iconKey,
              'color': category.color,
              'updated_at': FieldValue.serverTimestamp(),
            });
            category.remoteId = remoteCategory.id;
            await _isar.writeTxn(() => _isar.categorys.put(category));
          }
          remoteCategoryId = category.remoteId;
        }
      }

      final remoteId = e.remoteId;
      final payload = <String, dynamic>{
        'category_remote_id': remoteCategoryId,
        'amount': e.amount,
        'currency': e.currency,
        'occurred_at': Timestamp.fromDate(e.occurredAt.toUtc()),
        'note': e.note,
        'is_recurring': e.isRecurring,
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (remoteId == null || remoteId.isEmpty) {
        final remote = await _remoteCollection.add(payload);
        e.remoteId = remote.id;
      } else {
        await _remoteCollection
            .doc(remoteId)
            .set(payload, SetOptions(merge: true));
      }
      await _isar.writeTxn(() => _isar.expenses.put(e));
    } catch (error) {
      await _syncIncidentService.add(
        entity: 'expense',
        operation: 'put',
        stage: 'put',
        error: error,
      );
      // Local-first: sync can retry on next refresh/action.
    }

    return localId;
  }

  Future<void> delete(int id) async {
    final e = await _isar.expenses.get(id);
    if (e == null || e.userId != _userId) return;

    final remoteId = e.remoteId;
    await _isar.writeTxn(() => _isar.expenses.delete(id));

    if (!_canSync || remoteId == null || remoteId.isEmpty) return;
    try {
      await _remoteCollection.doc(remoteId).delete();
    } catch (error) {
      await _syncIncidentService.add(
        entity: 'expense',
        operation: 'delete',
        stage: 'delete',
        error: error,
      );
      // Local-first: keep local deletion even if remote is unavailable.
    }
  }
}
