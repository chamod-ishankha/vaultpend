import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../network/network_guard.dart';

const _kActivityLogGuestStorageKey = 'vaultspend_activity_log_guest_v2';
const _kActivityLogPendingStorageKey = 'vaultspend_activity_log_pending_v2';
const _kActivityLogMaxEntries = 200;
const _kActivityLogRemoteTimeout = Duration(seconds: 2);

class ActivityLogEntry {
  const ActivityLogEntry({
    this.id,
    required this.timestamp,
    required this.action,
    this.details,
  });

  final String? id;
  final DateTime timestamp;
  final String action;
  final String? details;

  Map<String, dynamic> toJson() => {
    if (id != null && id!.isNotEmpty) 'id': id,
    'timestamp': timestamp.toIso8601String(),
    'action': action,
    if (details != null && details!.isNotEmpty) 'details': details,
  };

  static ActivityLogEntry fromJson(Map<String, dynamic> json) {
    final rawTimestamp = json['timestamp'] as String?;
    final parsed = rawTimestamp == null
        ? DateTime.now()
        : DateTime.tryParse(rawTimestamp) ?? DateTime.now();

    return ActivityLogEntry(
      id: json['id'] as String?,
      timestamp: parsed,
      action: (json['action'] as String?) ?? 'Unknown activity',
      details: json['details'] as String?,
    );
  }
}

class ActivityLogPage {
  const ActivityLogPage({
    required this.entries,
    required this.hasMore,
    this.nextCursor,
  });

  final List<ActivityLogEntry> entries;
  final bool hasMore;
  final DateTime? nextCursor;
}

