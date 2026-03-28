import 'package:isar_community/isar.dart';

import '../models/subscription.dart';

class SubscriptionRepository {
  SubscriptionRepository(this._isar, this._userId);

  final Isar _isar;
  final String _userId;

  Future<List<Subscription>> getAll() => _isar.subscriptions
      .filter()
      .userIdEqualTo(_userId)
      .sortByNextBillingDate()
      .findAll();

  Future<Subscription?> getById(int id) async {
    final s = await _isar.subscriptions.get(id);
    if (s == null || s.userId != _userId) return null;
    return s;
  }

  Future<int> put(Subscription s) {
    s.userId = _userId;
    return _isar.writeTxn(() => _isar.subscriptions.put(s));
  }

  Future<void> delete(int id) async {
    final s = await _isar.subscriptions.get(id);
    if (s == null || s.userId != _userId) return;
    await _isar.writeTxn(() => _isar.subscriptions.delete(id));
  }
}
