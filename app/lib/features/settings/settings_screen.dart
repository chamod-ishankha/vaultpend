import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/obsidian_app_bar.dart';
import '../../core/widgets/obsidian_card.dart';
import '../activity/activity_log_screen.dart';
import '../auth/auth_providers.dart';
import '../auth/login_screen.dart';
import '../reminders/reminder_diagnostics_screen.dart';
import '../reminders/sync_incident_screen.dart';
import 'profile_update_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final authSession = ref.watch(authControllerProvider).value;
    final remindersEnabled = ref.watch(remindersEnabledProvider);
    final subscriptionRemindersEnabled = ref.watch(
      subscriptionRemindersEnabledProvider,
    );
    final recurringExpenseRemindersEnabled = ref.watch(
      recurringExpenseRemindersEnabledProvider,
    );
    final preferredCurrency = ref.watch(preferredCurrencyProvider);
    final signedIn = authSession != null;
    final profileTitle = signedIn ? authSession.user.email : 'Guest mode';
    final profileSubtitle = signedIn
        ? 'Preferred currency: $preferredCurrency'
        : 'Sign in to edit email and profile preferences';

    return Scaffold(
      appBar: ObsidianAppBar(
        centerTitle: false,
        title: Text(
          'Settings',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
              color: scheme.surfaceContainerLow,
            ),
            child: Icon(Icons.person, size: 18, color: scheme.primary),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          Text(
            'Profile',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          ObsidianCard(
            level: ObsidianCardTonalLevel.low,
            onTap: () {
              if (!signedIn) {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
                );
                return;
              }
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const ProfileUpdateScreen(),
                ),
              );
            },
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: scheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.person_rounded, color: scheme.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profileTitle,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        profileSubtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Reminders',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          ObsidianCard(
            level: ObsidianCardTonalLevel.low,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(
                    remindersEnabled
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_off_rounded,
                    color: remindersEnabled ? scheme.primary : scheme.outline,
                  ),
                  title: Text(
                    'Renewal reminders',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    remindersEnabled
                        ? 'Subscription and recurring reminders are on'
                        : 'All renewal reminders are off',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  value: remindersEnabled,
                  onChanged: (value) {
                    ref
                        .read(remindersEnabledControllerProvider.notifier)
                        .setEnabled(value);
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(height: 1, thickness: 0.5),
                ),
                SwitchListTile(
                  secondary: Icon(
                    Icons.subscriptions_rounded,
                    size: 22,
                    color: scheme.onSurfaceVariant,
                  ),
                  title: Text(
                    'Subscription reminders',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    remindersEnabled
                        ? '24h/48h reminders for subscription renewals'
                        : 'Disabled while main switch is off',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
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
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(height: 1, thickness: 0.5),
                ),
                SwitchListTile(
                  secondary: Icon(
                    Icons.repeat_rounded,
                    size: 22,
                    color: scheme.onSurfaceVariant,
                  ),
                  title: Text(
                    'Recurring expense reminders',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    remindersEnabled
                        ? '24h/48h reminders for recurring expenses'
                        : 'Disabled while main switch is off',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
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
            'Diagnostics & Logs',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          ObsidianCard(
            level: ObsidianCardTonalLevel.low,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.bug_report_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                  title: Text(
                    'Reminder diagnostics',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'View pending reminder jobs',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                  onTap: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const ReminderDiagnosticsScreen(),
                      ),
                    );
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(height: 1, thickness: 0.5),
                ),
                ListTile(
                  leading: Icon(
                    Icons.sync_problem_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                  title: Text(
                    'Sync incidents',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Open incident history',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                  onTap: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const SyncIncidentScreen(),
                      ),
                    );
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(height: 1, thickness: 0.5),
                ),
                ListTile(
                  leading: Icon(
                    Icons.history_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                  title: Text(
                    'Activity log',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'See your recent actions',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
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
