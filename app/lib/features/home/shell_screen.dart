import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

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
    _networkSub = ref.listenManual<AsyncValue<bool>>(
      networkOnlineProvider,
      (previous, next) {
        final wasOnline = previous?.value ?? true;
        final isOnline = next.value ?? true;
        if (!wasOnline && isOnline) {
          final auth = ref.read(authControllerProvider);
          if (auth.value != null && auth.value != null) {
            unawaited(_syncNow());
          }
        }
      },
    );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cloud sync completed.')),
        );
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
    final subtitle = signedIn ? 'Premium Member' : 'Local-only (sync disabled)';
    
    // Theme references
    final scheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<VaultSpendThemeExtension>()!;

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
      backgroundColor: scheme.surface,
      extendBody: true, // Needed to let background bleed behind bottom nav
      drawer: isDesktop
          ? null
          : _buildSidebarDrawer(context, scheme, ext, email, subtitle, signedIn, isGuest),
      body: Row(
        children: [
          if (isDesktop) _buildDesktopRail(scheme, signedIn, isGuest),
          Expanded(
            child: Stack(
              children: [
                Column(
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
                if (!isDesktop) ...[
                  // Bottom Navbar
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: _buildBottomNavBar(scheme, ext),
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarDrawer(BuildContext context, ColorScheme scheme, VaultSpendThemeExtension ext, String? email, String subtitle, bool signedIn, bool isGuest) {
    return Drawer(
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drawer Header
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 24, bottom: 40),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.primary.withOpacity(0.3), width: 2),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: scheme.surfaceContainerHighest,
                        ),
                        child: Icon(Icons.person, color: scheme.primary, size: 24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          email?.split('@').first ?? 'User',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w700,
                            color: scheme.primary,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          subtitle,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w500,
                            color: scheme.onSurface.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Drawer Items
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                   _buildDrawerItem(
                    icon: Icons.account_balance,
                    label: 'Accounts',
                    isActive: false,
                    scheme: scheme,
                    onTap: () {},
                  ),
                  const SizedBox(height: 8),
                  _buildDrawerItem(
                    icon: Icons.category_outlined,
                    label: 'Categories',
                    isActive: false,
                    scheme: scheme,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ManageCategoriesScreen()));
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildDrawerItem(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    isActive: false,
                    scheme: scheme,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
                    },
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  if (signedIn) ...[
                    _buildDrawerItem(
                      icon: Icons.cloud_sync_outlined,
                      label: 'Account sync',
                      isActive: false,
                      scheme: scheme,
                      onTap: () {},
                    ),
                    const SizedBox(height: 8),
                    _buildDrawerItem(
                      icon: Icons.logout,
                      label: 'Sign out',
                      isActive: false,
                      scheme: scheme,
                      onTap: () async {
                        Navigator.pop(context);
                        await ref.read(authControllerProvider.notifier).signOut();
                      },
                    ),
                  ] else if (isGuest) ...[
                    _buildDrawerItem(
                      icon: Icons.login,
                      label: 'Sign in',
                      isActive: false,
                      scheme: scheme,
                      onTap: () async {
                        Navigator.pop(context);
                        await ref.read(guestModeControllerProvider.notifier).exitGuestMode();
                      },
                    ),
                  ],
                ],
              ),
            ),
            
            const Spacer(),
            
            // Drawer Footer
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'ID: VAULT-SPEND',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: scheme.onSurface.withOpacity(0.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required ColorScheme scheme,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: isActive ? scheme.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border(
            right: isActive ? BorderSide(color: scheme.primary, width: 4) : BorderSide.none,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: isActive ? scheme.primary : scheme.onSurfaceVariant),
            const SizedBox(width: 16),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w500,
                color: isActive ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopRail(ColorScheme scheme, bool signedIn, bool isGuest) {
    return NavigationRail(
      backgroundColor: scheme.surface,
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
                  MaterialPageRoute<void>(builder: (_) => const ManageCategoriesScreen()),
                );
              },
              icon: const Icon(Icons.category_outlined),
            ),
            IconButton(
              tooltip: 'Settings',
              onPressed: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
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
            const SizedBox(height: 8),
            IconButton(
              tooltip: signedIn ? 'Sign out' : 'Sign in or create account',
              onPressed: () async {
                if (signedIn) {
                  await ref.read(authControllerProvider.notifier).signOut();
                } else if (isGuest) {
                  await ref.read(guestModeControllerProvider.notifier).exitGuestMode();
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
    );
  }

  Widget _buildBottomNavBar(ColorScheme scheme, VaultSpendThemeExtension ext) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withOpacity(0.9),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.05)),
            ),
          ),
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomNavItem(0, Icons.payments, Icons.payments_outlined, 'Expenses', scheme),
              _buildBottomNavItem(1, Icons.subscriptions, Icons.subscriptions_outlined, 'Subscriptions', scheme),
              _buildBottomNavItem(2, Icons.query_stats, Icons.query_stats_outlined, 'Insights', scheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(int index, IconData activeIcon, IconData inactiveIcon, String label, ColorScheme scheme) {
    final isActive = _index == index;
    final color = isActive ? scheme.primary : scheme.outline;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _index = index),
      child: SizedBox(
        width: 100,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isActive ? activeIcon : inactiveIcon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? scheme.primary : Colors.transparent,
              ),
            )
          ],
        ),
      ),
    );
  }

  String? _cloudSubtitle(AsyncValue<SyncStatus>? syncStatusAsync) {
    if (syncStatusAsync == null) return null;
    final dateFmt = DateFormat('MMM d, yyyy h:mm a');
    return syncStatusAsync.when(
      loading: () => 'Checking Cloud sync status…',
      error: (_, _) => 'Cloud status unavailable right now.',
      data: (status) {
        if (status.totalCount == 0) return 'Connected to Cloud. No synced records yet.';
        final latest = status.latestUpdatedAt;
        if (latest == null) return 'Connected to Cloud. Waiting for first sync timestamp.';
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
    final scheme = Theme.of(context).colorScheme;

    if (!signedIn && !isGuest) return const SizedBox.shrink();

    final IconData icon = signedIn ? (syncing ? Icons.sync : Icons.cloud_done) : Icons.person_outline;
    final String title = signedIn ? (syncing ? 'Syncing...' : 'Account sync active') : 'Guest mode active';
    final String? actionLabel = signedIn ? (online ? (syncing ? null : 'SYNC NOW') : 'OFFLINE') : null;

    return SafeArea(
      bottom: false,
      child: Container(
        decoration: BoxDecoration(
          color: signedIn ? scheme.primary : scheme.surfaceContainerHighest,
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
              Icon(icon, color: signedIn ? scheme.onPrimaryContainer : scheme.onSurfaceVariant, size: 20),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: signedIn ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          if (actionLabel != null)
            GestureDetector(
              onTap: onSyncNow,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.onPrimaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  actionLabel,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: scheme.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
    );
  }
}
