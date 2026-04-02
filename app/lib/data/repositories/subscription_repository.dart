import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:isar_community/isar.dart';

import '../models/subscription.dart';

class SubscriptionRepository {
  SubscriptionRepository(
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
    return firestore!
        .collection('users')
        .doc(_userId)
        .collection('subscriptions');
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

  DateTime? _coerceNullableDate(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

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
      final remoteItems = await _remoteCollection.get();
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
      for (final doc in remoteItems.docs) {
        final remoteId = doc.id;
        final data = doc.data();
        seenRemoteIds.add(remoteId);
        final existing = localByRemoteId[remoteId];
        final target = existing ?? Subscription()
          ..userId = _userId;
        target.remoteId = remoteId;
        target.name = (data['name'] as String?)?.trim().isNotEmpty == true
            ? (data['name'] as String)
            : 'Subscription';
        target.amount = (data['amount'] as num?)?.toDouble() ?? 0;
        target.currency = (data['currency'] as String?) ?? 'USD';
        target.cycle = (data['cycle'] as String?) ?? 'monthly';
        target.nextBillingDate = _coerceDate(
          data['next_billing_date'],
          fallback: DateTime.now(),
        ).toLocal();
        target.isTrial = data['is_trial'] as bool? ?? false;
        target.trialEndsAt = _coerceNullableDate(
          data['trial_ends_at'],
        )?.toLocal();
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
      final payload = <String, dynamic>{
        'name': s.name,
        'amount': s.amount,
        'currency': s.currency,
        'cycle': s.cycle,
        'next_billing_date': Timestamp.fromDate(s.nextBillingDate.toUtc()),
        'is_trial': s.isTrial,
        'trial_ends_at': s.trialEndsAt == null
            ? null
            : Timestamp.fromDate(s.trialEndsAt!.toUtc()),
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (remoteId == null || remoteId.isEmpty) {
        final remote = await _remoteCollection.add(payload);
        s.remoteId = remote.id;
      } else {
        await _remoteCollection
            .doc(remoteId)
            .set(payload, SetOptions(merge: true));
      }
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
      await _remoteCollection.doc(remoteId).delete();
    } catch (_) {
      // Local-first: keep local deletion even if remote is unavailable.
    }
  }
}
