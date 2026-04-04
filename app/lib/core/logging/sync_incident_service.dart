import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kSyncIncidentStorageKey = 'vaultspend_sync_incidents_v1';
const _kSyncIncidentMaxEntries = 150;

class SyncIncidentEntry {
  const SyncIncidentEntry({
    required this.timestamp,
    required this.entity,
    required this.operation,
    required this.stage,
    required this.error,
  });

  final DateTime timestamp;
  final String entity;
  final String operation;
  final String stage;
  final String error;

  Map<String, dynamic> toJson() => {
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
      timestamp: parsed,
      entity: (json['entity'] as String?) ?? 'unknown',
      operation: (json['operation'] as String?) ?? 'unknown',
      stage: (json['stage'] as String?) ?? 'unknown',
      error: (json['error'] as String?) ?? 'Unknown error',
    );
  }
}

class SyncIncidentService {
  SyncIncidentService({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  final FlutterSecureStorage _storage;

  Future<List<SyncIncidentEntry>> readAll() async {
    final raw = await _storage.read(key: _kSyncIncidentStorageKey);
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
                (entry) => SyncIncidentEntry.fromJson(
                  Map<String, dynamic>.from(entry),
                ),
              )
              .toList()
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return entries;
    } catch (_) {
      return const [];
    }
  }

  Future<void> add({
    required String entity,
    required String operation,
    required String stage,
    required Object error,
  }) async {
    final current = await readAll();
    final updated = <SyncIncidentEntry>[
      SyncIncidentEntry(
        timestamp: DateTime.now(),
        entity: entity,
        operation: operation,
        stage: stage,
        error: error.toString(),
      ),
      ...current,
    ];

    if (updated.length > _kSyncIncidentMaxEntries) {
      updated.removeRange(_kSyncIncidentMaxEntries, updated.length);
    }

    final encoded = jsonEncode(updated.map((entry) => entry.toJson()).toList());
    await _storage.write(key: _kSyncIncidentStorageKey, value: encoded);
  }

  Future<void> clear() => _storage.delete(key: _kSyncIncidentStorageKey);
}
