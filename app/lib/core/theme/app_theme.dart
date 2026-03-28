import 'package:flutter/material.dart';

ThemeData buildVaultSpendTheme({required Brightness brightness}) {
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
  );
  final seed = brightness == Brightness.dark
      ? const Color(0xFF0D9488)
      : const Color(0xFF0F766E);
  return base.copyWith(
    colorScheme: ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      surface: brightness == Brightness.dark
          ? const Color(0xFF121218)
          : const Color(0xFFF8FAFC),
    ),
    scaffoldBackgroundColor: brightness == Brightness.dark
        ? const Color(0xFF0B0B0F)
        : const Color(0xFFF1F5F9),
    appBarTheme: const AppBarTheme(centerTitle: true, scrolledUnderElevation: 0),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: base.colorScheme.primaryContainer,
    ),
  );
}
