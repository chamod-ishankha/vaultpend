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
  static const _supportedBuckets = ['48h', '24h', 'due'];
  static final _dateTimeFmt = DateFormat('MMM d, yyyy h:mm a');

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
      final subscriptionIds = subscriptions
          .map((subscription) => subscription.id)
          .toSet();

      for (final request in pending) {
        final payload = request.payload;
        if (payload?.startsWith(_payloadPrefix) != true) {
          continue;
        }

        final entityId = _entityIdFromPayload(payload!);
        if (entityId == null || !subscriptionIds.contains(entityId)) {
          await _plugin.cancel(request.id);
        }
      }

      final now = DateTime.now();
      for (final subscription in subscriptions) {
        final plan = _nextReminderPlan(subscription.nextBillingDate, now);
        await _syncSubscriptionPlan(subscription, plan);
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
    bool includeSubscriptions = true,
    bool includeRecurringExpenses = true,
  }) async {
    await initialize();
    if (!_initialized || !_pluginAvailable) {
      return;
    }

    try {
      final pending = await _plugin.pendingNotificationRequests();

      final now = DateTime.now();
      if (includeSubscriptions) {
        final subscriptionIds = subscriptions
            .map((subscription) => subscription.id)
            .toSet();

        for (final request in pending) {
          final payload = request.payload;
          if (payload?.startsWith(_payloadPrefix) != true) {
            continue;
          }

          final entityId = _entityIdFromPayload(payload!);
          if (entityId == null || !subscriptionIds.contains(entityId)) {
            await _plugin.cancel(request.id);
          }
        }

        for (final subscription in subscriptions) {
          final plan = _nextReminderPlan(subscription.nextBillingDate, now);
          await _syncSubscriptionPlan(subscription, plan);
        }
      } else {
        for (final request in pending) {
          if (request.payload?.startsWith(_payloadPrefix) == true) {
            await _plugin.cancel(request.id);
          }
        }
      }

      if (includeRecurringExpenses) {
        final recurringExpenses = expenses.where((e) => e.isRecurring);
        final recurringIds = recurringExpenses
            .map((expense) => expense.id)
            .toSet();

        for (final request in pending) {
          final payload = request.payload;
          if (payload?.startsWith(_expensePayloadPrefix) != true) {
            continue;
          }

          final entityId = _entityIdFromPayload(payload!);
          if (entityId == null || !recurringIds.contains(entityId)) {
            await _plugin.cancel(request.id);
          }
        }

        for (final expense in recurringExpenses) {
          final nextOccurrence = _nextMonthlyOccurrence(
            expense.occurredAt,
            now,
          );
          final plan = _nextReminderPlan(nextOccurrence, now);
          await _syncRecurringExpensePlan(
            expense: expense,
            nextOccurrence: nextOccurrence,
            plan: plan,
          );
        }
      } else {
        for (final request in pending) {
          if (request.payload?.startsWith(_expensePayloadPrefix) == true) {
            await _plugin.cancel(request.id);
          }
        }
      }
    } on MissingPluginException {
      _pluginAvailable = false;
    } on PlatformException {
      _pluginAvailable = false;
    }
  }

  Future<void> cancelManagedReminders() async {
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
    } on MissingPluginException {
      _pluginAvailable = false;
    } on PlatformException {
      _pluginAvailable = false;
    }
  }

  Future<List<PendingNotificationRequest>> getManagedPendingReminders() async {
    await initialize();
    if (!_initialized || !_pluginAvailable) {
      return const <PendingNotificationRequest>[];
    }

    try {
      final pending = await _plugin.pendingNotificationRequests();
      return pending
          .where((request) {
            final payload = request.payload;
            return payload?.startsWith(_payloadPrefix) == true ||
                payload?.startsWith(_expensePayloadPrefix) == true;
          })
          .toList(growable: false);
    } on MissingPluginException {
      _pluginAvailable = false;
      return const <PendingNotificationRequest>[];
    } on PlatformException {
      _pluginAvailable = false;
      return const <PendingNotificationRequest>[];
    }
  }

  Future<void> _scheduleReminder({
    required Subscription subscription,
    required String bucketLabel,
    required DateTime trigger,
  }) async {
    await _schedule(
      id: _notificationId(subscription.id, bucketLabel),
      title: _subscriptionTitleForBucket(bucketLabel),
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
    required String bucketLabel,
    required DateTime trigger,
  }) async {
    final id = _recurringNotificationId(expense.id, bucketLabel);

    await _schedule(
      id: id,
      title: _recurringTitleForBucket(bucketLabel),
      body:
          '${expense.currency} ${expense.amount.toStringAsFixed(2)} due on ${_formatDateTime(nextOccurrence)}',
      trigger: trigger,
      payload: '$_expensePayloadPrefix:${expense.id}:$bucketLabel',
    );
  }

  int _notificationId(int subscriptionId, String bucketLabel) {
    final bucketPart = bucketLabel == '48h'
        ? 48
        : bucketLabel == '24h'
        ? 24
        : 0;
    return (subscriptionId * 100) + bucketPart;
  }

  int _recurringNotificationId(int expenseId, String bucketLabel) {
    final bucketPart = bucketLabel == '48h'
        ? 48
        : bucketLabel == '24h'
        ? 24
        : 0;
    return 100000000 + (expenseId * 100) + bucketPart;
  }

  Future<void> _syncSubscriptionPlan(
    Subscription subscription,
    _ReminderPlan? plan,
  ) async {
    if (plan == null) {
      await _cancelSubscriptionBuckets(subscription.id);
      return;
    }

    await _scheduleReminder(
      subscription: subscription,
      bucketLabel: plan.bucketLabel,
      trigger: plan.trigger,
    );
    await _cancelSubscriptionBuckets(
      subscription.id,
      exceptBucket: plan.bucketLabel,
    );
  }

  Future<void> _syncRecurringExpensePlan({
    required Expense expense,
    required DateTime nextOccurrence,
    required _ReminderPlan? plan,
  }) async {
    if (plan == null) {
      await _cancelRecurringBuckets(expense.id);
      return;
    }

    await _scheduleRecurringExpenseReminder(
      expense: expense,
      nextOccurrence: nextOccurrence,
      bucketLabel: plan.bucketLabel,
      trigger: plan.trigger,
    );
    await _cancelRecurringBuckets(expense.id, exceptBucket: plan.bucketLabel);
  }

  Future<void> _cancelSubscriptionBuckets(
    int subscriptionId, {
    String? exceptBucket,
  }) async {
    for (final bucket in _supportedBuckets) {
      if (bucket == exceptBucket) {
        continue;
      }
      await _plugin.cancel(_notificationId(subscriptionId, bucket));
    }
  }

  Future<void> _cancelRecurringBuckets(
    int expenseId, {
    String? exceptBucket,
  }) async {
    for (final bucket in _supportedBuckets) {
      if (bucket == exceptBucket) {
        continue;
      }
      await _plugin.cancel(_recurringNotificationId(expenseId, bucket));
    }
  }

  int? _entityIdFromPayload(String payload) {
    final parts = payload.split(':');
    if (parts.length < 3) {
      return null;
    }
    return int.tryParse(parts[1]);
  }

  _ReminderPlan? _nextReminderPlan(DateTime dueDate, DateTime now) {
    if (!dueDate.isAfter(now)) {
      return null;
    }

    final trigger48h = dueDate.subtract(const Duration(hours: 48));
    if (trigger48h.isAfter(now)) {
      return _ReminderPlan(bucketLabel: '48h', trigger: trigger48h);
    }

    final trigger24h = dueDate.subtract(const Duration(hours: 24));
    if (trigger24h.isAfter(now)) {
      return _ReminderPlan(bucketLabel: '24h', trigger: trigger24h);
    }

    return _ReminderPlan(bucketLabel: 'due', trigger: dueDate);
  }

  String _subscriptionTitleForBucket(String bucketLabel) {
    if (bucketLabel == 'due') {
      return 'Subscription renewal due now';
    }
    return 'Subscription renewal in $bucketLabel';
  }

  String _recurringTitleForBucket(String bucketLabel) {
    if (bucketLabel == 'due') {
      return 'Recurring expense due now';
    }
    return 'Recurring expense in $bucketLabel';
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

class _ReminderPlan {
  const _ReminderPlan({required this.bucketLabel, required this.trigger});

  final String bucketLabel;
  final DateTime trigger;
}
