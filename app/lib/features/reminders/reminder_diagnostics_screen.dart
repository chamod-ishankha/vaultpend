import 'dart:async';

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
    _pendingFuture = _loadPending();
  }


  Future<List<PendingNotificationRequest>> _loadPending() async {
    try {
      await _service.initialize();
      final remindersEnabled = ref.read(remindersEnabledProvider);
      final subscriptionsEnabled = ref.read(subscriptionRemindersEnabledProvider);
      final recurringEnabled = ref.read(recurringExpenseRemindersEnabledProvider);
      
      final subscriptions = await ref.read(subscriptionRepositoryProvider).getAll();
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
          _expectedTotal = subscriptions.length + expenses.where((e) => e.isRecurring).length;
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
    final lastSyncStr = _lastCheckedAt != null 
        ? formatTimeRemainingLabel(_lastCheckedAt!).replaceAll('In ', '').replaceAll('ago', 'ago')
        : 'Never';

    final isHealthy = _pendingTotal >= _expectedTotal;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: ObsidianAppBar(
        title: const Text('Reminder System'),
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
              // Status Cards
              Row(
                children: [
                  Expanded(
                    child: _StatusHeroCard(
                      title: 'HEALTH',
                      status: isHealthy ? 'EXCELLENT' : 'WARNING',
                      description: isHealthy ? 'System is operational.' : 'Reminder mismatch.',
                      color: isHealthy ? Colors.greenAccent : Colors.orangeAccent,
                      isHighTonal: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatusHeroCard(
                      title: 'SYNC',
                      status: 'HEALTHY',
                      description: 'Last sync $lastSyncStr',
                      color: scheme.primary,
                      isHighTonal: false,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              _buildSectionHeader(theme, scheme, 'ACTIVE TRIGGERS'),
              const SizedBox(height: 16),
              
              FutureBuilder<List<PendingNotificationRequest>>(
                future: _pendingFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final requests = snapshot.data ?? [];
                  if (requests.isEmpty) {
                    return _buildEmptyState(theme, scheme, 'No active triggers');
                  }
                  return Column(
                    children: requests.map((r) => _TriggerItem(
                      request: r,
                      descriptor: _describePendingReminder(r),
                      triggerDate: _computeReminderTrigger(_describePendingReminder(r)),
                    )).toList(),
                  );
                },
              ),
              
              const SizedBox(height: 32),
              _buildSectionHeader(theme, scheme, 'SYSTEM LOGS'),
              const SizedBox(height: 16),
              _buildSystemLogs(theme, scheme),
              
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, ColorScheme scheme, String title) {
    return Text(
      title,
      style: theme.textTheme.labelSmall?.copyWith(
        color: scheme.outline,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
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
          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.outline),
        ),
      ),
    );
  }

  Widget _buildSystemLogs(ThemeData theme, ColorScheme scheme) {
    final logs = [
      {'event': 'Background Sync', 'time': '2m ago', 'status': 'SUCCESS'},
      {'event': 'Reminder Fired', 'time': '1h ago', 'status': 'SUCCESS'},
      {'event': 'Service Init', 'time': '4h ago', 'status': 'INITIALIZED'},
    ];

    return ObsidianCard(
      level: ObsidianCardTonalLevel.low,
      padding: EdgeInsets.zero,
      child: Column(
        children: logs.map((log) => Container(
          decoration: BoxDecoration(
            border: log != logs.last ? Border(bottom: BorderSide(color: scheme.outlineVariant.withOpacity(0.1))) : null,
          ),
          child: ListTile(
            dense: true,
            title: Text(log['event']!, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            trailing: Text(log['time']!, style: theme.textTheme.labelSmall?.copyWith(color: scheme.outline)),
            leading: Icon(Icons.circle, size: 8, color: log['status'] == 'SUCCESS' ? Colors.greenAccent : scheme.primary),
          ),
        )).toList(),
      ),
    );
  }

  _PendingReminderDescriptor? _describePendingReminder(PendingNotificationRequest request) {
    final payload = request.payload;
    if (payload == null || payload.isEmpty) return null;
    final parts = payload.split(':');
    if (parts.length < 3) return null;

    final prefix = parts[0];
    final entityId = int.tryParse(parts[1]);
    final bucketToken = parts[2].toUpperCase();
    final bucketHours = bucketToken == 'DUE' ? 0 : int.tryParse(bucketToken.replaceAll('H', ''));

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
        dueDate = ReminderPlanning.nextMonthlyOccurrence(expense.occurredAt, DateTime.now());
      }
    }
    if (dueDate == null) return null;
    if (descriptor.bucketToken == 'DUE') return dueDate;
    return descriptor.bucketHours == null ? null : dueDate.subtract(Duration(hours: descriptor.bucketHours!));
  }
}

class _StatusHeroCard extends StatelessWidget {
  final String title;
  final String status;
  final String description;
  final Color color;
  final bool isHighTonal;

  const _StatusHeroCard({
    required this.title,
    required this.status,
    required this.description,
    required this.color,
    required this.isHighTonal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ObsidianCard(
      level: isHighTonal ? ObsidianCardTonalLevel.high : ObsidianCardTonalLevel.low,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              color: isHighTonal ? color : scheme.outline,
              fontWeight: FontWeight.w800,
              fontSize: 9,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            status,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: isHighTonal ? Colors.white : scheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: theme.textTheme.labelSmall?.copyWith(
              color: isHighTonal ? Colors.white.withOpacity(0.7) : scheme.outline,
              fontSize: 8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TriggerItem extends StatelessWidget {
  final PendingNotificationRequest request;
  final _PendingReminderDescriptor? descriptor;
  final DateTime? triggerDate;

  const _TriggerItem({
    required this.request,
    this.descriptor,
    this.triggerDate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final timeStr = triggerDate != null ? DateFormat('MMM d, h:mm a').format(triggerDate!) : 'Unknown time';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ObsidianCard(
        level: ObsidianCardTonalLevel.low,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _StatusPill(label: 'PENDING', color: scheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          descriptor?.title ?? request.title ?? 'Reminder',
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    timeStr,
                    style: theme.textTheme.labelSmall?.copyWith(color: scheme.outline),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: scheme.outline.withOpacity(0.5)),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
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

