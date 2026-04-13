import 'package:flutter/material.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_strings.dart';

class ShellDesktopRail extends StatelessWidget {
  const ShellDesktopRail({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.signedIn,
    required this.isGuest,
    required this.isSyncing,
    required this.onCategoriesTap,
    required this.onSettingsTap,
    required this.onSyncTap,
    required this.onAuthTap,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool signedIn;
  final bool isGuest;
  final bool isSyncing;
  final VoidCallback onCategoriesTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onSyncTap;
  final VoidCallback onAuthTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return NavigationRail(
      backgroundColor: scheme.surface,
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      labelType: NavigationRailLabelType.all,
      leading: Padding(
        padding: const EdgeInsets.only(top: AppDimensions.sp8),
        child: SizedBox(
          width: AppDimensions.shellDesktopRailWidth,
          height: AppDimensions.shellDesktopRailWidth,
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
              tooltip: AppStrings.navCategories,
              onPressed: onCategoriesTap,
              icon: const Icon(AppIcons.categories),
            ),
            IconButton(
              tooltip: AppStrings.navSettings,
              onPressed: onSettingsTap,
              icon: const Icon(AppIcons.settings),
            ),
            if (signedIn)
              IconButton(
                tooltip: isSyncing ? 'Syncing...' : 'Sync now',
                onPressed: isSyncing ? null : onSyncTap,
                icon: const Icon(AppIcons.syncStatus),
              ),
            const SizedBox(height: AppDimensions.sp8),
            IconButton(
              tooltip: signedIn ? AppStrings.signOut : AppStrings.signIn,
              onPressed: onAuthTap,
              icon: Icon(signedIn ? AppIcons.logout : AppIcons.login),
            ),
            const SizedBox(height: AppDimensions.sp16),
          ],
        ),
      ),
      destinations: const [
        NavigationRailDestination(
          icon: Icon(AppIcons.expensesInactive),
          selectedIcon: Icon(AppIcons.expensesActive),
          label: Text(AppStrings.navExpenses),
        ),
        NavigationRailDestination(
          icon: Icon(AppIcons.subscriptionsInactive),
          selectedIcon: Icon(AppIcons.subscriptionsActive),
          label: Text(AppStrings.navSubscriptions),
        ),
        NavigationRailDestination(
          icon: Icon(AppIcons.insightsInactive),
          selectedIcon: Icon(AppIcons.insightsActive),
          label: Text(AppStrings.navInsights),
        ),
      ],
    );
  }
}
