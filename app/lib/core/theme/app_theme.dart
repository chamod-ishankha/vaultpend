import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class VaultSpendThemeExtension extends ThemeExtension<VaultSpendThemeExtension> {
  final Color primaryDark;
  final Color surfaceContainerHighest;
  final Color surfaceContainerHigh;
  final Color surfaceContainerLow;

  const VaultSpendThemeExtension({
    required this.primaryDark,
    required this.surfaceContainerHighest,
    required this.surfaceContainerHigh,
    required this.surfaceContainerLow,
  });

  @override
  ThemeExtension<VaultSpendThemeExtension> copyWith({
    Color? primaryDark,
    Color? surfaceContainerHighest,
    Color? surfaceContainerHigh,
    Color? surfaceContainerLow,
  }) {
    return VaultSpendThemeExtension(
      primaryDark: primaryDark ?? this.primaryDark,
      surfaceContainerHighest:
          surfaceContainerHighest ?? this.surfaceContainerHighest,
      surfaceContainerHigh: surfaceContainerHigh ?? this.surfaceContainerHigh,
      surfaceContainerLow: surfaceContainerLow ?? this.surfaceContainerLow,
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
    );
  }
}

ThemeData buildVaultSpendTheme({required Brightness brightness}) {
  // "The Digital Obsidian" Palette
  const colorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF6bd8cb),
    onPrimary: Color(0xFF003732),
    primaryContainer: Color(0xFF29a195),
    onPrimaryContainer: Color(0xFF00302b),
    secondary: Color(0xFFcebdff),
    onSecondary: Color(0xFF381385),
    secondaryContainer: Color(0xFF4f319c),
    onSecondaryContainer: Color(0xFFbea8ff),
    tertiary: Color(0xFFffb2b9),
    onTertiary: Color(0xFF67001f),
    error: Color(0xFFffb4ab),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000a),
    onErrorContainer: Color(0xFFffdad6),
    surface: Color(0xFF131317),
    onSurface: Color(0xFFe4e1e7),
    onSurfaceVariant: Color(0xFFbcc9c6),
    outline: Color(0xFF879391),
    outlineVariant: Color(0xFF3d4947),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    extensions: const [
      VaultSpendThemeExtension(
        primaryDark: Color(0xFF006a61),
        surfaceContainerHighest: Color(0xFF353439),
        surfaceContainerHigh: Color(0xFF2a292e),
        surfaceContainerLow: Color(0xFF1b1b1f),
      ),
    ],
    textTheme: GoogleFonts.interTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    ).copyWith(
      displayLarge: GoogleFonts.manrope(),
      displayMedium: GoogleFonts.manrope(),
      displaySmall: GoogleFonts.manrope(),
      headlineLarge: GoogleFonts.manrope(),
      headlineMedium: GoogleFonts.manrope(),
      headlineSmall: GoogleFonts.manrope(),
      titleLarge: GoogleFonts.manrope(),
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      scrolledUnderElevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: colorScheme.primaryContainer,
    ),
  );
}
