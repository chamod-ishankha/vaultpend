import 'package:flutter/material.dart';

/// Centralized dimensions and layout constants for the VaultSpend application.
class AppDimensions {
  AppDimensions._();

  // Screen Padding
  static const double screenPaddingHorizontal = 24.0;
  static const double screenPaddingVertical = 24.0;
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(
    horizontal: screenPaddingHorizontal,
    vertical: screenPaddingVertical,
  );

  // General Spacing
  static const double sp4 = 4.0;
  static const double sp8 = 8.0;
  static const double sp12 = 12.0;
  static const double sp16 = 16.0;
  static const double sp24 = 24.0;
  static const double sp32 = 32.0;
  static const double sp48 = 48.0;
  static const double sp64 = 64.0;

  // Component Sizes
  static const double standardButtonHeight = 56.0;
  static const double smallButtonHeight = 40.0;
  static const double iconSizeSmall = 16.0;
  static const double iconSizeMedium = 20.0;
  static const double iconSizeLarge = 24.0;
  static const double iconSizeXLarge = 32.0;

  // Layout Properties
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 24.0;
  static const double radiusCircular = 999.0;

  // Shell Layout Details
  static const double shellBottomNavBaseHeight = 80.0;
  static const double shellDesktopRailWidth = 72.0;
}
