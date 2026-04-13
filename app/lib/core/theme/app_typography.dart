import 'package:flutter/material.dart';

/// Semantic typography facade mapped to Material TextTheme.
/// This acts as the standard source of truth for text styles,
/// avoiding hardcoded GoogleFonts references inline.
class AppTypography {
  AppTypography._();

  static TextStyle? headline1(ThemeData theme) => theme.textTheme.displayLarge;
  static TextStyle? headline2(ThemeData theme) => theme.textTheme.displayMedium;
  static TextStyle? headline3(ThemeData theme) => theme.textTheme.displaySmall;

  static TextStyle? title1(ThemeData theme) => theme.textTheme.headlineMedium;
  static TextStyle? title2(ThemeData theme) => theme.textTheme.headlineSmall;

  static TextStyle? subtitle1(ThemeData theme) => theme.textTheme.titleLarge;
  static TextStyle? subtitle2(ThemeData theme) => theme.textTheme.titleMedium;
  static TextStyle? subtitle3(ThemeData theme) => theme.textTheme.titleSmall;

  static TextStyle? bodyLarge(ThemeData theme) => theme.textTheme.bodyLarge;
  static TextStyle? bodyMedium(ThemeData theme) => theme.textTheme.bodyMedium;
  static TextStyle? bodySmall(ThemeData theme) => theme.textTheme.bodySmall;

  static TextStyle? labelLarge(ThemeData theme) => theme.textTheme.labelLarge;
  static TextStyle? labelMedium(ThemeData theme) => theme.textTheme.labelMedium;
  static TextStyle? labelSmall(ThemeData theme) => theme.textTheme.labelSmall;
}
