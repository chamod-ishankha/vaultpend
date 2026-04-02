import 'package:isar_community/isar.dart';

import '../../core/api/vaultspend_api.dart';

import '../models/category.dart';

class CategoryRepository {
  CategoryRepository(this._isar, this._userId, {this.api, this.accessToken});

  final Isar _isar;
  final String _userId;
  final VaultSpendApi? api;
  final String? accessToken;

  bool get _canSync =>
      api != null && accessToken != null && accessToken!.isNotEmpty;

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
    try {
      final remote = await api!.listCategories(accessToken!);
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
      for (final item in remote) {
        seenRemoteIds.add(item.id);
        final existing = byRemoteId[item.id];
        final target = existing ?? Category()
          ..userId = _userId;
        target.remoteId = item.id;
        target.name = item.name;
        target.iconKey = item.iconKey;
        target.color = item.color;
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
    } catch (_) {
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
    for (final item in defaults) {
      try {
        final remote = await api!.createCategory(
          accessToken!,
          name: item.name,
          iconKey: item.iconKey,
          color: item.color,
        );
        item.remoteId = remote.id;
        await _isar.writeTxn(() => _isar.categorys.put(item));
      } on ApiException catch (e) {
        if (e.statusCode == 409) {
          await _pullFromRemoteIfAvailable();
          break;
        }
      } catch (_) {}
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

    try {
      final remoteId = c.remoteId;
      final remote = (remoteId == null || remoteId.isEmpty)
          ? await api!.createCategory(
              accessToken!,
              name: c.name,
              iconKey: c.iconKey,
              color: c.color,
            )
          : await api!.updateCategory(
              accessToken!,
              remoteId,
              name: c.name,
              iconKey: c.iconKey,
              color: c.color,
            );
      c.remoteId = remote.id;
      c.name = remote.name;
      c.iconKey = remote.iconKey;
      c.color = remote.color;
      await _isar.writeTxn(() => _isar.categorys.put(c));
    } on ApiException catch (e) {
      if (e.statusCode == 409) {
        await _pullFromRemoteIfAvailable();
      }
    } catch (_) {}

    return localId;
  }

  Future<void> delete(int id) async {
    final c = await _isar.categorys.get(id);
    if (c == null || c.userId != _userId) return;

    final remoteId = c.remoteId;
    await _isar.writeTxn(() => _isar.categorys.delete(id));

    if (!_canSync || remoteId == null || remoteId.isEmpty) return;
    try {
      await api!.deleteCategory(accessToken!, remoteId);
    } catch (_) {
      // Local-first: keep local deletion even if remote is unavailable.
    }
  }
}
