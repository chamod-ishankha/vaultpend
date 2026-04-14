import 'package:flutter/material.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/user_profile_avatar.dart';

class ShellSidebarDrawer extends StatelessWidget {
  const ShellSidebarDrawer({
    super.key,
    required this.email,
    required this.subtitle,
    required this.signedIn,
    required this.isGuest,
    required this.onTransactionsTap,
    required this.onCategoriesTap,
    required this.onSettingsTap,
    required this.onAuthTap,
  });

  final String? email;
  final String subtitle;
  final bool signedIn;
  final bool isGuest;
  final VoidCallback onTransactionsTap;
  final VoidCallback onCategoriesTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onAuthTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final displayName = signedIn
        ? (email?.split('@').first ?? 'Member')
        : 'Guest User';

    return Drawer(
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(
          right: Radius.circular(AppDimensions.radiusLarge),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.sp24,
                AppDimensions.sp24,
                AppDimensions.sp24,
                AppDimensions.sp24,
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: const UserProfileAvatar(size: 46),
                  ),
                  const SizedBox(width: AppDimensions.sp16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: AppTypography.title2(Theme.of(context))
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.primary,
                            ),
                      ),
                      Text(
                        subtitle,
                        style: AppTypography.labelMedium(
                          Theme.of(context),
                        )?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Drawer Items
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.sp16,
              ),
              child: Column(
                children: [
                  _buildDrawerItem(
                    context,
                    icon: AppIcons.expensesActive,
                    label: 'Transactions',
                    isActive: true,
                    scheme: scheme,
                    onTap: onTransactionsTap,
                  ),
                  const SizedBox(height: AppDimensions.sp8),
                  _buildDrawerItem(
                    context,
                    icon: AppIcons.categories,
                    label: AppStrings.navCategories,
                    isActive: false,
                    scheme: scheme,
                    onTap: onCategoriesTap,
                  ),
                  const SizedBox(height: AppDimensions.sp8),
                  _buildDrawerItem(
                    context,
                    icon: AppIcons.settings,
                    label: AppStrings.navSettings,
                    isActive: false,
                    scheme: scheme,
                    onTap: onSettingsTap,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppDimensions.sp24),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.sp32,
              ),
              child: Divider(
                height: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(height: AppDimensions.sp16),
            if (signedIn)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.sp16,
                ),
                child: _buildDrawerItem(
                  context,
                  icon: AppIcons.logout,
                  label: AppStrings.signOut,
                  isActive: false,
                  scheme: scheme,
                  onTap: onAuthTap,
                ),
              )
            else if (isGuest)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.sp16,
                ),
                child: _buildDrawerItem(
                  context,
                  icon: AppIcons.login,
                  label: AppStrings.signIn,
                  isActive: false,
                  scheme: scheme,
                  onTap: onAuthTap,
                ),
              ),

            const Spacer(),

            // Drawer Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.sp24,
                0,
                AppDimensions.sp24,
                AppDimensions.sp16,
              ),
              child: Text(
                AppStrings.systemId,
                style: AppTypography.labelSmall(Theme.of(context))?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  fontSize: 10,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isActive,
    required ColorScheme scheme,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      child: Container(
        decoration: BoxDecoration(
          color: isActive
              ? scheme.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          border: Border(
            right: isActive
                ? BorderSide(color: scheme.primary, width: 4)
                : BorderSide.none,
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.sp16,
          vertical: AppDimensions.sp12,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isActive ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppDimensions.sp16),
            Text(
              label,
              style: AppTypography.subtitle2(Theme.of(context))?.copyWith(
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
