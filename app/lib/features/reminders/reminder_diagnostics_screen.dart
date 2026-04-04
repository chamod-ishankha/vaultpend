import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/logging/sync_incident_service.dart';
import '../../core/notifications/reminder_planning.dart';
import '../../core/notifications/subscription_reminder_service.dart';
import '../../core/providers.dart';
import '../../data/models/expense.dart';
import '../../data/models/subscription.dart';
import '../auth/auth_providers.dart';

class ReminderDiagnosticsScreen extends ConsumerStatefulWidget {
  const ReminderDiagnosticsScreen({super.key});

  @override
  ConsumerState<ReminderDiagnosticsScreen> createState() =>
      _ReminderDiagnosticsScreenState();
}

class _ReminderDiagnosticsScreenState
    extends ConsumerState<ReminderDiagnosticsScreen> {
  final _service = SubscriptionReminderService();
  final _syncIncidentService = SyncIncidentService();
  late Future<List<PendingNotificationRequest>> _pendingFuture;
  late Future<List<Expense>> _recurringExpensesFuture;
  late Future<List<SyncIncidentEntry>> _syncIncidentsFuture;
  late Future<ReminderRuntimeStatus> _runtimeStatusFuture;
  Timer? _liveRefreshTimer;
  static final _dateFmt = DateFormat('MMM d, yyyy h:mm a');
  DateTime? _lastCheckedAt;
  String? _lastRefreshError;
  Map<int, Expense> _expenseById = {};
  Map<int, Subscription> _subscriptionById = {};
  int _expectedSubscriptionReminders = 0;
  int _expectedRecurringReminders = 0;
  int _pendingSubscriptionReminders = 0;
  int _pendingRecurringReminders = 0;

  @override
  void initState() {
    super.initState();
    _pendingFuture = _loadPending();
    _recurringExpensesFuture = _loadRecurringExpenses();
    _syncIncidentsFuture = _loadSyncIncidents();
    _runtimeStatusFuture = _service.getRuntimeStatus();
    _liveRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _runtimeStatusFuture = _service.getRuntimeStatus();
      });
    });
  }

  @override
  void dispose() {
    _liveRefreshTimer?.cancel();
    super.dispose();
  }

  Future<List<SyncIncidentEntry>> _loadSyncIncidents() async {
    final incidents = await _syncIncidentService.readAll();
    return incidents.take(10).toList(growable: false);
  }

  Future<List<Expense>> _loadRecurringExpenses() async {
    try {
      final expenses = await ref.read(expenseRepositoryProvider).getAll();
      return expenses.where((e) => e.isRecurring).toList();
    } catch (_) {
      return const <Expense>[];
    }
  }

  Future<List<PendingNotificationRequest>> _loadPending() async {
    try {
      await _service.initialize();
      final remindersEnabled = ref.read(remindersEnabledProvider);
      final subscriptionsEnabled = ref.read(
        subscriptionRemindersEnabledProvider,
      );
      final recurringEnabled = ref.read(
        recurringExpenseRemindersEnabledProvider,
      );
      final subscriptions = await ref
          .read(subscriptionRepositoryProvider)
          .getAll();
      final expenses = await ref.read(expenseRepositoryProvider).getAll();

      if (!remindersEnabled) {
        await _service.cancelManagedReminders();
      } else {
        await _service.syncGlobalReminders(
          subscriptions: subscriptions,
          expenses: expenses,
          includeSubscriptions: subscriptionsEnabled,
          includeRecurringExpenses: recurringEnabled,
        );
      }

      final expenseById = <int, Expense>{
        for (final expense in expenses) expense.id: expense,
      };
      final subscriptionById = <int, Subscription>{
        for (final subscription in subscriptions) subscription.id: subscription,
      };

      final requests = await _service.getManagedPendingReminders();
      requests.sort((a, b) {
        final left = _pendingSortKey(a);
        final right = _pendingSortKey(b);
        return left.compareTo(right);
      });
      final now = DateTime.now();

      final expectedSubscriptionReminders = subscriptions.where((subscription) {
        return ReminderPlanning.nextReminderPlan(
              subscription.nextBillingDate,
              now,
            ) !=
            null;
      }).length;

      final recurringExpenses = expenses.where(
        (expense) => expense.isRecurring,
      );
      final expectedRecurringReminders = recurringExpenses.where((expense) {
        final dueDate = ReminderPlanning.nextMonthlyOccurrence(
          expense.occurredAt,
          now,
        );
        return ReminderPlanning.nextReminderPlan(dueDate, now) != null;
      }).length;

      final pendingSubscriptionReminders = requests.where((request) {
        return request.payload?.startsWith('vaultspend-renewal') == true;
      }).length;

      final pendingRecurringReminders = requests.where((request) {
        return request.payload?.startsWith('vaultspend-recurring-expense') ==
            true;
      }).length;

      if (mounted) {
        setState(() {
          _expenseById = expenseById;
          _subscriptionById = subscriptionById;
          _expectedSubscriptionReminders = expectedSubscriptionReminders;
          _expectedRecurringReminders = expectedRecurringReminders;
          _pendingSubscriptionReminders = pendingSubscriptionReminders;
          _pendingRecurringReminders = pendingRecurringReminders;
          _lastCheckedAt = DateTime.now();
          _lastRefreshError = null;
        });
      }
      return requests;
    } catch (error) {
      if (mounted) {
        setState(() {
          _lastCheckedAt = DateTime.now();
          _lastRefreshError = '$error';
        });
      }
      return const <PendingNotificationRequest>[];
    }
  }

  Future<void> _refresh() async {
    final future = _loadPending();
    final incidentsFuture = _loadSyncIncidents();
    setState(() {
      _pendingFuture = future;
      _syncIncidentsFuture = incidentsFuture;
      _runtimeStatusFuture = _service.getRuntimeStatus();
    });
    await future;
    if (!mounted || _lastRefreshError == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Refresh completed with warning: $_lastRefreshError'),
      ),
    );
  }

  Future<void> _sendTestNotificationNow() async {
    try {
      await _service.sendDebugNotificationNow();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test notification fired now.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Test notification failed: $error')));
    }
  }

  Future<void> _scheduleTestNotification() async {
    try {
      await _service.scheduleDebugNotification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scheduled test notification for 15s.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Scheduled test failed: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final remindersEnabled = ref.watch(remindersEnabledProvider);
    final subscriptionsEnabled = ref.watch(
      subscriptionRemindersEnabledProvider,
    );
    final recurringEnabled = ref.watch(
      recurringExpenseRemindersEnabledProvider,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminder diagnostics'),
        actions: [
          IconButton(
            tooltip: 'Schedule test notification in 15s',
            onPressed: _scheduleTestNotification,
            icon: const Icon(Icons.alarm_add),
          ),
          IconButton(
            tooltip: 'Send test notification now',
            onPressed: _sendTestNotificationNow,
            icon: const Icon(Icons.notifications_active),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current reminder settings',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _StatusRow(
                      label: 'Master reminders',
                      enabled: remindersEnabled,
                    ),
                    _StatusRow(
                      label: 'Subscription reminders',
                      enabled: subscriptionsEnabled,
                    ),
                    _StatusRow(
                      label: 'Recurring expense reminders',
                      enabled: recurringEnabled,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Last checked: ${_lastCheckedAt == null ? 'Not yet' : _dateFmt.format(_lastCheckedAt!.toLocal())}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (_lastRefreshError != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Last warning: $_lastRefreshError',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Reliability check',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Subscriptions: expected $_expectedSubscriptionReminders, pending $_pendingSubscriptionReminders',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      'Recurring: expected $_expectedRecurringReminders, pending $_pendingRecurringReminders',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (_expectedSubscriptionReminders !=
                            _pendingSubscriptionReminders ||
                        _expectedRecurringReminders !=
                            _pendingRecurringReminders)
                      Text(
                        'Warning: expected and pending counts differ. Run refresh again and inspect pending entries.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Runtime notification status',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            FutureBuilder<ReminderRuntimeStatus>(
              future: _runtimeStatusFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Loading notification runtime status...'),
                    ),
                  );
                }

                final status = snapshot.data;
                if (status == null) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Runtime status unavailable.'),
                    ),
                  );
                }

                String label(bool? value) {
                  if (value == null) {
                    return 'Unknown';
                  }
                  return value ? 'Yes' : 'No';
                }

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Plugin initialized: ${status.initialized ? 'Yes' : 'No'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          'Plugin available: ${status.pluginAvailable ? 'Yes' : 'No'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          'Notifications enabled (OS): ${label(status.notificationsEnabled)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          'Exact alarms allowed (OS): ${label(status.exactAlarmsAllowed)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          'Managed pending reminders: ${status.managedPendingCount}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Recurring expenses & next occurrences',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<Expense>>(
              future: _recurringExpensesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final expenses = snapshot.data ?? const <Expense>[];
                if (expenses.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('No recurring expenses found.'),
                    ),
                  );
                }

                final now = DateTime.now();
                return Column(
                  children: [
                    for (final expense in expenses)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.repeat_outlined),
                          title: Text(
                            '${expense.currency} ${expense.amount.toStringAsFixed(2)}',
                          ),
                          subtitle: Text(
                            'Original: ${_dateFmt.format(expense.occurredAt.toLocal())}\nNext: ${_dateFmt.format(ReminderPlanning.nextMonthlyOccurrence(expense.occurredAt, now).toLocal())}',
                          ),
                          trailing: Text('#${expense.id}'),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Recent sync incidents',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<SyncIncidentEntry>>(
              future: _syncIncidentsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final incidents = snapshot.data ?? const <SyncIncidentEntry>[];
                if (incidents.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('No sync incidents recorded.'),
                    ),
                  );
                }

                return Column(
                  children: [
                    for (final incident in incidents)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.sync_problem_outlined),
                          title: Text(
                            '${incident.entity} ${incident.operation} failed',
                          ),
                          subtitle: Text(
                            '${_dateFmt.format(incident.timestamp.toLocal())}\nStage: ${incident.stage}\nError: ${incident.error}',
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Pending managed reminders',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<PendingNotificationRequest>>(
              future: _pendingFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final requests =
                    snapshot.data ?? const <PendingNotificationRequest>[];
                if (requests.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _lastRefreshError == null
                            ? 'No managed reminder notifications are pending.'
                            : 'No reminders shown because diagnostics hit a warning. Pull to refresh.',
                      ),
                    ),
                  );
                }

                final subscriptionRequests = requests
                    .where(
                      (request) =>
                          request.payload?.startsWith('vaultspend-renewal') ==
                          true,
                    )
                    .toList(growable: false);
                final recurringRequests = requests
                    .where(
                      (request) =>
                          request.payload?.startsWith(
                            'vaultspend-recurring-expense',
                          ) ==
                          true,
                    )
                    .toList(growable: false);
                final otherRequests = requests
                    .where(
                      (request) =>
                          (request.payload?.startsWith('vaultspend-renewal') !=
                              true) &&
                          (request.payload?.startsWith(
                                'vaultspend-recurring-expense',
                              ) !=
                              true),
                    )
                    .toList(growable: false);

                return Column(
                  children: [
                    if (subscriptionRequests.isNotEmpty)
                      _buildPendingSection(
                        context: context,
                        heading: 'Subscription reminders',
                        requests: subscriptionRequests,
                      ),
                    if (recurringRequests.isNotEmpty)
                      _buildPendingSection(
                        context: context,
                        heading: 'Recurring expense reminders',
                        requests: recurringRequests,
                      ),
                    if (otherRequests.isNotEmpty)
                      _buildPendingSection(
                        context: context,
                        heading: 'Other reminders',
                        requests: otherRequests,
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _buildSubtitle(PendingNotificationRequest request) {
    final body = request.body ?? '';
    final descriptor = _describePendingReminder(request);
    if (descriptor == null) {
      final payload = request.payload ?? 'no payload';
      if (body.isEmpty) {
        return payload;
      }
      return '$body\n$payload';
    }

    final trigger = _computeReminderTrigger(descriptor);
    final lines = <String>[
      descriptor.summary,
      if (trigger != null) 'Trigger: ${_dateFmt.format(trigger.toLocal())}',
      if (trigger != null) _formatTimeRemaining(trigger),
      if (body.isNotEmpty) body,
    ];
    return lines.join('\n');
  }

  String _formatTimeRemaining(DateTime trigger) {
    final now = DateTime.now();
    final diff = trigger.difference(now);

    if (!diff.isNegative) {
      final days = diff.inDays;
      final hours = diff.inHours.remainder(24);
      final minutes = diff.inMinutes.remainder(60);

      final parts = <String>[];
      if (days > 0) {
        parts.add('${days}d');
      }
      if (hours > 0 || days > 0) {
        parts.add('${hours}h');
      }
      parts.add('${minutes}m');
      return 'Time remaining: in ${parts.join(' ')}';
    }

    final elapsed = now.difference(trigger);
    final days = elapsed.inDays;
    final hours = elapsed.inHours.remainder(24);
    final minutes = elapsed.inMinutes.remainder(60);

    final parts = <String>[];
    if (days > 0) {
      parts.add('${days}d');
    }
    if (hours > 0 || days > 0) {
      parts.add('${hours}h');
    }
    parts.add('${minutes}m');
    return 'Time remaining: overdue by ${parts.join(' ')}';
  }

  String _buildPendingTitle(PendingNotificationRequest request) {
    final descriptor = _describePendingReminder(request);
    if (descriptor == null) {
      return request.title ?? 'Reminder ${request.id}';
    }
    return descriptor.title;
  }

  Widget _buildPendingSection({
    required BuildContext context,
    required String heading,
    required List<PendingNotificationRequest> requests,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
          child: Text(
            '$heading (${requests.length})',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        for (final request in requests)
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: Text(_buildPendingTitle(request)),
              subtitle: Text(_buildSubtitle(request)),
              trailing: Text('#${request.id}'),
            ),
          ),
      ],
    );
  }

  String _pendingSortKey(PendingNotificationRequest request) {
    final descriptor = _describePendingReminder(request);
    if (descriptor == null) {
      return '${request.payload ?? ''}:${request.id}';
    }

    final kindOrder = descriptor.kind == 'Subscription renewal reminder'
        ? '0'
        : descriptor.kind == 'Recurring expense reminder'
        ? '1'
        : '2';
    final entityOrder =
        descriptor.entityId?.toString().padLeft(8, '0') ?? '99999999';
    final bucketOrder =
        descriptor.bucketHours?.toString().padLeft(3, '0') ?? '999';
    return '$kindOrder:$entityOrder:$bucketOrder:${request.id}';
  }

  _PendingReminderDescriptor? _describePendingReminder(
    PendingNotificationRequest request,
  ) {
    final payload = request.payload;
    if (payload == null || payload.isEmpty) {
      return null;
    }

    final parts = payload.split(':');
    if (parts.length < 3) {
      return null;
    }

    final prefix = parts[0];
    final entityId = int.tryParse(parts[1]);
    final bucketToken = parts[2].toUpperCase();
    final bucketHours = bucketToken == 'DUE'
        ? 0
        : int.tryParse(bucketToken.replaceAll('H', ''));

    String kind;
    String title;
    if (prefix == 'vaultspend-recurring-expense') {
      kind = 'Recurring expense reminder';
      final expense = entityId == null ? null : _expenseById[entityId];
      final expenseLabel = expense?.note?.trim();
      title = expenseLabel == null || expenseLabel.isEmpty
          ? 'Recurring expense #${parts[1]}'
          : expenseLabel;
    } else if (prefix == 'vaultspend-renewal') {
      kind = 'Subscription renewal reminder';
      final subscriptionName = entityId == null
          ? null
          : _subscriptionById[entityId]?.name;
      title = subscriptionName == null || subscriptionName.isEmpty
          ? 'Subscription #${parts[1]}'
          : subscriptionName;
    } else {
      kind = 'Reminder';
      title = 'Reminder #${parts[1]}';
    }

    final bucketLabel = bucketToken == 'DUE'
        ? 'at due time'
        : bucketHours == null
        ? bucketToken
        : '$bucketHours hour${bucketHours == 1 ? '' : 's'} before due date';

    return _PendingReminderDescriptor(
      kind: kind,
      entityId: entityId,
      bucketHours: bucketHours,
      bucketToken: bucketToken,
      rawPayload: payload,
      title: title,
      summary: 'Fires $bucketLabel',
    );
  }

  DateTime? _computeReminderTrigger(_PendingReminderDescriptor descriptor) {
    final entityId = descriptor.entityId;
    if (entityId == null) {
      return null;
    }

    DateTime? dueDate;
    if (descriptor.kind == 'Subscription renewal reminder') {
      dueDate = _subscriptionById[entityId]?.nextBillingDate;
    } else if (descriptor.kind == 'Recurring expense reminder') {
      final expense = _expenseById[entityId];
      if (expense != null) {
        dueDate = ReminderPlanning.nextMonthlyOccurrence(
          expense.occurredAt,
          DateTime.now(),
        );
      }
    }

    if (dueDate == null) {
      return null;
    }

    if (descriptor.bucketToken == 'DUE') {
      return dueDate;
    }

    final hours = descriptor.bucketHours;
    if (hours == null) {
      return null;
    }
    return dueDate.subtract(Duration(hours: hours));
  }
}

class _PendingReminderDescriptor {
  const _PendingReminderDescriptor({
    required this.kind,
    required this.entityId,
    required this.bucketHours,
    required this.bucketToken,
    required this.rawPayload,
    required this.title,
    required this.summary,
  });

  final String kind;
  final int? entityId;
  final int? bucketHours;
  final String bucketToken;
  final String rawPayload;
  final String title;
  final String summary;
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.enabled});

  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            enabled ? Icons.check_circle_outline : Icons.cancel_outlined,
            size: 18,
            color: enabled
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(enabled ? 'On' : 'Off'),
        ],
      ),
    );
  }
}
