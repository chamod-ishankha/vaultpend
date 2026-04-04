import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kActivityLogStorageKey = 'vaultspend_activity_log_v1';
const _kActivityLogMaxEntries = 200;

class ActivityLogEntry {
  const ActivityLogEntry({
    required this.timestamp,
    required this.action,
    this.details,
  });

  final DateTime timestamp;
  final String action;
  final String? details;

  Map<String, dynamic> toJson() => {
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
      timestamp: parsed,
      action: (json['action'] as String?) ?? 'Unknown activity',
      details: json['details'] as String?,
    );
  }
}

class ActivityLogService {
  ActivityLogService({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  final FlutterSecureStorage _storage;

  Future<List<ActivityLogEntry>> readAll() async {
    final raw = await _storage.read(key: _kActivityLogStorageKey);
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

  Future<void> add({required String action, String? details}) async {
    final current = await readAll();
    final updated = <ActivityLogEntry>[
      ActivityLogEntry(
        timestamp: DateTime.now(),
        action: action,
        details: details,
      ),
      ...current,
    ];

    if (updated.length > _kActivityLogMaxEntries) {
      updated.removeRange(_kActivityLogMaxEntries, updated.length);
    }

    final encoded = jsonEncode(updated.map((entry) => entry.toJson()).toList());
    await _storage.write(key: _kActivityLogStorageKey, value: encoded);
  }

  Future<void> clear() => _storage.delete(key: _kActivityLogStorageKey);
}
