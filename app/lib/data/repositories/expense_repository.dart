import 'package:isar_community/isar.dart';

import '../../core/api/vaultspend_api.dart';
import '../models/category.dart';

import '../models/expense.dart';

class ExpenseRepository {
  ExpenseRepository(this._isar, this._userId, {this.api, this.accessToken});

  final Isar _isar;
  final String _userId;
  final VaultSpendApi? api;
  final String? accessToken;

  bool get _canSync =>
      api != null && accessToken != null && accessToken!.isNotEmpty;

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
      final remoteItems = await api!.listExpenses(accessToken!);
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
      for (final remote in remoteItems) {
        seenRemoteIds.add(remote.id);
        final existing = localByRemoteId[remote.id];
        final target = existing ?? Expense()
          ..userId = _userId;
        target.remoteId = remote.id;
        target.amount = remote.amount;
        target.currency = remote.currency;
        target.occurredAt = remote.occurredAt.toLocal();
        target.note = remote.note;
        target.isRecurring = remote.isRecurring;
        target.categoryId = remote.categoryId == null
            ? null
            : localCategoryByRemoteId[remote.categoryId!]?.id;
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
    } catch (_) {
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
            final remoteCategory = await api!.createCategory(
              accessToken!,
              name: category.name,
              iconKey: category.iconKey,
              color: category.color,
            );
            category.remoteId = remoteCategory.id;
            await _isar.writeTxn(() => _isar.categorys.put(category));
          }
          remoteCategoryId = category.remoteId;
        }
      }

      final remoteId = e.remoteId;
      final remote = (remoteId == null || remoteId.isEmpty)
          ? await api!.createExpense(
              accessToken!,
              categoryId: remoteCategoryId,
              amount: e.amount,
              currency: e.currency,
              occurredAt: e.occurredAt,
              note: e.note,
              isRecurring: e.isRecurring,
            )
          : await api!.updateExpense(
              accessToken!,
              remoteId,
              categoryId: remoteCategoryId,
              amount: e.amount,
              currency: e.currency,
              occurredAt: e.occurredAt,
              note: e.note,
              isRecurring: e.isRecurring,
            );

      e.remoteId = remote.id;
      e.amount = remote.amount;
      e.currency = remote.currency;
      e.occurredAt = remote.occurredAt.toLocal();
      e.note = remote.note;
      e.isRecurring = remote.isRecurring;
      await _isar.writeTxn(() => _isar.expenses.put(e));
    } catch (_) {
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
      await api!.deleteExpense(accessToken!, remoteId);
    } catch (_) {
      // Local-first: keep local deletion even if remote is unavailable.
    }
  }
}
