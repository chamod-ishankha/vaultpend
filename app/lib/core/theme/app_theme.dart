import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class VaultSpendThemeExtension
    extends ThemeExtension<VaultSpendThemeExtension> {
  final Color primaryDark;
  final Color surfaceContainerHighest;
  final Color surfaceContainerHigh;
  final Color surfaceContainerLow;
  final Color surfaceBright;
  final double glassBlur;
  final double loginMaxContentWidth;
  final double loginDecorativeWidth;
  final double loginDecorativeOpacity;
  final double loginPageHorizontalPadding;
  final double loginPageVerticalPadding;
  final double loginBackdropGlowSize;
  final double loginBackdropGlowBlur;
  final double loginBrandBlockHeight;
  final double loginLogoTileSize;
  final double loginLogoIconSize;
  final double loginBrandToWelcomeGap;
  final double loginHeaderSubtitleMaxWidth;
  final double loginFieldSpacing;
  final double loginSectionSpacing;
  final double loginDividerHorizontalPadding;
  final double loginFootnoteMaxWidth;
  final double loginPrimaryButtonHeight;
  final double loginCornerRadius;
  final double registerFieldSpacing;
  final double registerHelperSpacing;
  final double registerPrimaryTopPadding;
  final double registerFootnoteMaxWidth;
  final double addExpenseContentHorizontalPadding;
  final double addExpenseAmountHeroVerticalPadding;
  final double addExpenseSectionSpacing;
  final double addExpenseSectionHeaderSpacing;
  final double addExpenseCardRadius;
  final double addExpenseFormRowIconTileSize;
  final double addExpenseFormRowIconSize;
  final double addExpenseBottomActionSpacing;
  final double addExpenseAmountFontSize;
  final double addExpenseCurrencyChipRadius;
  final double addExpenseAmountFieldWidth;
  final double addExpenseCardGap;
  final double addExpenseSplitCardGap;
  final double addExpenseReceiptTileHeight;
  final double addExpenseModalCornerRadius;
  final double addExpenseModalOptionRadius;

  const VaultSpendThemeExtension({
    required this.primaryDark,
    required this.surfaceContainerHighest,
    required this.surfaceContainerHigh,
    required this.surfaceContainerLow,
    required this.surfaceBright,
    this.glassBlur = 20.0,
    this.loginMaxContentWidth = 420.0,
    this.loginDecorativeWidth = 400.0,
    this.loginDecorativeOpacity = 0.2,
    this.loginPageHorizontalPadding = 24.0,
    this.loginPageVerticalPadding = 48.0,
    this.loginBackdropGlowSize = 600.0,
    this.loginBackdropGlowBlur = 120.0,
    this.loginBrandBlockHeight = 150.0,
    this.loginLogoTileSize = 64.0,
    this.loginLogoIconSize = 32.0,
    this.loginBrandToWelcomeGap = 32.0,
    this.loginHeaderSubtitleMaxWidth = 280.0,
    this.loginFieldSpacing = 24.0,
    this.loginSectionSpacing = 40.0,
    this.loginDividerHorizontalPadding = 16.0,
    this.loginFootnoteMaxWidth = 300.0,
    this.loginPrimaryButtonHeight = 56.0,
    this.loginCornerRadius = 12.0,
    this.registerFieldSpacing = 24.0,
    this.registerHelperSpacing = 4.0,
    this.registerPrimaryTopPadding = 24.0,
    this.registerFootnoteMaxWidth = 340.0,
    this.addExpenseContentHorizontalPadding = 16.0,
    this.addExpenseAmountHeroVerticalPadding = 36.0,
    this.addExpenseSectionSpacing = 24.0,
    this.addExpenseSectionHeaderSpacing = 12.0,
    this.addExpenseCardRadius = 16.0,
    this.addExpenseFormRowIconTileSize = 36.0,
    this.addExpenseFormRowIconSize = 20.0,
    this.addExpenseBottomActionSpacing = 96.0,
    this.addExpenseAmountFontSize = 56.0,
    this.addExpenseCurrencyChipRadius = 8.0,
    this.addExpenseAmountFieldWidth = 280.0,
    this.addExpenseCardGap = 14.0,
    this.addExpenseSplitCardGap = 12.0,
    this.addExpenseReceiptTileHeight = 128.0,
    this.addExpenseModalCornerRadius = 24.0,
    this.addExpenseModalOptionRadius = 14.0,
  });

  @override
  ThemeExtension<VaultSpendThemeExtension> copyWith({
    Color? primaryDark,
    Color? surfaceContainerHighest,
    Color? surfaceContainerHigh,
    Color? surfaceContainerLow,
    Color? surfaceBright,
    double? glassBlur,
    double? loginMaxContentWidth,
    double? loginDecorativeWidth,
    double? loginDecorativeOpacity,
    double? loginPageHorizontalPadding,
    double? loginPageVerticalPadding,
    double? loginBackdropGlowSize,
    double? loginBackdropGlowBlur,
    double? loginBrandBlockHeight,
    double? loginLogoTileSize,
    double? loginLogoIconSize,
    double? loginBrandToWelcomeGap,
    double? loginHeaderSubtitleMaxWidth,
    double? loginFieldSpacing,
    double? loginSectionSpacing,
    double? loginDividerHorizontalPadding,
    double? loginFootnoteMaxWidth,
    double? loginPrimaryButtonHeight,
    double? loginCornerRadius,
    double? registerFieldSpacing,
    double? registerHelperSpacing,
    double? registerPrimaryTopPadding,
    double? registerFootnoteMaxWidth,
    double? addExpenseContentHorizontalPadding,
    double? addExpenseAmountHeroVerticalPadding,
    double? addExpenseSectionSpacing,
    double? addExpenseSectionHeaderSpacing,
    double? addExpenseCardRadius,
    double? addExpenseFormRowIconTileSize,
    double? addExpenseFormRowIconSize,
    double? addExpenseBottomActionSpacing,
    double? addExpenseAmountFontSize,
    double? addExpenseCurrencyChipRadius,
    double? addExpenseAmountFieldWidth,
    double? addExpenseCardGap,
    double? addExpenseSplitCardGap,
    double? addExpenseReceiptTileHeight,
    double? addExpenseModalCornerRadius,
    double? addExpenseModalOptionRadius,
  }) {
    return VaultSpendThemeExtension(
      primaryDark: primaryDark ?? this.primaryDark,
      surfaceContainerHighest:
          surfaceContainerHighest ?? this.surfaceContainerHighest,
      surfaceContainerHigh: surfaceContainerHigh ?? this.surfaceContainerHigh,
      surfaceContainerLow: surfaceContainerLow ?? this.surfaceContainerLow,
      surfaceBright: surfaceBright ?? this.surfaceBright,
      glassBlur: glassBlur ?? this.glassBlur,
      loginMaxContentWidth: loginMaxContentWidth ?? this.loginMaxContentWidth,
      loginDecorativeWidth: loginDecorativeWidth ?? this.loginDecorativeWidth,
      loginDecorativeOpacity:
          loginDecorativeOpacity ?? this.loginDecorativeOpacity,
      loginPageHorizontalPadding:
          loginPageHorizontalPadding ?? this.loginPageHorizontalPadding,
      loginPageVerticalPadding:
          loginPageVerticalPadding ?? this.loginPageVerticalPadding,
      loginBackdropGlowSize:
          loginBackdropGlowSize ?? this.loginBackdropGlowSize,
      loginBackdropGlowBlur:
          loginBackdropGlowBlur ?? this.loginBackdropGlowBlur,
      loginBrandBlockHeight:
          loginBrandBlockHeight ?? this.loginBrandBlockHeight,
      loginLogoTileSize: loginLogoTileSize ?? this.loginLogoTileSize,
      loginLogoIconSize: loginLogoIconSize ?? this.loginLogoIconSize,
      loginBrandToWelcomeGap:
          loginBrandToWelcomeGap ?? this.loginBrandToWelcomeGap,
      loginHeaderSubtitleMaxWidth:
          loginHeaderSubtitleMaxWidth ?? this.loginHeaderSubtitleMaxWidth,
      loginFieldSpacing: loginFieldSpacing ?? this.loginFieldSpacing,
      loginSectionSpacing: loginSectionSpacing ?? this.loginSectionSpacing,
      loginDividerHorizontalPadding:
          loginDividerHorizontalPadding ?? this.loginDividerHorizontalPadding,
      loginFootnoteMaxWidth:
          loginFootnoteMaxWidth ?? this.loginFootnoteMaxWidth,
      loginPrimaryButtonHeight:
          loginPrimaryButtonHeight ?? this.loginPrimaryButtonHeight,
      loginCornerRadius: loginCornerRadius ?? this.loginCornerRadius,
      registerFieldSpacing: registerFieldSpacing ?? this.registerFieldSpacing,
      registerHelperSpacing:
          registerHelperSpacing ?? this.registerHelperSpacing,
      registerPrimaryTopPadding:
          registerPrimaryTopPadding ?? this.registerPrimaryTopPadding,
      registerFootnoteMaxWidth:
          registerFootnoteMaxWidth ?? this.registerFootnoteMaxWidth,
      addExpenseContentHorizontalPadding:
          addExpenseContentHorizontalPadding ??
          this.addExpenseContentHorizontalPadding,
      addExpenseAmountHeroVerticalPadding:
          addExpenseAmountHeroVerticalPadding ??
          this.addExpenseAmountHeroVerticalPadding,
      addExpenseSectionSpacing:
          addExpenseSectionSpacing ?? this.addExpenseSectionSpacing,
      addExpenseSectionHeaderSpacing:
          addExpenseSectionHeaderSpacing ?? this.addExpenseSectionHeaderSpacing,
      addExpenseCardRadius: addExpenseCardRadius ?? this.addExpenseCardRadius,
      addExpenseFormRowIconTileSize:
          addExpenseFormRowIconTileSize ?? this.addExpenseFormRowIconTileSize,
      addExpenseFormRowIconSize:
          addExpenseFormRowIconSize ?? this.addExpenseFormRowIconSize,
      addExpenseBottomActionSpacing:
          addExpenseBottomActionSpacing ?? this.addExpenseBottomActionSpacing,
      addExpenseAmountFontSize:
          addExpenseAmountFontSize ?? this.addExpenseAmountFontSize,
      addExpenseCurrencyChipRadius:
          addExpenseCurrencyChipRadius ?? this.addExpenseCurrencyChipRadius,
      addExpenseAmountFieldWidth:
          addExpenseAmountFieldWidth ?? this.addExpenseAmountFieldWidth,
      addExpenseCardGap: addExpenseCardGap ?? this.addExpenseCardGap,
      addExpenseSplitCardGap:
          addExpenseSplitCardGap ?? this.addExpenseSplitCardGap,
      addExpenseReceiptTileHeight:
          addExpenseReceiptTileHeight ?? this.addExpenseReceiptTileHeight,
      addExpenseModalCornerRadius:
          addExpenseModalCornerRadius ?? this.addExpenseModalCornerRadius,
      addExpenseModalOptionRadius:
          addExpenseModalOptionRadius ?? this.addExpenseModalOptionRadius,
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
        surfaceContainerHighest,
        other.surfaceContainerHighest,
        t,
      )!,
      surfaceContainerHigh: Color.lerp(
        surfaceContainerHigh,
        other.surfaceContainerHigh,
        t,
      )!,
      surfaceContainerLow: Color.lerp(
        surfaceContainerLow,
        other.surfaceContainerLow,
        t,
      )!,
      surfaceBright: Color.lerp(surfaceBright, other.surfaceBright, t)!,
      glassBlur: ui.lerpDouble(glassBlur, other.glassBlur, t)!,
      loginMaxContentWidth: ui.lerpDouble(
        loginMaxContentWidth,
        other.loginMaxContentWidth,
        t,
      )!,
      loginDecorativeWidth: ui.lerpDouble(
        loginDecorativeWidth,
        other.loginDecorativeWidth,
        t,
      )!,
      loginDecorativeOpacity: ui.lerpDouble(
        loginDecorativeOpacity,
        other.loginDecorativeOpacity,
        t,
      )!,
      loginPageHorizontalPadding: ui.lerpDouble(
        loginPageHorizontalPadding,
        other.loginPageHorizontalPadding,
        t,
      )!,
      loginPageVerticalPadding: ui.lerpDouble(
        loginPageVerticalPadding,
        other.loginPageVerticalPadding,
        t,
      )!,
      loginBackdropGlowSize: ui.lerpDouble(
        loginBackdropGlowSize,
        other.loginBackdropGlowSize,
        t,
      )!,
      loginBackdropGlowBlur: ui.lerpDouble(
        loginBackdropGlowBlur,
        other.loginBackdropGlowBlur,
        t,
      )!,
      loginBrandBlockHeight: ui.lerpDouble(
        loginBrandBlockHeight,
        other.loginBrandBlockHeight,
        t,
      )!,
      loginLogoTileSize: ui.lerpDouble(
        loginLogoTileSize,
        other.loginLogoTileSize,
        t,
      )!,
      loginLogoIconSize: ui.lerpDouble(
        loginLogoIconSize,
        other.loginLogoIconSize,
        t,
      )!,
      loginBrandToWelcomeGap: ui.lerpDouble(
        loginBrandToWelcomeGap,
        other.loginBrandToWelcomeGap,
        t,
      )!,
      loginHeaderSubtitleMaxWidth: ui.lerpDouble(
        loginHeaderSubtitleMaxWidth,
        other.loginHeaderSubtitleMaxWidth,
        t,
      )!,
      loginFieldSpacing: ui.lerpDouble(
        loginFieldSpacing,
        other.loginFieldSpacing,
        t,
      )!,
      loginSectionSpacing: ui.lerpDouble(
        loginSectionSpacing,
        other.loginSectionSpacing,
        t,
      )!,
      loginDividerHorizontalPadding: ui.lerpDouble(
        loginDividerHorizontalPadding,
        other.loginDividerHorizontalPadding,
        t,
      )!,
      loginFootnoteMaxWidth: ui.lerpDouble(
        loginFootnoteMaxWidth,
        other.loginFootnoteMaxWidth,
        t,
      )!,
      loginPrimaryButtonHeight: ui.lerpDouble(
        loginPrimaryButtonHeight,
        other.loginPrimaryButtonHeight,
        t,
      )!,
      loginCornerRadius: ui.lerpDouble(
        loginCornerRadius,
        other.loginCornerRadius,
        t,
      )!,
      registerFieldSpacing: ui.lerpDouble(
        registerFieldSpacing,
        other.registerFieldSpacing,
        t,
      )!,
      registerHelperSpacing: ui.lerpDouble(
        registerHelperSpacing,
        other.registerHelperSpacing,
        t,
      )!,
      registerPrimaryTopPadding: ui.lerpDouble(
        registerPrimaryTopPadding,
        other.registerPrimaryTopPadding,
        t,
      )!,
      registerFootnoteMaxWidth: ui.lerpDouble(
        registerFootnoteMaxWidth,
        other.registerFootnoteMaxWidth,
        t,
      )!,
      addExpenseContentHorizontalPadding: ui.lerpDouble(
        addExpenseContentHorizontalPadding,
        other.addExpenseContentHorizontalPadding,
        t,
      )!,
      addExpenseAmountHeroVerticalPadding: ui.lerpDouble(
        addExpenseAmountHeroVerticalPadding,
        other.addExpenseAmountHeroVerticalPadding,
        t,
      )!,
      addExpenseSectionSpacing: ui.lerpDouble(
        addExpenseSectionSpacing,
        other.addExpenseSectionSpacing,
        t,
      )!,
      addExpenseSectionHeaderSpacing: ui.lerpDouble(
        addExpenseSectionHeaderSpacing,
        other.addExpenseSectionHeaderSpacing,
        t,
      )!,
      addExpenseCardRadius: ui.lerpDouble(
        addExpenseCardRadius,
        other.addExpenseCardRadius,
        t,
      )!,
      addExpenseFormRowIconTileSize: ui.lerpDouble(
        addExpenseFormRowIconTileSize,
        other.addExpenseFormRowIconTileSize,
        t,
      )!,
      addExpenseFormRowIconSize: ui.lerpDouble(
        addExpenseFormRowIconSize,
        other.addExpenseFormRowIconSize,
        t,
      )!,
      addExpenseBottomActionSpacing: ui.lerpDouble(
        addExpenseBottomActionSpacing,
        other.addExpenseBottomActionSpacing,
        t,
      )!,
      addExpenseAmountFontSize: ui.lerpDouble(
        addExpenseAmountFontSize,
        other.addExpenseAmountFontSize,
        t,
      )!,
      addExpenseCurrencyChipRadius: ui.lerpDouble(
        addExpenseCurrencyChipRadius,
        other.addExpenseCurrencyChipRadius,
        t,
      )!,
      addExpenseAmountFieldWidth: ui.lerpDouble(
        addExpenseAmountFieldWidth,
        other.addExpenseAmountFieldWidth,
        t,
      )!,
      addExpenseCardGap: ui.lerpDouble(
        addExpenseCardGap,
        other.addExpenseCardGap,
        t,
      )!,
      addExpenseSplitCardGap: ui.lerpDouble(
        addExpenseSplitCardGap,
        other.addExpenseSplitCardGap,
        t,
      )!,
      addExpenseReceiptTileHeight: ui.lerpDouble(
        addExpenseReceiptTileHeight,
        other.addExpenseReceiptTileHeight,
        t,
      )!,
      addExpenseModalCornerRadius: ui.lerpDouble(
        addExpenseModalCornerRadius,
        other.addExpenseModalCornerRadius,
        t,
      )!,
      addExpenseModalOptionRadius: ui.lerpDouble(
        addExpenseModalOptionRadius,
        other.addExpenseModalOptionRadius,
        t,
      )!,
    );
  }
}

