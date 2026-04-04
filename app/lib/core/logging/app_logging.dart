import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'activity_log_service.dart';

final appLoggerProvider = Provider<Logger>((ref) => Logger('VaultSpend'));
final activityLogServiceProvider = Provider<ActivityLogService>(
  (ref) => ActivityLogService(),
);

var _loggingConfigured = false;

void configureAppLogging() {
  if (_loggingConfigured) {
    return;
  }
  _loggingConfigured = true;

  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    final buffer = StringBuffer()
      ..write('[${record.time.toIso8601String()}] ')
      ..write('${record.level.name.padRight(7)} ')
      ..write('${record.loggerName}: ')
      ..write(record.message);
    developer.log(
      buffer.toString(),
      name: record.loggerName,
      level: record.level.value,
      error: record.error,
      stackTrace: record.stackTrace,
    );
  });

  FlutterError.onError = (details) {
    Logger(
      'VaultSpend.Flutter',
    ).severe('framework_error', details.exception, details.stack);
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    Logger(
      'VaultSpend.Flutter',
    ).severe('unhandled_platform_error', error, stack);
    return true;
  };
}
