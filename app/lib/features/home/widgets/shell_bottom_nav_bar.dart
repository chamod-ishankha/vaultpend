import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_strings.dart';

class ShellBottomNavBar extends StatelessWidget {
  const ShellBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppDimensions.radiusXLarge),
      ),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: AppDimensions.shellBottomNavBaseHeight + bottomInset,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow.withValues(alpha: 0.9),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
          ),
          padding: EdgeInsets.only(bottom: AppDimensions.sp8 + bottomInset),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomNavItem(
                context,
                index: 0,
                activeIcon: AppIcons.expensesActive,
                inactiveIcon: AppIcons.expensesInactive,
                label: AppStrings.navExpenses,
                scheme: scheme,
              ),
              _buildBottomNavItem(
                context,
                index: 1,
                activeIcon: AppIcons.subscriptionsActive,
                inactiveIcon: AppIcons.subscriptionsInactive,
                label: AppStrings.navSubscriptions,
                scheme: scheme,
              ),
              _buildBottomNavItem(
                context,
                index: 2,
                activeIcon: AppIcons.insightsActive,
                inactiveIcon: AppIcons.insightsInactive,
                label: AppStrings.navInsights,
                scheme: scheme,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(
    BuildContext context, {
    required int index,
    required IconData activeIcon,
    required IconData inactiveIcon,
    required String label,
    required ColorScheme scheme,
  }) {
    final isActive = selectedIndex == index;
    final color = isActive ? scheme.primary : scheme.outline;
    final textTheme = Theme.of(context).textTheme;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onDestinationSelected(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : inactiveIcon,
              color: color,
              size: AppDimensions.iconSizeLarge + 2,
            ),
            const SizedBox(height: AppDimensions.sp4),
            Text(
              label.toUpperCase(),
              style: textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 1.2,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: AppDimensions.sp4),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? scheme.primary : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
