import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/expense.dart';
import '../../data/models/subscription.dart';

class SubscriptionReminderService {
  SubscriptionReminderService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _pluginAvailable = true;

  static const _payloadPrefix = 'vaultspend-renewal';
  static const _expensePayloadPrefix = 'vaultspend-recurring-expense';
  static final _dateTimeFmt = DateFormat('MMM d, yyyy h:mm a');

  static const _recurringOffsets = [Duration(hours: 48), Duration(hours: 24)];

  Future<void> initialize() async {
    if (_initialized || !_pluginAvailable) {
      return;
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      await _plugin.initialize(settings);

      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.requestNotificationsPermission();

      final iosPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );

      tz.initializeTimeZones();
      final localTzName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTzName));

      _initialized = true;
    } on MissingPluginException {
      _pluginAvailable = false;
    } on PlatformException {
      _pluginAvailable = false;
    }
  }

  Future<void> syncRenewalReminders(List<Subscription> subscriptions) async {
    await initialize();
    if (!_initialized || !_pluginAvailable) {
      return;
    }

    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final request in pending) {
        if (request.payload?.startsWith(_payloadPrefix) == true) {
          await _plugin.cancel(request.id);
        }
      }

      final now = DateTime.now();
      for (final subscription in subscriptions) {
        await _scheduleReminder(
          subscription: subscription,
          now: now,
          offset: const Duration(hours: 48),
          bucketLabel: '48h',
        );
        await _scheduleReminder(
          subscription: subscription,
          now: now,
          offset: const Duration(hours: 24),
          bucketLabel: '24h',
        );
      }
    } on MissingPluginException {
      _pluginAvailable = false;
    } on PlatformException {
      _pluginAvailable = false;
    }
  }

  Future<void> syncGlobalReminders({
    required List<Subscription> subscriptions,
    required List<Expense> expenses,
  }) async {
    await initialize();
    if (!_initialized || !_pluginAvailable) {
      return;
    }

    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final request in pending) {
        final payload = request.payload;
        if (payload?.startsWith(_payloadPrefix) == true ||
            payload?.startsWith(_expensePayloadPrefix) == true) {
          await _plugin.cancel(request.id);
        }
      }

      final now = DateTime.now();
      for (final subscription in subscriptions) {
        await _scheduleReminder(
          subscription: subscription,
          now: now,
          offset: const Duration(hours: 48),
          bucketLabel: '48h',
        );
        await _scheduleReminder(
          subscription: subscription,
          now: now,
          offset: const Duration(hours: 24),
          bucketLabel: '24h',
        );
      }

      final recurringExpenses = expenses.where((e) => e.isRecurring);
      for (final expense in recurringExpenses) {
        final nextOccurrence = _nextMonthlyOccurrence(expense.occurredAt, now);
        for (final offset in _recurringOffsets) {
          await _scheduleRecurringExpenseReminder(
            expense: expense,
            nextOccurrence: nextOccurrence,
            now: now,
            offset: offset,
          );
        }
      }
    } on MissingPluginException {
      _pluginAvailable = false;
    } on PlatformException {
      _pluginAvailable = false;
    }
  }

  Future<void> _scheduleReminder({
    required Subscription subscription,
    required DateTime now,
    required Duration offset,
    required String bucketLabel,
  }) async {
    final remaining = subscription.nextBillingDate.difference(now);
    if (remaining.isNegative || remaining.inSeconds == 0) {
      return;
    }

    final trigger = subscription.nextBillingDate.subtract(offset);
    if (!trigger.isAfter(now)) {
      final isCatchUpFor48h =
          bucketLabel == '48h' &&
          remaining.inHours > 24 &&
          remaining.inHours <= 48;
      final isCatchUpFor24h = bucketLabel == '24h' && remaining.inHours <= 24;
      if (isCatchUpFor48h || isCatchUpFor24h) {
        await _showNow(
          id: _notificationId(subscription.id, bucketLabel),
          title: 'Subscription renewal in $bucketLabel',
          body:
              '${subscription.name} renews on ${_formatDateTime(subscription.nextBillingDate)} (${subscription.currency} ${subscription.amount.toStringAsFixed(2)})',
          payload: '$_payloadPrefix:${subscription.id}:$bucketLabel',
        );
      }
      return;
    }

    await _schedule(
      id: _notificationId(subscription.id, bucketLabel),
      title: 'Subscription renewal in $bucketLabel',
      body:
          '${subscription.name} renews on ${_formatDateTime(subscription.nextBillingDate)} (${subscription.currency} ${subscription.amount.toStringAsFixed(2)})',
      trigger: trigger,
      payload: '$_payloadPrefix:${subscription.id}:$bucketLabel',
    );
  }

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime trigger,
    required String payload,
  }) async {
    final triggerTz = tz.TZDateTime.from(trigger, tz.local);

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'subscription_renewals',
        'Subscription renewals',
        channelDescription: 'Alerts sent before subscription renewal dates.',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      triggerTz,
      details,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  Future<void> _scheduleRecurringExpenseReminder({
    required Expense expense,
    required DateTime nextOccurrence,
    required DateTime now,
    required Duration offset,
  }) async {
    final remaining = nextOccurrence.difference(now);
    if (remaining.isNegative || remaining.inSeconds == 0) {
      return;
    }

    final trigger = nextOccurrence.subtract(offset);
    final bucketLabel = '${offset.inHours}h';
    final id = _recurringNotificationId(expense.id, bucketLabel);

    if (!trigger.isAfter(now)) {
      final isCatchUpFor48h =
          offset.inHours == 48 &&
          remaining.inHours > 24 &&
          remaining.inHours <= 48;
      final isCatchUpFor24h = offset.inHours == 24 && remaining.inHours <= 24;
      if (isCatchUpFor48h || isCatchUpFor24h) {
        await _showNow(
          id: id,
          title: 'Recurring expense in $bucketLabel',
          body:
              '${expense.currency} ${expense.amount.toStringAsFixed(2)} due on ${_formatDateTime(nextOccurrence)}',
          payload: '$_expensePayloadPrefix:${expense.id}:$bucketLabel',
        );
      }
      return;
    }

    await _schedule(
      id: id,
      title: 'Recurring expense in $bucketLabel',
      body:
          '${expense.currency} ${expense.amount.toStringAsFixed(2)} due on ${_formatDateTime(nextOccurrence)}',
      trigger: trigger,
      payload: '$_expensePayloadPrefix:${expense.id}:$bucketLabel',
    );
  }

  Future<void> _showNow({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'subscription_renewals',
        'Subscription renewals',
        channelDescription: 'Alerts sent before subscription renewal dates.',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _plugin.show(id, title, body, details, payload: payload);
  }

  int _notificationId(int subscriptionId, String bucketLabel) {
    final bucketPart = bucketLabel == '24h' ? 24 : 48;
    return (subscriptionId * 100) + bucketPart;
  }

  int _recurringNotificationId(int expenseId, String bucketLabel) {
    final bucketPart = bucketLabel == '24h' ? 24 : 48;
    return 100000000 + (expenseId * 100) + bucketPart;
  }

  DateTime _nextMonthlyOccurrence(DateTime seed, DateTime now) {
    var cursor = seed;
    while (!cursor.isAfter(now)) {
      cursor = _addMonthsKeepingTime(cursor, 1);
    }
    return cursor;
  }

  DateTime _addMonthsKeepingTime(DateTime value, int monthsToAdd) {
    final totalMonths = value.month + monthsToAdd;
    final year = value.year + ((totalMonths - 1) ~/ 12);
    final month = ((totalMonths - 1) % 12) + 1;
    final maxDay = DateTime(year, month + 1, 0).day;
    final day = value.day <= maxDay ? value.day : maxDay;
    return DateTime(
      year,
      month,
      day,
      value.hour,
      value.minute,
      value.second,
      value.millisecond,
      value.microsecond,
    );
  }

  String _formatDateTime(DateTime date) {
    return _dateTimeFmt.format(date.toLocal());
  }
}
