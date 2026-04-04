import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:isar_community/isar.dart';

import '../../core/logging/sync_incident_service.dart';
import '../../core/network/network_guard.dart';
import '../models/category.dart';

final _syncIncidentService = SyncIncidentService();
const _remoteSyncTimeout = Duration(seconds: 2);

class CategoryRepository {
  CategoryRepository(
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
    return firestore!.collection('users').doc(_userId).collection('categories');
  }

  Future<List<Category>> getAll() async {
    await _pullFromRemoteIfAvailable();
    await _ensureDefaultCategoriesIfEmpty();
    return _isar.categorys
        .filter()
        .userIdEqualTo(_userId)
        .sortByName()
        .findAll();
  }

  Future<void> _pullFromRemoteIfAvailable() async {
    if (!_canSync) return;
    if (shouldBypassCloudSync()) return;
    if (!await hasNetworkConnection()) return;
    try {
      final remote = await _remoteCollection.get().timeout(_remoteSyncTimeout);
      final local = await _isar.categorys
          .filter()
          .userIdEqualTo(_userId)
          .findAll();

      final byRemoteId = <String, Category>{
        for (final item in local)
          if (item.remoteId != null && item.remoteId!.isNotEmpty)
            item.remoteId!: item,
      };

      final seenRemoteIds = <String>{};
      final upserts = <Category>[];
      for (final doc in remote.docs) {
        final id = doc.id;
        final data = doc.data();
        seenRemoteIds.add(id);
        final existing = byRemoteId[id];
        final target = existing ?? Category()
          ..userId = _userId;
        target.remoteId = id;
        target.name = (data['name'] as String?)?.trim().isNotEmpty == true
            ? (data['name'] as String)
            : 'Unnamed';
        target.description = (data['description'] as String?)?.trim();
        target.iconKey = data['icon_key'] as String?;
        target.color = data['color'] as String?;
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
          await _isar.categorys.putAll(upserts);
        }
        if (staleIds.isNotEmpty) {
          await _isar.categorys.deleteAll(staleIds);
        }
      });
      markCloudSyncSuccess();
    } catch (error) {
      markCloudSyncFailure();
      await _syncIncidentService.add(
        entity: 'category',
        operation: 'pull',
        stage: '_pullFromRemoteIfAvailable',
        error: error,
      );
      // Keep local-only behavior if sync is unavailable.
    }
  }

  Future<void> _ensureDefaultCategoriesIfEmpty() async {
    final n = await _isar.categorys.filter().userIdEqualTo(_userId).count();
    if (n > 0) return;
    final defaults = [
      Category()
        ..userId = _userId
        ..name = 'Food',
      Category()
        ..userId = _userId
        ..name = 'Utilities',
      Category()
        ..userId = _userId
        ..name = 'Development',
    ];

    await _isar.writeTxn(() async {
      await _isar.categorys.putAll(defaults);
    });

    if (!_canSync) return;
    if (shouldBypassCloudSync()) return;
    if (!await hasNetworkConnection()) return;
    for (final item in defaults) {
      try {
        final remote = await _remoteCollection
            .add({
              'name': item.name,
              'description': item.description,
              'icon_key': item.iconKey,
              'color': item.color,
              'updated_at': FieldValue.serverTimestamp(),
            })
            .timeout(_remoteSyncTimeout);
        item.remoteId = remote.id;
        await _isar.writeTxn(() => _isar.categorys.put(item));
        markCloudSyncSuccess();
      } catch (error) {
        markCloudSyncFailure();
        await _syncIncidentService.add(
          entity: 'category',
          operation: 'default_seed_push',
          stage: '_ensureDefaultCategoriesIfEmpty',
          error: error,
        );
      }
    }
  }

  Future<Category?> getById(int id) async {
    final c = await _isar.categorys.get(id);
    if (c == null || c.userId != _userId) return null;
    return c;
  }

  /// Whether [trimmedName] is unused for this user (case-insensitive).
  /// When editing, pass [excludingId] so the current row does not conflict.
  Future<bool> isNameAvailable(String name, {int? excludingId}) async {
    final t = name.trim();
    if (t.isEmpty) return false;
    final lower = t.toLowerCase();
    final all = await _isar.categorys.filter().userIdEqualTo(_userId).findAll();
    for (final c in all) {
      if (excludingId != null && c.id == excludingId) continue;
      if (c.name.trim().toLowerCase() == lower) return false;
    }
    return true;
  }

  Future<int> put(Category c) {
    c.userId = _userId;
    return _putAndSync(c);
  }

  Future<int> _putAndSync(Category c) async {
    final localId = await _isar.writeTxn(() => _isar.categorys.put(c));
    if (!_canSync) return localId;
    if (shouldBypassCloudSync()) {
      await _syncIncidentService.add(
        entity: 'category',
        operation: 'put',
        stage: 'local_only_bypass',
        error: StateError('Cloud sync bypass active; saved locally.'),
      );
      return localId;
    }
    if (!await hasNetworkConnection()) {
      await _syncIncidentService.add(
        entity: 'category',
        operation: 'put',
        stage: 'local_only_offline',
        error: StateError('No network connection; saved locally.'),
      );
      return localId;
    }

    try {
      final remoteId = c.remoteId;
      if (remoteId == null || remoteId.isEmpty) {
        final doc = await _remoteCollection
            .add({
              'name': c.name,
              'description': c.description,
              'icon_key': c.iconKey,
              'color': c.color,
              'updated_at': FieldValue.serverTimestamp(),
            })
            .timeout(_remoteSyncTimeout);
        c.remoteId = doc.id;
      } else {
        await _remoteCollection
            .doc(remoteId)
            .set({
              'name': c.name,
              'description': c.description,
              'icon_key': c.iconKey,
              'color': c.color,
              'updated_at': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true))
            .timeout(_remoteSyncTimeout);
      }
      await _isar.writeTxn(() => _isar.categorys.put(c));
      markCloudSyncSuccess();
    } catch (error) {
      markCloudSyncFailure();
      await _syncIncidentService.add(
        entity: 'category',
        operation: 'put',
        stage: '_putAndSync',
        error: error,
      );
    }

    return localId;
  }

  Future<void> delete(int id) async {
    final c = await _isar.categorys.get(id);
    if (c == null || c.userId != _userId) return;

    final remoteId = c.remoteId;
    await _isar.writeTxn(() => _isar.categorys.delete(id));

    if (!_canSync || remoteId == null || remoteId.isEmpty) return;
    if (shouldBypassCloudSync()) {
      await _syncIncidentService.add(
        entity: 'category',
        operation: 'delete',
        stage: 'local_only_bypass',
        error: StateError('Cloud sync bypass active; deleted locally.'),
      );
      return;
    }
    if (!await hasNetworkConnection()) {
      await _syncIncidentService.add(
        entity: 'category',
        operation: 'delete',
        stage: 'local_only_offline',
        error: StateError('No network connection; deleted locally.'),
      );
      return;
    }
    try {
      await _remoteCollection
          .doc(remoteId)
          .delete()
          .timeout(_remoteSyncTimeout);
      markCloudSyncSuccess();
    } catch (error) {
      markCloudSyncFailure();
      await _syncIncidentService.add(
        entity: 'category',
        operation: 'delete',
        stage: 'delete',
        error: error,
      );
      // Local-first: keep local deletion even if remote is unavailable.
    }
  }
}
