import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class VaultSpendThemeExtension extends ThemeExtension<VaultSpendThemeExtension> {
  final Color primaryDark;
  final Color surfaceContainerHighest;
  final Color surfaceContainerHigh;
  final Color surfaceContainerLow;
  final Color surfaceBright;
  final double glassBlur;

  const VaultSpendThemeExtension({
    required this.primaryDark,
    required this.surfaceContainerHighest,
    required this.surfaceContainerHigh,
    required this.surfaceContainerLow,
    required this.surfaceBright,
    this.glassBlur = 20.0,
  });

  @override
  ThemeExtension<VaultSpendThemeExtension> copyWith({
    Color? primaryDark,
    Color? surfaceContainerHighest,
    Color? surfaceContainerHigh,
    Color? surfaceContainerLow,
    Color? surfaceBright,
    double? glassBlur,
  }) {
    return VaultSpendThemeExtension(
      primaryDark: primaryDark ?? this.primaryDark,
      surfaceContainerHighest:
          surfaceContainerHighest ?? this.surfaceContainerHighest,
      surfaceContainerHigh: surfaceContainerHigh ?? this.surfaceContainerHigh,
      surfaceContainerLow: surfaceContainerLow ?? this.surfaceContainerLow,
      surfaceBright: surfaceBright ?? this.surfaceBright,
      glassBlur: glassBlur ?? this.glassBlur,
    );
  }

  @override
  ThemeExtension<VaultSpendThemeExtension> lerp(
    covariant ThemeExtension<VaultSpendThemeExtension>? other,
    double t,
  ) {
    if (other is! VaultSpendThemeExtension) return this;
    return VaultSpendThemeExtension(
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      surfaceContainerHighest: Color.lerp(
          surfaceContainerHighest, other.surfaceContainerHighest, t)!,
      surfaceContainerHigh:
          Color.lerp(surfaceContainerHigh, other.surfaceContainerHigh, t)!,
      surfaceContainerLow:
          Color.lerp(surfaceContainerLow, other.surfaceContainerLow, t)!,
      surfaceBright: Color.lerp(surfaceBright, other.surfaceBright, t)!,
      glassBlur: ui.lerpDouble(glassBlur, other.glassBlur, t)!,
    );
  }
}

// Helper to access theme extension
extension VaultSpendThemeExtensionX on ThemeData {
  VaultSpendThemeExtension get vaultSpend => extension<VaultSpendThemeExtension>()!;
}

ThemeData buildVaultSpendTheme({required Brightness brightness}) {
  // "The Digital Obsidian" Palette from DESIGN.md
  final colorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: const Color(0xFF6BD8CB), // Liquid capital teal
    onPrimary: const Color(0xFF003732),
    primaryContainer: const Color(0xFF29A195),
    onPrimaryContainer: const Color(0xFF00302b),
    secondary: const Color(0xFFCEBDFF), // Lavender accents
    onSecondary: const Color(0xFF381385),
    secondaryContainer: const Color(0xFF4F319C),
    onSecondaryContainer: const Color(0xFFbea8ff),
    tertiary: const Color(0xFFFFB2B9), // Decline/Pink
    onTertiary: const Color(0xFF67001f),
    error: const Color(0xFFFFB4AB),
    onError: const Color(0xFF690005),
    errorContainer: const Color(0xFF93000a),
    onErrorContainer: const Color(0xFFffdad6),
    surface: const Color(0xFF131317), // Base foundation
    onSurface: const Color(0xFFE4E1E7),
    onSurfaceVariant: const Color(0xFFBCC9C6),
    outline: const Color(0xFF879391),
    outlineVariant: const Color(0xFF3D4947).withOpacity(0.15), // Ghost Border Rule
  );

  final baseTextTheme = ThemeData(brightness: Brightness.dark).textTheme;

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    extensions: [
      VaultSpendThemeExtension(
        primaryDark: const Color(0xFF006a61),
        surfaceContainerHighest: const Color(0xFF353439),
        surfaceContainerHigh: const Color(0xFF2A292E), // Interactive Layer
        surfaceContainerLow: const Color(0xFF1B1B1F),  // Sectional Layer
        surfaceBright: const Color(0xFF39393D),        // Floating Layer
        glassBlur: 20.0,
      ),
    ],
    textTheme: GoogleFonts.interTextTheme(baseTextTheme).copyWith(
      // Manrope for Display, Headlines, and authoritative tech-wealth feel
      displayLarge: GoogleFonts.manrope(textStyle: baseTextTheme.displayLarge),
      displayMedium: GoogleFonts.manrope(textStyle: baseTextTheme.displayMedium),
      displaySmall: GoogleFonts.manrope(textStyle: baseTextTheme.displaySmall),
      headlineLarge: GoogleFonts.manrope(textStyle: baseTextTheme.headlineLarge),
      headlineMedium: GoogleFonts.manrope(textStyle: baseTextTheme.headlineMedium),
      headlineSmall: GoogleFonts.manrope(textStyle: baseTextTheme.headlineSmall),
      titleLarge: GoogleFonts.manrope(textStyle: baseTextTheme.titleLarge),
      titleMedium: GoogleFonts.manrope(textStyle: baseTextTheme.titleMedium),
      titleSmall: GoogleFonts.manrope(textStyle: baseTextTheme.titleSmall),
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: colorScheme.primaryContainer.withOpacity(0.2),
      backgroundColor: colorScheme.surface,
    ),
  );
}
