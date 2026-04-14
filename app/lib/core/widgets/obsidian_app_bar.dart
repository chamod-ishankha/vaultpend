import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../constants/app_dimensions.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

class ObsidianAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ObsidianAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.height = AppDimensions.sp64,
    this.showBottomBorder = true,
    this.centerTitle = true,
  });

  final Widget title;
  final List<Widget>? actions;
  final Widget? leading;
  final double height;
  final bool showBottomBorder;
  final bool centerTitle;

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.vaultSpend;
    final scheme = theme.colorScheme;
    final topPadding = MediaQuery.of(context).padding.top;

    return ClipRRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: ext.glassBlur,
          sigmaY: ext.glassBlur,
        ),
        child: Container(
          height: height + topPadding,
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.6),
            border: showBottomBorder
                ? Border(
                    bottom: BorderSide(
                      color: scheme.outlineVariant.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  )
                : null,
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: leading,
            title: DefaultTextStyle.merge(
              style: AppTypography.subtitle1(theme)?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
              child: title,
            ),
            actions: actions,
            centerTitle: centerTitle,
          ),
        ),
      ),
    );
  }
}
