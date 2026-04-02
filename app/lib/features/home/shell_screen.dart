import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../auth/auth_providers.dart';
import '../categories/manage_categories_screen.dart';
import '../expenses/expense_list_screen.dart';
import '../expenses/expense_providers.dart';
import '../subscriptions/subscription_list_screen.dart';
import '../subscriptions/subscription_providers.dart';

class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  final GlobalKey<ScaffoldState> _shellKey = GlobalKey<ScaffoldState>();
  int _index = 0;
  bool _syncing = false;

  void _openDrawer() => _shellKey.currentState?.openDrawer();

  Future<void> _syncNow() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      ref.invalidate(categoryListProvider);
      ref.invalidate(expenseListProvider);
      ref.invalidate(subscriptionListProvider);
      await Future.wait([
        ref.read(categoryListProvider.future),
        ref.read(expenseListProvider.future),
        ref.read(subscriptionListProvider.future),
      ]);
      ref.invalidate(syncStatusProvider);
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authSession = ref.watch(authControllerProvider).value;
    final isGuest = ref.watch(isGuestModeProvider);
    final signedIn = authSession != null;
    final email = signedIn ? authSession.user.email : 'Guest mode';
    final subtitle = signedIn ? 'Signed in' : 'Local-only (sync disabled)';

    return Scaffold(
      key: _shellKey,
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    'VaultSpend',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              ListTile(title: Text(email), subtitle: Text(subtitle)),
              if (signedIn)
                ListTile(
                  leading: const Icon(Icons.cloud_sync_outlined),
                  title: const Text('Account sync'),
                  subtitle: Text(
                    _syncing
                        ? 'Syncing now…'
                        : 'Local data synced with account',
                  ),
                ),
              ListTile(
                leading: const Icon(Icons.category_outlined),
                title: const Text('Categories'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const ManageCategoriesScreen(),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              if (signedIn) ...[
                const _SyncStatusTile(),
                ListTile(
                  leading: const Icon(Icons.sync),
                  title: Text(_syncing ? 'Syncing…' : 'Sync now'),
                  subtitle: const Text('Pull remote changes into this device'),
                  onTap: _syncing ? null : _syncNow,
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Sign out'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await ref.read(authControllerProvider.notifier).signOut();
                  },
                ),
              ] else if (isGuest) ...[
                ListTile(
                  leading: const Icon(Icons.login),
                  title: const Text('Sign in or create account'),
                  subtitle: const Text('Enable sync across devices'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await ref
                        .read(guestModeControllerProvider.notifier)
                        .exitGuestMode();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          _ShellStatusBanner(
            signedIn: signedIn,
            isGuest: isGuest,
            syncing: _syncing,
            onSyncNow: signedIn && !_syncing ? _syncNow : null,
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _index == 0
                  ? ExpenseListScreen(
                      key: const ValueKey(0),
                      onOpenDrawer: _openDrawer,
                    )
                  : SubscriptionListScreen(
                      key: const ValueKey(1),
                      onOpenDrawer: _openDrawer,
                    ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Expenses',
          ),
          NavigationDestination(
            icon: Icon(Icons.subscriptions_outlined),
            selectedIcon: Icon(Icons.subscriptions),
            label: 'Subscriptions',
          ),
        ],
      ),
    );
  }
}

class _ShellStatusBanner extends StatelessWidget {
  const _ShellStatusBanner({
    required this.signedIn,
    required this.isGuest,
    required this.syncing,
    required this.onSyncNow,
  });

  final bool signedIn;
  final bool isGuest;
  final bool syncing;
  final VoidCallback? onSyncNow;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final IconData icon;
    final Color background;
    final Color foreground;
    final String title;
    final String subtitle;
    final String? actionLabel;

    if (signedIn) {
      icon = syncing ? Icons.sync : Icons.cloud_done_outlined;
      background = colorScheme.primaryContainer;
      foreground = colorScheme.onPrimaryContainer;
      title = syncing ? 'Syncing account data' : 'Account sync active';
      subtitle = syncing
          ? 'Pulling remote changes into this device.'
          : 'Local data can sync with your VaultSpend account.';
      actionLabel = syncing ? null : 'Sync now';
    } else if (isGuest) {
      icon = Icons.person_outline;
      background = colorScheme.secondaryContainer;
      foreground = colorScheme.onSecondaryContainer;
      title = 'Guest mode';
      subtitle = 'Local-only storage is active. Sign in to enable sync.';
      actionLabel = null;
    } else {
      icon = Icons.lock_outline;
      background = colorScheme.surfaceContainerHighest;
      foreground = colorScheme.onSurfaceVariant;
      title = 'Not signed in';
      subtitle = 'Use guest mode for local-only storage or sign in for sync.';
      actionLabel = null;
    }

    return Material(
      color: background,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: foreground),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: foreground.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              if (actionLabel != null)
                TextButton(onPressed: onSyncNow, child: Text(actionLabel)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncStatusTile extends ConsumerWidget {
  const _SyncStatusTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(syncStatusProvider);
    final dateFmt = DateFormat.yMMMd().add_jm();

    return async.when(
      loading: () => const ListTile(
        leading: Icon(Icons.cloud_sync_outlined),
        title: Text('Sync status'),
        subtitle: Text('Loading…'),
      ),
      error: (e, _) => ListTile(
        leading: const Icon(Icons.cloud_off_outlined),
        title: const Text('Sync status'),
        subtitle: Text('Unavailable: $e'),
      ),
      data: (s) {
        String line(String label, int count, DateTime? last) {
          final lastText = last == null
              ? 'never'
              : dateFmt.format(last.toLocal());
          return '$label: $count (last: $lastText)';
        }

        return ListTile(
          leading: const Icon(Icons.cloud_done_outlined),
          title: const Text('Sync status'),
          subtitle: Text(
            [
              line(
                'Categories',
                s.categories.count,
                s.categories.lastUpdatedAt,
              ),
              line('Expenses', s.expenses.count, s.expenses.lastUpdatedAt),
              line(
                'Subscriptions',
                s.subscriptions.count,
                s.subscriptions.lastUpdatedAt,
              ),
            ].join('\n'),
          ),
          isThreeLine: true,
        );
      },
    );
  }
}