class ActivityLogService {
  ActivityLogService({
    FlutterSecureStorage? storage,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _storage =
           storage ??
           const FlutterSecureStorage(
             aOptions: AndroidOptions(encryptedSharedPreferences: true),
           );

  final FlutterSecureStorage _storage;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return _firestore.collection('users').doc(uid).collection('activity_logs');
  }

  Map<String, dynamic> _toFirestorePayload(ActivityLogEntry entry) {
    return {
      'timestamp': Timestamp.fromDate(entry.timestamp.toUtc()),
      'action': entry.action,
      'details': entry.details,
      'created_at': FieldValue.serverTimestamp(),
    };
  }

  ActivityLogEntry _fromFirestore(String id, Map<String, dynamic> json) {
    final raw = json['timestamp'];
    final timestamp = raw is Timestamp
        ? raw.toDate()
        : DateTime.tryParse(raw?.toString() ?? '') ?? DateTime.now();
    return ActivityLogEntry(
      id: id,
      timestamp: timestamp,
      action: (json['action'] as String?) ?? 'Unknown activity',
      details: json['details'] as String?,
    );
  }

  Future<List<Map<String, dynamic>>> _readPendingRaw() async {
    final raw = await _storage.read(key: _kActivityLogPendingStorageKey);
    if (raw == null || raw.trim().isEmpty) {
      return <Map<String, dynamic>>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <Map<String, dynamic>>[];
      }
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _writePendingRaw(List<Map<String, dynamic>> entries) async {
    if (entries.isEmpty) {
      await _storage.delete(key: _kActivityLogPendingStorageKey);
      return;
    }
    await _storage.write(
      key: _kActivityLogPendingStorageKey,
      value: jsonEncode(entries),
    );
  }

  Future<List<ActivityLogEntry>> _readGuestLocalAll() async {
    final raw = await _storage.read(key: _kActivityLogGuestStorageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }

      final entries =
          decoded
              .whereType<Map>()
              .map(
                (entry) =>
                    ActivityLogEntry.fromJson(Map<String, dynamic>.from(entry)),
              )
              .toList()
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return entries;
    } catch (_) {
      return const [];
    }
  }

  Future<void> _appendGuestLocal(ActivityLogEntry entry) async {
    final current = await _readGuestLocalAll();
    final updated = <ActivityLogEntry>[entry, ...current];
    if (updated.length > _kActivityLogMaxEntries) {
      updated.removeRange(_kActivityLogMaxEntries, updated.length);
    }
    await _storage.write(
      key: _kActivityLogGuestStorageKey,
      value: jsonEncode(updated.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> _enqueuePending(String uid, ActivityLogEntry entry) async {
    final pending = await _readPendingRaw();
    pending.insert(0, {...entry.toJson(), 'uid': uid});
    if (pending.length > _kActivityLogMaxEntries) {
      pending.removeRange(_kActivityLogMaxEntries, pending.length);
    }
    await _writePendingRaw(pending);
  }

  Future<List<ActivityLogEntry>> readAll() async {
    final uid = _uid;
    if (uid == null) {
      return _readGuestLocalAll();
    }
    final page = await readPage(pageSize: _kActivityLogMaxEntries);
    return page.entries;
  }

  Future<ActivityLogPage> readPage({
    int pageSize = 30,
    DateTime? startAfter,
  }) async {
    final uid = _uid;
    if (uid == null) {
      final local = await _readGuestLocalAll();
      final filtered = startAfter == null
          ? local
          : local
                .where((entry) => entry.timestamp.isBefore(startAfter))
                .toList();
      final hasMore = filtered.length > pageSize;
      final entries = hasMore ? filtered.take(pageSize).toList() : filtered;
      return ActivityLogPage(
        entries: entries,
        hasMore: hasMore,
        nextCursor: entries.isEmpty ? null : entries.last.timestamp,
      );
    }

    await syncPendingToDatabase();
    try {
      if (shouldBypassCloudSync()) {
        return const ActivityLogPage(entries: [], hasMore: false);
      }
      var query = _collection(
        uid,
      ).orderBy('timestamp', descending: true).limit(pageSize + 1);

      if (startAfter != null) {
        query = query.startAfter([Timestamp.fromDate(startAfter.toUtc())]);
      }

      final snapshot = await query.get().timeout(_kActivityLogRemoteTimeout);
      final docs = snapshot.docs;
      final hasMore = docs.length > pageSize;
      final usedDocs = hasMore ? docs.take(pageSize).toList() : docs;
      final entries = usedDocs
          .map((doc) => _fromFirestore(doc.id, doc.data()))
          .toList();
      markCloudSyncSuccess();
      return ActivityLogPage(
        entries: entries,
        hasMore: hasMore,
        nextCursor: entries.isEmpty ? null : entries.last.timestamp,
      );
    } catch (_) {
      markCloudSyncFailure();
      return const ActivityLogPage(entries: [], hasMore: false);
    }
  }

  Future<void> add({required String action, String? details}) async {
    final entry = ActivityLogEntry(
      timestamp: DateTime.now(),
      action: action,
      details: details,
    );
    final uid = _uid;

    if (uid == null) {
      await _appendGuestLocal(entry);
      return;
    }

    if (shouldBypassCloudSync()) {
      await _enqueuePending(uid, entry);
      return;
    }

    try {
      await _collection(
        uid,
      ).add(_toFirestorePayload(entry)).timeout(_kActivityLogRemoteTimeout);
      markCloudSyncSuccess();
    } catch (_) {
      markCloudSyncFailure();
      await _enqueuePending(uid, entry);
    }
  }

  Future<void> syncPendingToDatabase() async {
    final uid = _uid;
    if (uid == null) {
      return;
    }
    if (shouldBypassCloudSync()) {
      return;
    }
    if (!await hasNetworkConnection()) {
      return;
    }

    final pending = await _readPendingRaw();
    if (pending.isEmpty) {
      return;
    }

    final forCurrentUser =
        pending.where((item) => item['uid'] == uid).toList(growable: false)
          ..sort((a, b) {
            final left =
                DateTime.tryParse(a['timestamp']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final right =
                DateTime.tryParse(b['timestamp']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return left.compareTo(right);
          });

    if (forCurrentUser.isEmpty) {
      return;
    }

    try {
      for (final item in forCurrentUser) {
        final entry = ActivityLogEntry.fromJson(item);
        await _collection(
          uid,
        ).add(_toFirestorePayload(entry)).timeout(_kActivityLogRemoteTimeout);
      }
      markCloudSyncSuccess();

      final remaining = pending.where((item) => item['uid'] != uid).toList();
      await _writePendingRaw(remaining);
    } catch (_) {
      markCloudSyncFailure();
      // Keep pending entries for next reconnect attempt.
    }
  }

  Future<void> clear() async {
    final uid = _uid;
    if (uid == null) {
      await _storage.delete(key: _kActivityLogGuestStorageKey);
      return;
    }

    try {
      while (true) {
        final page = await _collection(uid)
            .orderBy('timestamp', descending: true)
            .limit(200)
            .get()
            .timeout(_kActivityLogRemoteTimeout);
        if (page.docs.isEmpty) {
          break;
        }
        final batch = _firestore.batch();
        for (final doc in page.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit().timeout(_kActivityLogRemoteTimeout);
        if (page.docs.length < 200) {
          break;
        }
      }
    } catch (_) {
      // Remote clear can be retried later.
    }

    final pending = await _readPendingRaw();
    final remaining = pending.where((item) => item['uid'] != uid).toList();
    await _writePendingRaw(remaining);
  }
}
