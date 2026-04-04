import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/logging/app_logging.dart';
import '../../core/network/network_providers.dart';
import '../../core/providers.dart';
import '../../core/widgets/responsive_layout.dart';
import '../auth/auth_providers.dart';
import '../auth/sync_status.dart';
import '../categories/manage_categories_screen.dart';
import '../expenses/expense_list_screen.dart';
import '../expenses/expense_providers.dart';
import '../insights/insights_screen.dart';
import '../settings/settings_screen.dart';
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
  ProviderSubscription<AsyncValue<bool>>? _networkSub;

  @override
  void initState() {
    super.initState();
    _networkSub = ref.listenManual<AsyncValue<bool>>(networkOnlineProvider, (
      previous,
      next,
    ) {
      final wasOnline = previous?.value ?? true;
      final isOnline = next.value ?? true;
      if (!wasOnline && isOnline) {
        final signedIn = ref.read(authControllerProvider).value != null;
        if (signedIn) {
          unawaited(_syncNow());
        }
      }
    });
  }

  @override
  void dispose() {
    _networkSub?.close();
    super.dispose();
  }

  void _openDrawer() => _shellKey.currentState?.openDrawer();

  Future<void> _syncNow() async {
    if (_syncing) return;
    final online = ref.read(networkOnlineProvider).value ?? true;
    if (!online) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Offline mode active. Changes are saved locally and will sync when online.',
          ),
        ),
      );
      return;
    }
    setState(() => _syncing = true);
    try {
      await Future.wait([
        ref.read(activityLogServiceProvider).syncPendingToDatabase(),
        ref.read(syncIncidentServiceProvider).syncPendingToDatabase(),
      ]);
      ref.invalidate(categoryListProvider);
      ref.invalidate(expenseListProvider);
      ref.invalidate(subscriptionListProvider);
      await Future.wait([
        ref.read(categoryListProvider.future),
        ref.read(expenseListProvider.future),
        ref.read(subscriptionListProvider.future),
      ]);
      ref.invalidate(syncStatusProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Cloud sync completed.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed. Using local mode: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = isDesktopWidth(MediaQuery.sizeOf(context).width);
    final authSession = ref.watch(authControllerProvider).value;
    final isGuest = ref.watch(isGuestModeProvider);
    final online = ref.watch(networkOnlineProvider).value ?? true;
    final signedIn = authSession != null;
    final syncStatusAsync = signedIn ? ref.watch(syncStatusProvider) : null;
    final email = signedIn ? authSession.user.email : 'Guest mode';
    final subtitle = signedIn ? 'Signed in' : 'Local-only (sync disabled)';

    final screenChild = _index == 0
        ? ExpenseListScreen(
            key: const ValueKey(0),
            onOpenDrawer: isDesktop ? null : _openDrawer,
          )
        : _index == 1
        ? SubscriptionListScreen(
            key: const ValueKey(1),
            onOpenDrawer: isDesktop ? null : _openDrawer,
          )
        : InsightsScreen(
            key: const ValueKey(2),
            onOpenDrawer: isDesktop ? null : _openDrawer,
          );

    return Scaffold(
      key: _shellKey,
      drawer: isDesktop
          ? null
          : Drawer(
              child: SafeArea(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    DrawerHeader(
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Image.asset(
                            'assets/branding/logo.png',
                            fit: BoxFit.contain,
                          ),
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
                    ListTile(
                      leading: const Icon(Icons.settings_outlined),
                      title: const Text('Settings'),
                      subtitle: const Text('Reminders, diagnostics, and logs'),
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => const SettingsScreen(),
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
                        subtitle: const Text(
                          'Pull remote changes into this device',
                        ),
                        onTap: _syncing ? null : _syncNow,
                      ),
                      ListTile(
                        leading: const Icon(Icons.logout),
                        title: const Text('Sign out'),
                        onTap: () async {
                          Navigator.of(context).pop();
                          await ref
                              .read(authControllerProvider.notifier)
                              .signOut();
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
      body: Row(
        children: [
          if (isDesktop)
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: Image.asset(
                    'assets/branding/app_icon.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              trailing: Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: 'Categories',
                      onPressed: () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => const ManageCategoriesScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.category_outlined),
                    ),
                    IconButton(
                      tooltip: 'Settings',
                      onPressed: () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => const SettingsScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.settings_outlined),
                    ),
                    if (signedIn)
                      IconButton(
                        tooltip: _syncing ? 'Syncing...' : 'Sync now',
                        onPressed: _syncing ? null : _syncNow,
                        icon: const Icon(Icons.sync),
                      ),
                    if (isGuest)
                      IconButton(
                        tooltip: 'Guest mode',
                        onPressed: null,
                        icon: const Icon(Icons.person_outline),
                      ),
                    const SizedBox(height: 8),
                    IconButton(
                      tooltip: signedIn
                          ? 'Sign out'
                          : 'Sign in or create account',
                      onPressed: () async {
                        if (signedIn) {
                          await ref
                              .read(authControllerProvider.notifier)
                              .signOut();
                        } else if (isGuest) {
                          await ref
                              .read(guestModeControllerProvider.notifier)
                              .exitGuestMode();
                        }
                      },
                      icon: Icon(signedIn ? Icons.logout : Icons.login),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long),
                  label: Text('Expenses'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.subscriptions_outlined),
                  selectedIcon: Icon(Icons.subscriptions),
                  label: Text('Subscriptions'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.insights_outlined),
                  selectedIcon: Icon(Icons.insights),
                  label: Text('Insights'),
                ),
              ],
            ),
          Expanded(
            child: Column(
              children: [
                _ShellStatusBanner(
                  signedIn: signedIn,
                  isGuest: isGuest,
                  online: online,
                  syncing: _syncing,
                  cloudSubtitle: _cloudSubtitle(syncStatusAsync),
                  onSyncNow: signedIn && !_syncing ? _syncNow : null,
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: screenChild,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isDesktop
          ? null
          : NavigationBar(
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
                NavigationDestination(
                  icon: Icon(Icons.insights_outlined),
                  selectedIcon: Icon(Icons.insights),
                  label: 'Insights',
                ),
              ],
            ),
    );
  }

  String? _cloudSubtitle(AsyncValue<SyncStatus>? syncStatusAsync) {
    if (syncStatusAsync == null) {
      return null;
    }

    final dateFmt = DateFormat('MMM d, yyyy h:mm a');
    return syncStatusAsync.when(
      loading: () => 'Checking Cloud sync status…',
      error: (_, _) => 'Cloud status unavailable right now.',
      data: (status) {
        if (status.totalCount == 0) {
          return 'Connected to Cloud. No synced records yet.';
        }
        final latest = status.latestUpdatedAt;
        if (latest == null) {
          return 'Connected to Cloud. Waiting for first sync timestamp.';
        }
        return 'Last Cloud update: ${dateFmt.format(latest.toLocal())}';
      },
    );
  }
}

class _ShellStatusBanner extends StatelessWidget {
  const _ShellStatusBanner({
    required this.signedIn,
    required this.isGuest,
    required this.online,
    required this.syncing,
    required this.cloudSubtitle,
    required this.onSyncNow,
  });

  final bool signedIn;
  final bool isGuest;
  final bool online;
  final bool syncing;
  final String? cloudSubtitle;
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
      if (!online) {
        title = 'Offline local mode';
        subtitle =
            'No network connection. Changes are stored locally and sync when online.';
        actionLabel = null;
      } else {
        title = syncing ? 'Syncing account data' : 'Account sync active';
        subtitle = syncing
            ? 'Pulling remote changes into this device.'
            : (cloudSubtitle ?? 'Local data can sync with your Cloud account.');
        actionLabel = syncing ? null : 'Sync now';
      }
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
    final dateFmt = DateFormat('MMM d, yyyy h:mm a');

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
