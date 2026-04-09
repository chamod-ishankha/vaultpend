import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum ObsidianButtonStyle { primary, secondary, tertiary }

class ObsidianButton extends StatefulWidget {
  const ObsidianButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.style = ObsidianButtonStyle.primary,
    this.width,
    this.height = 56,
    this.borderRadius = 12.0,
    this.isLoading = false,
    this.gradientColors,
    this.shadowColor,
    this.borderColor,
    this.backgroundColor,
    this.textColor,
    this.enableShimmer = false,
    this.shimmerDuration = const Duration(milliseconds: 4000),
    this.shimmerPeakOpacity = 0.12,
    this.shimmerBandFraction = 0.30,
    this.shimmerAngle = 0.78,
  });

  final VoidCallback? onPressed;
  final String text;
  final ObsidianButtonStyle style;
  final double? width;
  final double height;
  final double borderRadius;
  final bool isLoading;
  final List<Color>? gradientColors;
  final Color? shadowColor;
  final Color? borderColor;
  final Color? backgroundColor;
  final Color? textColor;
  final bool enableShimmer;
  final Duration shimmerDuration;
  final double shimmerPeakOpacity;
  final double shimmerBandFraction;
  final double shimmerAngle;

  @override
  State<ObsidianButton> createState() => _ObsidianButtonState();
}

class _ObsidianButtonState extends State<ObsidianButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;
  late final Animation<double> _shimmerPosition;

  bool get _shouldAnimateShimmer {
    return widget.enableShimmer &&
        widget.style == ObsidianButtonStyle.primary &&
        widget.onPressed != null &&
        !widget.isLoading;
  }

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: widget.shimmerDuration,
    );
    _shimmerPosition = Tween<double>(begin: -1.0, end: 1.6).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.linear),
    );

    if (_shouldAnimateShimmer) {
      _shimmerController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant ObsidianButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shimmerDuration != widget.shimmerDuration) {
      _shimmerController.duration = widget.shimmerDuration;
    }

    if (_shouldAnimateShimmer) {
      if (!_shimmerController.isAnimating) {
        _shimmerController.repeat();
      }
    } else {
      _shimmerController.stop();
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ext = theme.vaultSpend;

    final resolvedTextColor =
        widget.textColor ??
        (widget.style == ObsidianButtonStyle.primary
            ? scheme.onPrimary
            : scheme.primary);

    Widget buttonChild = Center(
      child: widget.isLoading
          ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: widget.style == ObsidianButtonStyle.primary
                    ? resolvedTextColor
                    : (widget.textColor ?? scheme.primary),
              ),
            )
          : Text(
              widget.text,
              style: theme.textTheme.titleMedium?.copyWith(
                color: resolvedTextColor,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
    );

    if (widget.style == ObsidianButtonStyle.primary) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          gradient: LinearGradient(
            colors: widget.gradientColors ?? [scheme.primary, ext.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  widget.shadowColor ?? ext.primaryDark.withValues(alpha: 0.3),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.isLoading ? null : widget.onPressed,
                borderRadius: BorderRadius.circular(widget.borderRadius),
                child: buttonChild,
              ),
            ),
            if (widget.enableShimmer)
              IgnorePointer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return AnimatedBuilder(
                        animation: _shimmerPosition,
                        builder: (context, _) {
                          final shimmerWidth =
                              constraints.maxWidth * widget.shimmerBandFraction;
                          final sweepDistance =
                              constraints.maxWidth + shimmerWidth;
                          final left =
                              (_shimmerPosition.value * sweepDistance) -
                              shimmerWidth;

                          return Stack(
                            children: [
                              Positioned(
                                left: left,
                                top: -constraints.maxHeight * 0.6,
                                child: Transform.rotate(
                                  angle: widget.shimmerAngle,
                                  child: Container(
                                    width: shimmerWidth,
                                    height: constraints.maxHeight * 2.2,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.transparent,
                                          resolvedTextColor.withValues(
                                            alpha: widget.shimmerPeakOpacity,
                                          ),
                                          Colors.transparent,
                                        ],
                                        stops: const [0.35, 0.5, 0.65],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      );
    } else if (widget.style == ObsidianButtonStyle.secondary) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: widget.borderColor ?? scheme.primary.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.isLoading ? null : widget.onPressed,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: buttonChild,
          ),
        ),
      );
    } else {
      // Tertiary / Text only
      return TextButton(
        onPressed: widget.isLoading ? null : widget.onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        ),
        child: widget.isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.primary,
                ),
              )
            : Text(
                widget.text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
      );
    }
  }
}
