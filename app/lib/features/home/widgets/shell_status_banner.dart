import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';

class ShellStatusBanner extends StatelessWidget {
  const ShellStatusBanner({
    super.key,
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ext = theme.vaultSpend;

    if (!signedIn && !isGuest) return const SizedBox.shrink();

    final IconData icon = signedIn
        ? (syncing ? AppIcons.syncStatus : AppIcons.syncCheck)
        : AppIcons.userProfile;
    final String title = signedIn
        ? (syncing ? AppStrings.syncingLabel : AppStrings.syncHealthyLabel)
        : AppStrings.guestModeLabel;
    final String? actionLabel = signedIn
        ? (online ? (syncing ? null : 'REFRESH') : 'OFFLINE')
        : null;

    final bgColor = signedIn
        ? scheme.primary.withValues(alpha: 0.1)
        : scheme.surfaceContainerHighest.withValues(alpha: 0.5);
    final fgColor = signedIn ? scheme.primary : scheme.onSurfaceVariant;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.sp16,
          AppDimensions.sp8,
          AppDimensions.sp16,
          0,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(
              sigmaX: ext.glassBlur,
              sigmaY: ext.glassBlur,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                border: Border.all(color: fgColor.withValues(alpha: 0.1)),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.sp16,
                vertical: AppDimensions.sp12,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        _PulseIcon(icon: icon, color: fgColor, active: syncing),
                        const SizedBox(width: AppDimensions.sp12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: AppTypography.labelSmall(theme)
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: fgColor,
                                      letterSpacing: 1.2,
                                    ),
                              ),
                              if (cloudSubtitle != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  cloudSubtitle!,
                                  style: AppTypography.labelSmall(theme)
                                      ?.copyWith(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 10,
                                        color: fgColor.withValues(alpha: 0.7),
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (actionLabel != null)
                    GestureDetector(
                      onTap: onSyncNow,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.sp12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: syncing
                              ? Colors.transparent
                              : fgColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusMedium,
                          ),
                          border: Border.all(
                            color: fgColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          actionLabel,
                          style: AppTypography.labelSmall(theme)?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            fontSize: 10,
                            color: fgColor,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PulseIcon extends StatefulWidget {
  const _PulseIcon({
    required this.icon,
    required this.color,
    required this.active,
  });

  final IconData icon;
  final Color color;
  final bool active;

  @override
  State<_PulseIcon> createState() => _PulseIconState();
}

class _PulseIconState extends State<_PulseIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.active) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(_PulseIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return Icon(widget.icon, color: widget.color, size: 18);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 1.0 + (_controller.value * 0.2);
        final opacity = 1.0 - _controller.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: scale,
              child: Icon(
                widget.icon,
                color: widget.color.withValues(alpha: opacity),
                size: 18,
              ),
            ),
            Icon(widget.icon, color: widget.color, size: 18),
          ],
        );
      },
    );
  }
}
