import 'package:isar_community/isar.dart';

import '../models/expense.dart';

class ExpenseRepository {
  ExpenseRepository(this._isar, this._userId);

  final Isar _isar;
  final String _userId;

  Future<List<Expense>> getAll() => _isar.expenses
      .filter()
      .userIdEqualTo(_userId)
      .sortByOccurredAtDesc()
      .findAll();

  Future<Expense?> getById(int id) async {
    final e = await _isar.expenses.get(id);
    if (e == null || e.userId != _userId) return null;
    return e;
  }

  Future<int> put(Expense e) {
    e.userId = _userId;
    return _isar.writeTxn(() => _isar.expenses.put(e));
  }

  Future<void> delete(int id) async {
    final e = await _isar.expenses.get(id);
    if (e == null || e.userId != _userId) return;
    await _isar.writeTxn(() => _isar.expenses.delete(id));
  }
}
