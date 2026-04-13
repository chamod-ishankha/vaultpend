import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/logging/app_logging.dart';
import '../../core/network/network_providers.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
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

import 'widgets/shell_bottom_nav_bar.dart';
import 'widgets/shell_desktop_rail.dart';
import 'widgets/shell_sidebar_drawer.dart';
import 'widgets/shell_status_banner.dart';

class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  final GlobalKey<ScaffoldState> _shellKey = GlobalKey<ScaffoldState>();
  late final PageController _pageController;
  int _index = 0;
  bool _syncing = false;
  ProviderSubscription<AsyncValue<bool>>? _networkSub;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _index);
    _networkSub = ref.listenManual<AsyncValue<bool>>(networkOnlineProvider, (
      previous,
      next,
    ) {
      final wasOnline = previous?.value ?? true;
      final isOnline = next.value ?? true;
      if (!wasOnline && isOnline) {
        final auth = ref.read(authControllerProvider);
        if (auth.value != null && auth.value != null) {
          unawaited(_syncNow());
        }
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _networkSub?.close();
    super.dispose();
  }

  void _openDrawer() => _shellKey.currentState?.openDrawer();

  void _onPageChanged(int index) {
    if (_index != index) {
      setState(() => _index = index);
    }
  }

  void _onNavSelected(int index) {
    if (_index == index) return;
    setState(() => _index = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCirc,
    );
  }

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

  String? _cloudSubtitle(AsyncValue<SyncStatus>? syncStatusAsync) {
    if (syncStatusAsync == null) return null;
    final dateFmt = DateFormat('MMM d, yyyy h:mm a');
    return syncStatusAsync.when(
      loading: () => 'Checking Cloud sync status...',
      error: (_, _) => 'Cloud status unavailable right now.',
      data: (status) {
        if (status.totalCount == 0) {
          return 'Connected to Cloud. No synced records yet.';
        }
        final latest = status.latestUpdatedAt;
        if (latest == null) {
          return 'Connected to Cloud. Waiting for first sync timestamp.';
        }
        return 'Last Cloud update: \${dateFmt.format(latest.toLocal())}';
      },
    );
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
    final subtitle = signedIn ? 'Premium Member' : 'Local-only (sync disabled)';

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      key: _shellKey,
      backgroundColor: scheme.surface,
      extendBody: true, // Needed to let background bleed behind bottom nav
      drawer: isDesktop
          ? null
          : ShellSidebarDrawer(
              email: email,
              subtitle: subtitle,
              signedIn: signedIn,
              isGuest: isGuest,
              onTransactionsTap: () => Navigator.pop(context),
              onCategoriesTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ManageCategoriesScreen(),
                  ),
                );
              },
              onSettingsTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
              onAuthTap: () async {
                Navigator.pop(context);
                if (signedIn) {
                  await ref.read(authControllerProvider.notifier).signOut();
                } else if (isGuest) {
                  await ref
                      .read(guestModeControllerProvider.notifier)
                      .exitGuestMode();
                }
              },
            ),
      body: Row(
        children: [
          if (isDesktop)
            ShellDesktopRail(
              selectedIndex: _index,
              onDestinationSelected: _onNavSelected,
              signedIn: signedIn,
              isGuest: isGuest,
              isSyncing: _syncing,
              onCategoriesTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ManageCategoriesScreen(),
                ),
              ),
              onSettingsTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
              onSyncTap: _syncNow,
              onAuthTap: () async {
                if (signedIn) {
                  await ref.read(authControllerProvider.notifier).signOut();
                } else if (isGuest) {
                  await ref
                      .read(guestModeControllerProvider.notifier)
                      .exitGuestMode();
                }
              },
            ),
          Expanded(
            child: Stack(
              children: [
                Column(
                  children: [
                    ShellStatusBanner(
                      signedIn: signedIn,
                      isGuest: isGuest,
                      online: online,
                      syncing: _syncing,
                      cloudSubtitle: _cloudSubtitle(syncStatusAsync),
                      onSyncNow: signedIn && !_syncing ? _syncNow : null,
                    ),
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: _onPageChanged,
                        children: [
                          ExpenseListScreen(
                            onOpenDrawer: isDesktop ? null : _openDrawer,
                          ),
                          SubscriptionListScreen(
                            onOpenDrawer: isDesktop ? null : _openDrawer,
                          ),
                          InsightsScreen(
                            onOpenDrawer: isDesktop ? null : _openDrawer,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!isDesktop) ...[
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: ShellBottomNavBar(
                      selectedIndex: _index,
                      onDestinationSelected: _onNavSelected,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
