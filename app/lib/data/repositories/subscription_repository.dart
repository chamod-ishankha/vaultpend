import 'package:isar_community/isar.dart';

import '../../core/api/vaultspend_api.dart';

import '../models/subscription.dart';

class SubscriptionRepository {
  SubscriptionRepository(
    this._isar,
    this._userId, {
    this.api,
    this.accessToken,
  });

  final Isar _isar;
  final String _userId;
  final VaultSpendApi? api;
  final String? accessToken;

  bool get _canSync =>
      api != null && accessToken != null && accessToken!.isNotEmpty;

  Future<List<Subscription>> getAll() async {
    await _pullFromRemoteIfAvailable();
    return _isar.subscriptions
        .filter()
        .userIdEqualTo(_userId)
        .sortByNextBillingDate()
        .findAll();
  }

  Future<void> _pullFromRemoteIfAvailable() async {
    if (!_canSync) return;
    try {
      final remoteItems = await api!.listSubscriptions(accessToken!);
      final local = await _isar.subscriptions
          .filter()
          .userIdEqualTo(_userId)
          .findAll();
      final localByRemoteId = <String, Subscription>{
        for (final item in local)
          if (item.remoteId != null && item.remoteId!.isNotEmpty)
            item.remoteId!: item,
      };

      final seenRemoteIds = <String>{};
      final upserts = <Subscription>[];
      for (final remote in remoteItems) {
        seenRemoteIds.add(remote.id);
        final existing = localByRemoteId[remote.id];
        final target = existing ?? Subscription()
          ..userId = _userId;
        target.remoteId = remote.id;
        target.name = remote.name;
        target.amount = remote.amount;
        target.currency = remote.currency;
        target.cycle = remote.cycle;
        target.nextBillingDate = remote.nextBillingDate.toLocal();
        target.isTrial = remote.isTrial;
        target.trialEndsAt = remote.trialEndsAt?.toLocal();
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
          await _isar.subscriptions.putAll(upserts);
        }
        if (staleIds.isNotEmpty) {
          await _isar.subscriptions.deleteAll(staleIds);
        }
      });
    } catch (_) {
      // Keep local-only behavior if sync is unavailable.
    }
  }

  Future<Subscription?> getById(int id) async {
    final s = await _isar.subscriptions.get(id);
    if (s == null || s.userId != _userId) return null;
    return s;
  }

  Future<int> put(Subscription s) async {
    s.userId = _userId;
    final localId = await _isar.writeTxn(() => _isar.subscriptions.put(s));
    if (!_canSync) return localId;

    try {
      final remoteId = s.remoteId;
      final remote = (remoteId == null || remoteId.isEmpty)
          ? await api!.createSubscription(
              accessToken!,
              name: s.name,
              amount: s.amount,
              currency: s.currency,
              cycle: s.cycle,
              nextBillingDate: s.nextBillingDate,
              isTrial: s.isTrial,
              trialEndsAt: s.trialEndsAt,
            )
          : await api!.updateSubscription(
              accessToken!,
              remoteId,
              name: s.name,
              amount: s.amount,
              currency: s.currency,
              cycle: s.cycle,
              nextBillingDate: s.nextBillingDate,
              isTrial: s.isTrial,
              trialEndsAt: s.trialEndsAt,
            );

      s.remoteId = remote.id;
      s.name = remote.name;
      s.amount = remote.amount;
      s.currency = remote.currency;
      s.cycle = remote.cycle;
      s.nextBillingDate = remote.nextBillingDate.toLocal();
      s.isTrial = remote.isTrial;
      s.trialEndsAt = remote.trialEndsAt?.toLocal();
      await _isar.writeTxn(() => _isar.subscriptions.put(s));
    } catch (_) {
      // Local-first: sync can retry on next refresh/action.
    }

    return localId;
  }

  Future<void> delete(int id) async {
    final s = await _isar.subscriptions.get(id);
    if (s == null || s.userId != _userId) return;

    final remoteId = s.remoteId;
    await _isar.writeTxn(() => _isar.subscriptions.delete(id));

    if (!_canSync || remoteId == null || remoteId.isEmpty) return;
    try {
      await api!.deleteSubscription(accessToken!, remoteId);
    } catch (_) {
      // Local-first: keep local deletion even if remote is unavailable.
    }
  }
}
