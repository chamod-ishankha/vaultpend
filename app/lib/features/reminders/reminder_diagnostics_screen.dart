import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/formatters/time_remaining_formatter.dart';
import '../../core/notifications/reminder_planning.dart';
import '../../core/notifications/subscription_reminder_service.dart';
import '../../core/providers.dart';
import '../../core/widgets/obsidian_app_bar.dart';
import '../../core/widgets/obsidian_card.dart';
import '../../core/widgets/responsive_layout.dart';
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
  late Future<List<PendingNotificationRequest>> _pendingFuture;
  DateTime? _lastCheckedAt;
  Map<int, Expense> _expenseById = {};
  Map<int, Subscription> _subscriptionById = {};

  int _expectedTotal = 0;
  int _pendingTotal = 0;

  @override
  void initState() {
    super.initState();
    _pendingFuture = _loadPending();
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

      final requests = await _service.getManagedPendingReminders();

      if (mounted) {
        setState(() {
          _expenseById = {for (final e in expenses) e.id: e};
          _subscriptionById = {for (final s in subscriptions) s.id: s};
          _pendingTotal = requests.length;
          _expectedTotal =
              subscriptions.length +
              expenses.where((e) => e.isRecurring).length;
          _lastCheckedAt = DateTime.now();
        });
      }
      return requests;
    } catch (error) {
      if (mounted) {
        setState(() {
          _lastCheckedAt = DateTime.now();
        });
      }
      return const <PendingNotificationRequest>[];
    }
  }

  Future<void> _refresh() async {
    final future = _loadPending();
    setState(() {
      _pendingFuture = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isHealthy = _expectedTotal == 0
        ? _pendingTotal == 0
        : _pendingTotal >= _expectedTotal;
    final efficiency = _expectedTotal == 0
        ? (_pendingTotal == 0 ? 100 : 0)
        : ((_pendingTotal / _expectedTotal).clamp(0.0, 1.0) * 100).round();

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: ObsidianAppBar(
        centerTitle: false,
        title: Text(
          'Reminder Diagnostics',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ResponsiveBody(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _DiagnosticsOverviewCard(
                efficiency: efficiency,
                healthy: isHealthy,
                lastSync: _lastCheckedAt,
              ),
              const SizedBox(height: 28),
              FutureBuilder<List<PendingNotificationRequest>>(
                future: _pendingFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final requests = snapshot.data ?? [];
                  final entries = requests.map((request) {
                    final descriptor = _describePendingReminder(request);
                    return _ReminderLogEntry(
                      request: request,
                      descriptor: descriptor,
                      triggerDate: _computeReminderTrigger(descriptor),
                    );
                  }).toList();

                  final subEntries = entries
                      .where(
                        (entry) =>
                            entry.descriptor?.kind == 'vaultspend-renewal',
                      )
                      .toList();
                  final recurringEntries = entries
                      .where(
                        (entry) =>
                            entry.descriptor?.kind ==
                            'vaultspend-recurring-expense',
                      )
                      .toList();

                  DateTime? earliest(List<_ReminderLogEntry> list) {
                    final triggers =
                        list
                            .map((entry) => entry.triggerDate)
                            .whereType<DateTime>()
                            .toList()
                          ..sort();
                    return triggers.isEmpty ? null : triggers.first;
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(theme, scheme, 'ACTIVE QUEUES'),
                      const SizedBox(height: 12),
                      _ActiveQueuesCard(
                        totalJobs: entries.length,
                        subscriptionCount: subEntries.length,
                        recurringCount: recurringEntries.length,
                        nextSubscriptionTrigger: earliest(subEntries),
                        nextRecurringTrigger: earliest(recurringEntries),
                      ),
                      const SizedBox(height: 28),
                      _buildSectionHeader(theme, scheme, 'PRECISION LOG'),
                      const SizedBox(height: 12),
                      if (entries.isEmpty)
                        _buildEmptyState(
                          theme,
                          scheme,
                          'No active diagnostic entries',
                        )
                      else
                        Column(
                          children: entries
                              .map((entry) => _TriggerItem(entry: entry))
                              .toList(),
                        ),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: _refresh,
                          child: Text(
                            'REFRESH LOG STACK',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: scheme.primary,
                              letterSpacing: 0.7,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'VaultSpend Diagnostic Interface v2.4.0',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.outline,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 64),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    ThemeData theme,
    ColorScheme scheme,
    String title,
  ) {
    return Text(
      title,
      style: theme.textTheme.labelSmall?.copyWith(
        color: scheme.primary,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme scheme, String message) {
    return ObsidianCard(
      level: ObsidianCardTonalLevel.low,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  _PendingReminderDescriptor? _describePendingReminder(
    PendingNotificationRequest request,
  ) {
    final payload = request.payload;
    if (payload == null || payload.isEmpty) return null;
    final parts = payload.split(':');
    if (parts.length < 3) return null;

    final prefix = parts[0];
    final entityId = int.tryParse(parts[1]);
    final bucketToken = parts[2].toUpperCase();
    final bucketHours = bucketToken == 'DUE'
        ? 0
        : int.tryParse(bucketToken.replaceAll('H', ''));

    String title;
    if (prefix == 'vaultspend-recurring-expense') {
      final expense = entityId == null ? null : _expenseById[entityId];
      title = expense?.note ?? 'Recurring Expense';
    } else if (prefix == 'vaultspend-renewal') {
      final sub = entityId == null ? null : _subscriptionById[entityId];
      title = sub?.name ?? 'Subscription Renewal';
    } else {
      title = 'System Reminder';
    }

    return _PendingReminderDescriptor(
      kind: prefix,
      entityId: entityId,
      bucketHours: bucketHours,
      bucketToken: bucketToken,
      rawPayload: payload,
      title: title,
      summary: 'Fires $bucketToken',
    );
  }

  DateTime? _computeReminderTrigger(_PendingReminderDescriptor? descriptor) {
    if (descriptor == null || descriptor.entityId == null) return null;
    DateTime? dueDate;
    if (descriptor.kind == 'vaultspend-renewal') {
      dueDate = _subscriptionById[descriptor.entityId]?.nextBillingDate;
    } else if (descriptor.kind == 'vaultspend-recurring-expense') {
      final expense = _expenseById[descriptor.entityId];
      if (expense != null) {
        dueDate = ReminderPlanning.nextMonthlyOccurrence(
          expense.occurredAt,
          DateTime.now(),
        );
      }
    }
    if (dueDate == null) return null;
    if (descriptor.bucketToken == 'DUE') return dueDate;
    return descriptor.bucketHours == null
        ? null
        : dueDate.subtract(Duration(hours: descriptor.bucketHours!));
  }
}

class _DiagnosticsOverviewCard extends StatelessWidget {
  const _DiagnosticsOverviewCard({
    required this.efficiency,
    required this.healthy,
    required this.lastSync,
  });

  final int efficiency;
  final bool healthy;
  final DateTime? lastSync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final sync = lastSync == null
        ? 'Never'
        : formatTimeRemainingLabel(
            lastSync!,
          ).replaceFirst('In ', '').replaceFirst('in ', '');

    return ObsidianCard(
      level: ObsidianCardTonalLevel.high,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$efficiency%',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
                ),
                Text(
                  'Efficiency',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  healthy ? 'SYSTEM OPTIMIZED' : 'ATTENTION REQUIRED',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: healthy ? scheme.primary : scheme.tertiary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Last full sync: $sync',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Icon(
              healthy
                  ? Icons.check_circle_outline_rounded
                  : Icons.warning_amber_rounded,
              color: healthy ? scheme.primary : scheme.tertiary,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveQueuesCard extends StatelessWidget {
  const _ActiveQueuesCard({
    required this.totalJobs,
    required this.subscriptionCount,
    required this.recurringCount,
    required this.nextSubscriptionTrigger,
    required this.nextRecurringTrigger,
  });

  final int totalJobs;
  final int subscriptionCount;
  final int recurringCount;
  final DateTime? nextSubscriptionTrigger;
  final DateTime? nextRecurringTrigger;

  String _nextLabel(DateTime? trigger) {
    if (trigger == null) {
      return '--';
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(trigger.year, trigger.month, trigger.day);
    if (day == today) {
      return 'Today, ${DateFormat('HH:mm').format(trigger)}';
    }
    if (day == today.add(const Duration(days: 1))) {
      return 'Tomorrow, ${DateFormat('HH:mm').format(trigger)}';
    }
    return DateFormat('MMM d, HH:mm').format(trigger);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ObsidianCard(
      level: ObsidianCardTonalLevel.low,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$totalJobs Total Jobs',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'subscriptions',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          _QueueLane(
            icon: Icons.subscriptions_rounded,
            title: 'Subscription Reminders',
            subtitle: 'Scheduled Trackers',
            count: subscriptionCount,
            nextTrigger: _nextLabel(nextSubscriptionTrigger),
          ),
          const SizedBox(height: 10),
          _QueueLane(
            icon: Icons.repeat_rounded,
            title: 'Recurring Expenses',
            subtitle: 'Fixed Liabilities',
            count: recurringCount,
            nextTrigger: _nextLabel(nextRecurringTrigger),
          ),
        ],
      ),
    );
  }
}

class _QueueLane extends StatelessWidget {
  const _QueueLane({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.nextTrigger,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int count;
  final String nextTrigger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                count.toString().padLeft(2, '0'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Next Trigger',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Text(
                nextTrigger,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TriggerItem extends StatelessWidget {
  const _TriggerItem({required this.entry});

  final _ReminderLogEntry entry;

  String _dueLabel(DateTime? triggerDate) {
    if (triggerDate == null) {
      return 'Due date unavailable';
    }
    final relative = formatTimeRemainingLabel(triggerDate);
    if (relative.toLowerCase().startsWith('in ')) {
      return 'Due in ${relative.substring(3)}';
    }
    return 'Due ${relative.toLowerCase()}';
  }

  IconData _kindIcon(_PendingReminderDescriptor? descriptor) {
    switch (descriptor?.kind) {
      case 'vaultspend-renewal':
        return Icons.subscriptions_rounded;
      case 'vaultspend-recurring-expense':
        return Icons.payments_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  String _kindLabel(_PendingReminderDescriptor? descriptor) {
    switch (descriptor?.kind) {
      case 'vaultspend-renewal':
        return 'subscriptions';
      case 'vaultspend-recurring-expense':
        return 'payments';
      default:
        return 'reminders';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final triggerDate = entry.triggerDate;
    final descriptor = entry.descriptor;
    final timeStr = triggerDate != null
        ? DateFormat('MMM d, y · HH:mm').format(triggerDate)
        : 'Unknown time';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ObsidianCard(
        level: ObsidianCardTonalLevel.low,
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Icon(
                _kindIcon(descriptor),
                size: 18,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    descriptor?.title ?? entry.request.title ?? 'Reminder',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Scheduled: $timeStr',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _StatusPill(
                        label: _dueLabel(triggerDate),
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _kindLabel(descriptor),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _ReminderLogEntry {
  const _ReminderLogEntry({
    required this.request,
    required this.descriptor,
    required this.triggerDate,
  });

  final PendingNotificationRequest request;
  final _PendingReminderDescriptor? descriptor;
  final DateTime? triggerDate;
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
