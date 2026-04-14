import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum ObsidianCardTonalLevel { low, high, bright }

class ObsidianCard extends StatelessWidget {
  const ObsidianCard({
    super.key,
    required this.child,
    this.level = ObsidianCardTonalLevel.high,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 12.0,
    this.showGlow = false,
    this.showTopBorder = true,
    this.onTap,
  });

  final Widget child;
  final ObsidianCardTonalLevel level;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool showGlow;
  final bool showTopBorder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.vaultSpend;

    Color backgroundColor;
    switch (level) {
      case ObsidianCardTonalLevel.low:
        backgroundColor = ext.surfaceContainerLow;
        break;
      case ObsidianCardTonalLevel.high:
        backgroundColor = ext.surfaceContainerHigh;
        break;
      case ObsidianCardTonalLevel.bright:
        backgroundColor = ext.surfaceBright;
        break;
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.04),
                  blurRadius: 32,
                  spreadRadius: 4,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Stack(
            children: [
              if (showTopBorder)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 1.5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary.withValues(alpha: 0.15),
                          theme.colorScheme.primary.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(borderRadius),
                      ),
                    ),
                  ),
                ),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    );
  }
}
