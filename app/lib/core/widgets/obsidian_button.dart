import 'package:flutter/material.dart';

enum ObsidianButtonStyle { primary, secondary, tertiary }

class ObsidianButton extends StatelessWidget {
  const ObsidianButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.style = ObsidianButtonStyle.primary,
    this.width,
    this.height = 56,
    this.borderRadius = 12.0,
    this.isLoading = false,
  });

  final VoidCallback? onPressed;
  final String text;
  final ObsidianButtonStyle style;
  final double? width;
  final double height;
  final double borderRadius;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget buttonChild = Center(
      child: isLoading
          ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: style == ObsidianButtonStyle.primary
                    ? scheme.onPrimary
                    : scheme.primary,
              ),
            )
          : Text(
              text,
              style: theme.textTheme.titleMedium?.copyWith(
                color: style == ObsidianButtonStyle.primary
                    ? scheme.onPrimary
                    : scheme.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
    );

    if (style == ObsidianButtonStyle.primary) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          gradient: LinearGradient(
            colors: [scheme.primary, scheme.primaryContainer],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withOpacity(0.3),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isLoading ? null : onPressed,
            borderRadius: BorderRadius.circular(borderRadius),
            child: buttonChild,
          ),
        ),
      );
    } else if (style == ObsidianButtonStyle.secondary) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: scheme.primary.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isLoading ? null : onPressed,
            borderRadius: BorderRadius.circular(borderRadius),
            child: buttonChild,
          ),
        ),
      );
    } else {
      // Tertiary / Text only
      return TextButton(
        onPressed: isLoading ? null : onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        child: isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.primary,
                ),
              )
            : Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
      );
    }
  }
}
