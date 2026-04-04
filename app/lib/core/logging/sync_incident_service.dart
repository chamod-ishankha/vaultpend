import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../network/network_guard.dart';

const _kSyncIncidentPendingStorageKey = 'vaultspend_sync_incidents_pending_v2';
const _kSyncIncidentMaxEntries = 150;
const _kSyncIncidentRemoteTimeout = Duration(seconds: 2);

class SyncIncidentEntry {
  const SyncIncidentEntry({
    this.id,
    required this.timestamp,
    required this.entity,
    required this.operation,
    required this.stage,
    required this.error,
  });

  final String? id;
  final DateTime timestamp;
  final String entity;
  final String operation;
  final String stage;
  final String error;

  Map<String, dynamic> toJson() => {
    if (id != null && id!.isNotEmpty) 'id': id,
    'timestamp': timestamp.toIso8601String(),
    'entity': entity,
    'operation': operation,
    'stage': stage,
    'error': error,
  };

  static SyncIncidentEntry fromJson(Map<String, dynamic> json) {
    final rawTimestamp = json['timestamp'] as String?;
    final parsed = rawTimestamp == null
        ? DateTime.now()
        : DateTime.tryParse(rawTimestamp) ?? DateTime.now();

    return SyncIncidentEntry(
      id: json['id'] as String?,
      timestamp: parsed,
      entity: (json['entity'] as String?) ?? 'unknown',
      operation: (json['operation'] as String?) ?? 'unknown',
      stage: (json['stage'] as String?) ?? 'unknown',
      error: (json['error'] as String?) ?? 'Unknown error',
    );
  }
}

class SyncIncidentPage {
  const SyncIncidentPage({
    required this.entries,
    required this.hasMore,
    this.nextCursor,
  });

  final List<SyncIncidentEntry> entries;
  final bool hasMore;
  final DateTime? nextCursor;
}

class SyncIncidentService {
  SyncIncidentService({
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
    return _firestore.collection('users').doc(uid).collection('sync_incidents');
  }

  Map<String, dynamic> _toFirestorePayload(SyncIncidentEntry entry) {
    return {
      'timestamp': Timestamp.fromDate(entry.timestamp.toUtc()),
      'entity': entry.entity,
      'operation': entry.operation,
      'stage': entry.stage,
      'error': entry.error,
      'created_at': FieldValue.serverTimestamp(),
    };
  }

  SyncIncidentEntry _fromFirestore(String id, Map<String, dynamic> json) {
    final raw = json['timestamp'];
    final timestamp = raw is Timestamp
        ? raw.toDate()
        : DateTime.tryParse(raw?.toString() ?? '') ?? DateTime.now();
    return SyncIncidentEntry(
      id: id,
      timestamp: timestamp,
      entity: (json['entity'] as String?) ?? 'unknown',
      operation: (json['operation'] as String?) ?? 'unknown',
      stage: (json['stage'] as String?) ?? 'unknown',
      error: (json['error'] as String?) ?? 'Unknown error',
    );
  }

  Future<List<Map<String, dynamic>>> _readPendingRaw() async {
    final raw = await _storage.read(key: _kSyncIncidentPendingStorageKey);
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
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _writePendingRaw(List<Map<String, dynamic>> entries) async {
    if (entries.isEmpty) {
      await _storage.delete(key: _kSyncIncidentPendingStorageKey);
      return;
    }

    await _storage.write(
      key: _kSyncIncidentPendingStorageKey,
      value: jsonEncode(entries),
    );
  }

  Future<void> _enqueuePending(String uid, SyncIncidentEntry entry) async {
    final current = await _readPendingRaw();
    current.insert(0, {...entry.toJson(), 'uid': uid});
    if (current.length > _kSyncIncidentMaxEntries) {
      current.removeRange(_kSyncIncidentMaxEntries, current.length);
    }
    await _writePendingRaw(current);
  }

  Future<List<SyncIncidentEntry>> readAll() async {
    final page = await readPage(pageSize: _kSyncIncidentMaxEntries);
    return page.entries;
  }

  Future<SyncIncidentPage> readPage({
    int pageSize = 30,
    DateTime? startAfter,
  }) async {
    final uid = _uid;
    if (uid == null) {
      return const SyncIncidentPage(entries: [], hasMore: false);
    }

    await syncPendingToDatabase();

    try {
      if (shouldBypassCloudSync()) {
        return const SyncIncidentPage(entries: [], hasMore: false);
      }
      var query = _collection(
        uid,
      ).orderBy('timestamp', descending: true).limit(pageSize + 1);
      if (startAfter != null) {
        query = query.startAfter([Timestamp.fromDate(startAfter.toUtc())]);
      }

      final snapshot = await query.get().timeout(_kSyncIncidentRemoteTimeout);
      final docs = snapshot.docs;
      final hasMore = docs.length > pageSize;
      final usedDocs = hasMore ? docs.take(pageSize).toList() : docs;
      final entries = usedDocs
          .map((doc) => _fromFirestore(doc.id, doc.data()))
          .toList();
      markCloudSyncSuccess();

      return SyncIncidentPage(
        entries: entries,
        hasMore: hasMore,
        nextCursor: entries.isEmpty ? null : entries.last.timestamp,
      );
    } catch (_) {
      markCloudSyncFailure();
      return const SyncIncidentPage(entries: [], hasMore: false);
    }
  }

  Future<void> add({
    required String entity,
    required String operation,
    required String stage,
    required Object error,
  }) async {
    final uid = _uid;
    if (uid == null) {
      return;
    }

    final entry = SyncIncidentEntry(
      timestamp: DateTime.now(),
      entity: entity,
      operation: operation,
      stage: stage,
      error: error.toString(),
    );

    if (shouldBypassCloudSync()) {
      await _enqueuePending(uid, entry);
      return;
    }

    try {
      await _collection(
        uid,
      ).add(_toFirestorePayload(entry)).timeout(_kSyncIncidentRemoteTimeout);
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
        pending.where((entry) => entry['uid'] == uid).toList(growable: false)
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
        final entry = SyncIncidentEntry.fromJson(item);
        await _collection(
          uid,
        ).add(_toFirestorePayload(entry)).timeout(_kSyncIncidentRemoteTimeout);
      }
      markCloudSyncSuccess();

      final remaining = pending.where((entry) => entry['uid'] != uid).toList();
      await _writePendingRaw(remaining);
    } catch (_) {
      markCloudSyncFailure();
      // Keep pending entries for a later reconnect.
    }
  }

  Future<void> clear() async {
    final uid = _uid;
    if (uid == null) {
      await _storage.delete(key: _kSyncIncidentPendingStorageKey);
      return;
    }

    try {
      while (true) {
        final page = await _collection(uid)
            .orderBy('timestamp', descending: true)
            .limit(200)
            .get()
            .timeout(_kSyncIncidentRemoteTimeout);
        if (page.docs.isEmpty) {
          break;
        }
        final batch = _firestore.batch();
        for (final doc in page.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit().timeout(_kSyncIncidentRemoteTimeout);
        if (page.docs.length < 200) {
          break;
        }
      }
    } catch (_) {
      // Keep remote items if clear fails.
    }

    final pending = await _readPendingRaw();
    final remaining = pending.where((entry) => entry['uid'] != uid).toList();
    await _writePendingRaw(remaining);
  }
}
