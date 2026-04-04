import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../activity/activity_log_screen.dart';
import '../auth/auth_providers.dart';
import '../reminders/reminder_diagnostics_screen.dart';
import '../reminders/sync_incident_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _currencies = ['LKR', 'USD', 'EUR'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersEnabled = ref.watch(remindersEnabledProvider);
    final subscriptionRemindersEnabled = ref.watch(
      subscriptionRemindersEnabledProvider,
    );
    final recurringExpenseRemindersEnabled = ref.watch(
      recurringExpenseRemindersEnabledProvider,
    );
    final preferredCurrency = ref.watch(preferredCurrencyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          Text(
            'Profile',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: DropdownButtonFormField<String>(
                initialValue: preferredCurrency,
                decoration: const InputDecoration(
                  labelText: 'Preferred currency (base)',
                  border: OutlineInputBorder(),
                ),
                items: _currencies
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  ref
                      .read(preferredCurrencyControllerProvider.notifier)
                      .setPreferredCurrency(value);
                },
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Reminder controls',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(
                    remindersEnabled
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_off_outlined,
                  ),
                  title: const Text('Renewal reminders'),
                  subtitle: Text(
                    remindersEnabled
                        ? 'Subscription and recurring reminders are on'
                        : 'All renewal reminders are off',
                  ),
                  value: remindersEnabled,
                  onChanged: (value) {
                    ref
                        .read(remindersEnabledControllerProvider.notifier)
                        .setEnabled(value);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.subscriptions_outlined),
                  title: const Text('Subscription reminders'),
                  subtitle: Text(
                    remindersEnabled
                        ? '24h/48h reminders for subscription renewals'
                        : 'Disabled while Renewal reminders is off',
                  ),
                  value: subscriptionRemindersEnabled,
                  onChanged: (value) {
                    ref
                        .read(
                          subscriptionRemindersEnabledControllerProvider
                              .notifier,
                        )
                        .setEnabled(value);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.repeat_outlined),
                  title: const Text('Recurring expense reminders'),
                  subtitle: Text(
                    remindersEnabled
                        ? '24h/48h reminders for recurring expenses'
                        : 'Disabled while Renewal reminders is off',
                  ),
                  value: recurringExpenseRemindersEnabled,
                  onChanged: (value) {
                    ref
                        .read(
                          recurringExpenseRemindersEnabledControllerProvider
                              .notifier,
                        )
                        .setEnabled(value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Diagnostics and logs',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.bug_report_outlined),
                  title: const Text('Reminder diagnostics'),
                  subtitle: const Text('View pending reminder jobs'),
                  onTap: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const ReminderDiagnosticsScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.sync_problem_outlined),
                  title: const Text('Sync incidents'),
                  subtitle: const Text('Open incident history'),
                  onTap: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const SyncIncidentScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.history_outlined),
                  title: const Text('Activity log'),
                  subtitle: const Text('See your recent actions'),
                  onTap: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const ActivityLogScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
