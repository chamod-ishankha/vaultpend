import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/expense.dart';
import '../../data/models/subscription.dart';
import 'reminder_planning.dart';

final _logger = Logger('VaultSpend.Reminders');

class ReminderRuntimeStatus {
  const ReminderRuntimeStatus({
    required this.initialized,
    required this.pluginAvailable,
    required this.notificationsEnabled,
    required this.exactAlarmsAllowed,
    required this.managedPendingCount,
  });

  final bool initialized;
  final bool pluginAvailable;
  final bool? notificationsEnabled;
  final bool? exactAlarmsAllowed;
  final int managedPendingCount;
}

class SubscriptionReminderService {
  SubscriptionReminderService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _pluginAvailable = true;

  static const _payloadPrefix = 'vaultspend-renewal';
  static const _expensePayloadPrefix = 'vaultspend-recurring-expense';
  static final _dateTimeFmt = DateFormat('MMM d, yyyy h:mm a');
  static const _grace48hTo24h = Duration(minutes: 2);
  static const _grace24hToDue = Duration(seconds: 20);

  Future<void> initialize() async {
    if (_initialized || !_pluginAvailable) {
      return;
    }

    _logger.info('reminder_init_started');

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
      final notificationsPermission = await androidPlugin
          ?.requestNotificationsPermission();
      final exactAlarmsPermission = await androidPlugin
          ?.requestExactAlarmsPermission();
      final notificationsEnabled = await androidPlugin
          ?.areNotificationsEnabled();
      final exactAlarmsAllowed = await androidPlugin
          ?.canScheduleExactNotifications();

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
      _logger.info(
        'reminder_init_completed '
        'notificationsPermission=$notificationsPermission '
        'exactAlarmsPermission=$exactAlarmsPermission '
        'notificationsEnabled=$notificationsEnabled '
        'exactAlarmsAllowed=$exactAlarmsAllowed '
        'timezone=$localTzName',
      );
    } on MissingPluginException {
      _pluginAvailable = false;
      _logger.warning('reminder_init_missing_plugin');
    } on PlatformException {
      _pluginAvailable = false;
      _logger.warning('reminder_init_platform_exception');
    }
  }

  Future<ReminderRuntimeStatus> getRuntimeStatus() async {
    await initialize();

    bool? notificationsEnabled;
    bool? exactAlarmsAllowed;
    if (_pluginAvailable) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      notificationsEnabled = await androidPlugin?.areNotificationsEnabled();
      exactAlarmsAllowed = await androidPlugin?.canScheduleExactNotifications();
    }

    final managedPendingCount = (await getManagedPendingReminders()).length;
    return ReminderRuntimeStatus(
      initialized: _initialized,
      pluginAvailable: _pluginAvailable,
      notificationsEnabled: notificationsEnabled,
      exactAlarmsAllowed: exactAlarmsAllowed,
      managedPendingCount: managedPendingCount,
    );
  }

  Future<void> syncRenewalReminders(List<Subscription> subscriptions) async {
    await initialize();
    if (!_initialized || !_pluginAvailable) {
      return;
    }

    try {
      final pending = await _plugin.pendingNotificationRequests();
      _logger.info(
        'reminder_sync_renewal_started subscriptions=${subscriptions.length} pending=${pending.length}',
      );
      final existingSubscriptionBuckets = _existingBucketsByEntity(
        pending,
        _payloadPrefix,
      );
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
        final plan = ReminderPlanning.nextReminderPlan(
          subscription.nextBillingDate,
          now,
        );
        await _syncSubscriptionPlan(
          subscription,
          plan,
          existingBucket: existingSubscriptionBuckets[subscription.id],
          now: now,
        );
      }
      _logger.info('reminder_sync_renewal_completed');
    } on MissingPluginException catch (error, stack) {
      _pluginAvailable = false;
      _logger.warning('reminder_sync_renewal_missing_plugin', error, stack);
    } on PlatformException catch (error, stack) {
      _pluginAvailable = false;
      _logger.warning('reminder_sync_renewal_platform_exception', error, stack);
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
      _logger.info(
        'reminder_sync_global_started '
        'subscriptions=${subscriptions.length} '
        'expenses=${expenses.length} '
        'includeSubscriptions=$includeSubscriptions '
        'includeRecurringExpenses=$includeRecurringExpenses '
        'pending=${pending.length}',
      );
      final existingSubscriptionBuckets = _existingBucketsByEntity(
        pending,
        _payloadPrefix,
      );
      final existingRecurringBuckets = _existingBucketsByEntity(
        pending,
        _expensePayloadPrefix,
      );

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
          final plan = ReminderPlanning.nextReminderPlan(
            subscription.nextBillingDate,
            now,
          );
          await _syncSubscriptionPlan(
            subscription,
            plan,
            existingBucket: existingSubscriptionBuckets[subscription.id],
            now: now,
          );
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
          final nextOccurrence = ReminderPlanning.nextMonthlyOccurrence(
            expense.occurredAt,
            now,
          );
          final plan = ReminderPlanning.nextReminderPlan(nextOccurrence, now);
          await _syncRecurringExpensePlan(
            expense: expense,
            nextOccurrence: nextOccurrence,
            plan: plan,
            existingBucket: existingRecurringBuckets[expense.id],
            now: now,
          );
        }
      } else {
        for (final request in pending) {
          if (request.payload?.startsWith(_expensePayloadPrefix) == true) {
            await _plugin.cancel(request.id);
          }
        }
      }
      _logger.info('reminder_sync_global_completed');
    } on MissingPluginException catch (error, stack) {
      _pluginAvailable = false;
      _logger.warning('reminder_sync_global_missing_plugin', error, stack);
    } on PlatformException catch (error, stack) {
      _pluginAvailable = false;
      _logger.warning('reminder_sync_global_platform_exception', error, stack);
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
      _logger.info('reminder_cancel_managed_completed');
    } on MissingPluginException catch (error, stack) {
      _pluginAvailable = false;
      _logger.warning('reminder_cancel_managed_missing_plugin', error, stack);
    } on PlatformException catch (error, stack) {
      _pluginAvailable = false;
      _logger.warning(
        'reminder_cancel_managed_platform_exception',
        error,
        stack,
      );
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
    } on MissingPluginException catch (error, stack) {
      _pluginAvailable = false;
      _logger.warning('reminder_get_pending_missing_plugin', error, stack);
      return const <PendingNotificationRequest>[];
    } on PlatformException catch (error, stack) {
      _pluginAvailable = false;
      _logger.warning('reminder_get_pending_platform_exception', error, stack);
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
    final now = DateTime.now();
    final delta = trigger.difference(now);

    _logger.info(
      'reminder_schedule '
      'id=$id payload=$payload '
      'trigger=${trigger.toIso8601String()} '
      'now=${now.toIso8601String()} '
      'deltaMs=${delta.inMilliseconds}',
    );

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
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );

    _logger.info('reminder_schedule_enqueued id=$id payload=$payload');
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

  Future<void> sendDebugNotificationNow() async {
    await initialize();
    if (!_initialized || !_pluginAvailable) {
      _logger.warning('reminder_debug_notification_skipped_not_initialized');
      return;
    }

    final id = 900000000 + (DateTime.now().millisecondsSinceEpoch % 1000000);
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

    await _plugin.show(
      id,
      'VaultSpend reminder test',
      'If this appears, local notification delivery is working.',
      details,
      payload: 'vaultspend-debug:test',
    );
    _logger.info('reminder_debug_notification_shown id=$id');
  }

  Future<void> scheduleDebugNotification({
    Duration delay = const Duration(seconds: 15),
  }) async {
    await initialize();
    if (!_initialized || !_pluginAvailable) {
      _logger.warning('reminder_debug_schedule_skipped_not_initialized');
      return;
    }

    final trigger = DateTime.now().add(delay);
    final id = 910000000 + (DateTime.now().millisecondsSinceEpoch % 1000000);
    _logger.info(
      'reminder_debug_schedule_requested id=$id trigger=${trigger.toIso8601String()} delayMs=${delay.inMilliseconds}',
    );
    await _schedule(
      id: id,
      title: 'VaultSpend scheduled test',
      body: 'This confirms scheduled reminder delivery.',
      trigger: trigger,
      payload: 'vaultspend-debug-scheduled:test',
    );
    _logger.info('reminder_debug_schedule_enqueued id=$id');
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
    ReminderPlan? plan, {
    String? existingBucket,
    required DateTime now,
  }) async {
    if (plan == null) {
      await _cancelSubscriptionBuckets(subscription.id);
      return;
    }

    if (existingBucket != null) {
      final keepExisting = _shouldKeepExistingBucketForEntity(
        dueDate: subscription.nextBillingDate,
        existingBucket: existingBucket,
        plannedBucket: plan.bucketLabel,
        now: now,
      );
      if (keepExisting) {
        _logger.info(
          'reminder_keep_existing_subscription '
          'subscriptionId=${subscription.id} '
          'existingBucket=$existingBucket plannedBucket=${plan.bucketLabel}',
        );
        return;
      }
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
    required ReminderPlan? plan,
    String? existingBucket,
    required DateTime now,
  }) async {
    if (plan == null) {
      await _cancelRecurringBuckets(expense.id);
      return;
    }

    if (existingBucket != null) {
      final keepExisting = _shouldKeepExistingBucketForEntity(
        dueDate: nextOccurrence,
        existingBucket: existingBucket,
        plannedBucket: plan.bucketLabel,
        now: now,
      );
      if (keepExisting) {
        _logger.info(
          'reminder_keep_existing_recurring '
          'expenseId=${expense.id} '
          'existingBucket=$existingBucket plannedBucket=${plan.bucketLabel}',
        );
        return;
      }
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
    for (final bucket in ReminderPlanning.supportedBuckets) {
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
    for (final bucket in ReminderPlanning.supportedBuckets) {
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

  Map<int, String> _existingBucketsByEntity(
    List<PendingNotificationRequest> pending,
    String prefix,
  ) {
    final byEntity = <int, String>{};

    for (final request in pending) {
      final payload = request.payload;
      if (payload?.startsWith(prefix) != true) {
        continue;
      }

      final parts = payload!.split(':');
      if (parts.length < 3) {
        continue;
      }
      final entityId = int.tryParse(parts[1]);
      if (entityId == null) {
        continue;
      }

      byEntity[entityId] = parts[2].toLowerCase();
    }

    return byEntity;
  }

  bool _shouldKeepExistingBucketForEntity({
    required DateTime dueDate,
    required String existingBucket,
    required String plannedBucket,
    required DateTime now,
  }) {
    if (!ReminderPlanning.shouldKeepExistingBucket(
      existingBucket: existingBucket,
      plannedBucket: plannedBucket,
    )) {
      return false;
    }

    final existingTrigger = ReminderPlanning.triggerForBucket(
      dueDate,
      existingBucket,
    );
    if (existingTrigger == null) {
      return false;
    }

    final overdueBy = now.difference(existingTrigger);
    if (overdueBy.isNegative) {
      return true;
    }

    final graceWindow = _graceWindowForTransition(
      existingBucket: existingBucket,
      plannedBucket: plannedBucket,
    );
    final keep = overdueBy <= graceWindow;
    if (!keep) {
      _logger.info(
        'reminder_roll_forward_stale_bucket '
        'existingBucket=$existingBucket '
        'plannedBucket=$plannedBucket '
        'dueDate=${dueDate.toIso8601String()} '
        'existingTrigger=${existingTrigger.toIso8601String()} '
        'graceMs=${graceWindow.inMilliseconds} '
        'overdueMs=${overdueBy.inMilliseconds}',
      );
    }
    return keep;
  }

  Duration _graceWindowForTransition({
    required String existingBucket,
    required String plannedBucket,
  }) {
    final existing = existingBucket.toLowerCase();
    final planned = plannedBucket.toLowerCase();

    if (existing == '48h' && planned == '24h') {
      return _grace48hTo24h;
    }
    if (existing == '24h' && planned == 'due') {
      return _grace24hToDue;
    }

    return Duration.zero;
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

  String _formatDateTime(DateTime date) {
    return _dateTimeFmt.format(date.toLocal());
  }
}
