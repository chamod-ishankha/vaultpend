import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../auth/auth_providers.dart';
import '../categories/manage_categories_screen.dart';
import '../expenses/expense_list_screen.dart';
import '../subscriptions/subscription_list_screen.dart';

class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  final GlobalKey<ScaffoldState> _shellKey = GlobalKey<ScaffoldState>();
  int _index = 0;

  void _openDrawer() => _shellKey.currentState?.openDrawer();

  @override
  Widget build(BuildContext context) {
    final email =
        ref.watch(authControllerProvider).value?.user.email ?? 'Account';

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
              ListTile(title: Text(email), subtitle: const Text('Signed in')),
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
              const _SyncStatusTile(),
              ListTile(
                leading: const Icon(Icons.sync),
                title: const Text('Refresh sync status'),
                onTap: () {
                  ref.invalidate(syncStatusProvider);
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sign out'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await ref.read(authControllerProvider.notifier).signOut();
                },
              ),
            ],
          ),
        ),
      ),
      body: AnimatedSwitcher(
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