// Helper to access theme extension
extension VaultSpendThemeExtensionX on ThemeData {
  VaultSpendThemeExtension get vaultSpend =>
      extension<VaultSpendThemeExtension>()!;
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
    outlineVariant: const Color(
      0xFF3D4947,
    ).withValues(alpha: 0.15), // Ghost Border Rule
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
        surfaceContainerLow: const Color(0xFF1B1B1F), // Sectional Layer
        surfaceBright: const Color(0xFF39393D), // Floating Layer
        glassBlur: 20.0,
        loginMaxContentWidth: 420,
        loginDecorativeWidth: 400,
        loginDecorativeOpacity: 0.20,
        loginPageHorizontalPadding: 24,
        loginPageVerticalPadding: 48,
        loginBackdropGlowSize: 600,
        loginBackdropGlowBlur: 120,
        loginBrandBlockHeight: 150,
        loginLogoTileSize: 64,
        loginLogoIconSize: 32,
        loginBrandToWelcomeGap: 32,
        loginHeaderSubtitleMaxWidth: 280,
        loginFieldSpacing: 24,
        loginSectionSpacing: 40,
        loginDividerHorizontalPadding: 16,
        loginFootnoteMaxWidth: 300,
        loginPrimaryButtonHeight: 56,
        loginCornerRadius: 12,
        registerFieldSpacing: 24,
        registerHelperSpacing: 4,
        registerPrimaryTopPadding: 24.0,
        registerFootnoteMaxWidth: 340,
        addExpenseContentHorizontalPadding: 24,
        addExpenseAmountHeroVerticalPadding: 36,
        addExpenseSectionSpacing: 24,
        addExpenseSectionHeaderSpacing: 12,
        addExpenseCardRadius: 16,
        addExpenseFormRowIconTileSize: 36,
        addExpenseFormRowIconSize: 20,
        addExpenseBottomActionSpacing: 96,
        addExpenseAmountFontSize: 56,
        addExpenseCurrencyChipRadius: 999,
        addExpenseAmountFieldWidth: 280,
        addExpenseCardGap: 14,
        addExpenseSplitCardGap: 12,
        addExpenseReceiptTileHeight: 128,
        addExpenseModalCornerRadius: 24,
        addExpenseModalOptionRadius: 14,
      ),
    ],
    textTheme: GoogleFonts.interTextTheme(baseTextTheme).copyWith(
      // Manrope for Display, Headlines, and authoritative tech-wealth feel
      displayLarge: GoogleFonts.manrope(textStyle: baseTextTheme.displayLarge),
      displayMedium: GoogleFonts.manrope(
        textStyle: baseTextTheme.displayMedium,
      ),
      displaySmall: GoogleFonts.manrope(textStyle: baseTextTheme.displaySmall),
      headlineLarge: GoogleFonts.manrope(
        textStyle: baseTextTheme.headlineLarge,
      ),
      headlineMedium: GoogleFonts.manrope(
        textStyle: baseTextTheme.headlineMedium,
      ),
      headlineSmall: GoogleFonts.manrope(
        textStyle: baseTextTheme.headlineSmall,
      ),
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
      indicatorColor: colorScheme.primaryContainer.withValues(alpha: 0.2),
      backgroundColor: colorScheme.surface,
    ),
  );
}
