import 'package:isar_community/isar.dart';

import '../models/category.dart';

class CategoryRepository {
  CategoryRepository(this._isar, this._userId);

  final Isar _isar;
  final String _userId;

  Future<List<Category>> getAll() async {
    await _ensureDefaultCategoriesIfEmpty();
    return _isar.categorys
        .filter()
        .userIdEqualTo(_userId)
        .sortByName()
        .findAll();
  }

  Future<void> _ensureDefaultCategoriesIfEmpty() async {
    final n =
        await _isar.categorys.filter().userIdEqualTo(_userId).count();
    if (n > 0) return;
    await _isar.writeTxn(() async {
      await _isar.categorys.putAll([
        Category()
          ..userId = _userId
          ..name = 'Food',
        Category()
          ..userId = _userId
          ..name = 'Utilities',
        Category()
          ..userId = _userId
          ..name = 'Development',
      ]);
    });
  }

  Future<Category?> getById(int id) async {
    final c = await _isar.categorys.get(id);
    if (c == null || c.userId != _userId) return null;
    return c;
  }

  /// Whether [trimmedName] is unused for this user (case-insensitive).
  /// When editing, pass [excludingId] so the current row does not conflict.
  Future<bool> isNameAvailable(
    String name, {
    int? excludingId,
  }) async {
    final t = name.trim();
    if (t.isEmpty) return false;
    final lower = t.toLowerCase();
    final all =
        await _isar.categorys.filter().userIdEqualTo(_userId).findAll();
    for (final c in all) {
      if (excludingId != null && c.id == excludingId) continue;
      if (c.name.trim().toLowerCase() == lower) return false;
    }
    return true;
  }

  Future<int> put(Category c) {
    c.userId = _userId;
    return _isar.writeTxn(() => _isar.categorys.put(c));
  }

  Future<void> delete(int id) async {
    final c = await _isar.categorys.get(id);
    if (c == null || c.userId != _userId) return;
    await _isar.writeTxn(() => _isar.categorys.delete(id));
  }
}
