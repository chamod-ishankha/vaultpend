import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/obsidian_button.dart';
import '../../core/widgets/obsidian_text_field.dart';
import 'auth_providers.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _password2 = TextEditingController();
  String _currency = 'USD';
  String? _localError;
  bool _submitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  static const _currencies = ['USD', 'LKR', 'EUR'];
  static const _currencyLabels = {
    'USD': 'USD - United States Dollar',
    'LKR': 'LKR - Sri Lankan Rupee',
    'EUR': 'EUR - Euro',
  };

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _password2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _localError = null;
      _submitting = true;
    });
    final email = _email.text.trim();
    final p1 = _password.text;
    final p2 = _password2.text;
    if (email.isEmpty || p1.isEmpty) {
      setState(() {
        _localError = 'Enter email and password';
        _submitting = false;
      });
      return;
    }
    if (p1.length < 8) {
      setState(() {
        _localError = 'Password must be at least 8 characters';
        _submitting = false;
      });
      return;
    }
    if (p1 != p2) {
      setState(() {
        _localError = 'Passwords do not match';
        _submitting = false;
      });
      return;
    }
    await ref
        .read(authControllerProvider.notifier)
        .signUp(email: email, password: p1, preferredCurrency: _currency);
    final state = ref.read(authControllerProvider);
    if (!mounted) return;
    if (state.hasError) {
      final e = state.error;
      setState(() {
        _localError = e.toString();
        _submitting = false;
      });
      return;
    }
    setState(() => _submitting = false);
    if (state.hasValue && state.value != null) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _submitting;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ext = theme.vaultSpend;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;

    final decorativeWidth = (screenWidth * 0.95) < ext.loginDecorativeWidth
        ? (screenWidth * 0.95)
        : ext.loginDecorativeWidth;
    final decorativeHeight = (screenHeight * 0.58) < ext.loginDecorativeWidth
        ? (screenHeight * 0.58)
        : ext.loginDecorativeWidth;

    final titleStyle = theme.textTheme.displaySmall?.copyWith(
      color: scheme.primary,
      fontWeight: FontWeight.w900,
      letterSpacing: -1.2,
    );
    final headingStyle = theme.textTheme.headlineMedium?.copyWith(
      color: scheme.onSurface,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    );
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
      height: 1.5,
    );
    final footnoteStyle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.outline.withValues(alpha: 0.6),
      height: 1.6,
    );

    final logoBottomSpacing = ext.loginFieldSpacing / 1.5;
    final helperSpacing = ext.registerHelperSpacing;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: Alignment.center,
            child: Container(
              width: ext.loginBackdropGlowSize,
              height: ext.loginBackdropGlowSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primary.withValues(alpha: 0.05),
              ),
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(
                    sigmaX: ext.loginBackdropGlowBlur,
                    sigmaY: ext.loginBackdropGlowBlur,
                  ),
                  child: const SizedBox.shrink(),
                ),
              ),
            ),
          ),

          Positioned(
            top: 0,
            right: 0,
            left: 0,
            child: IgnorePointer(
              child: Opacity(
                opacity: ext.loginDecorativeOpacity,
                child: SizedBox(
                  width: decorativeWidth,
                  height: decorativeHeight,
                  child: Image.asset(
                    'assets/branding/login_decorative.png',
                    fit: BoxFit.contain,
                    alignment: Alignment.topRight,
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: ext.loginPageHorizontalPadding,
                  vertical: ext.loginPageVerticalPadding,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: ext.loginMaxContentWidth,
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: ext.loginBrandBlockHeight,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: ext.loginLogoTileSize,
                              height: ext.loginLogoTileSize,
                              margin: EdgeInsets.only(
                                bottom: logoBottomSpacing,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  ext.loginCornerRadius,
                                ),
                                gradient: LinearGradient(
                                  colors: [
                                    scheme.primary,
                                    scheme.primaryContainer,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: scheme.primary.withValues(
                                      alpha: 0.15,
                                    ),
                                    blurRadius: ext.loginSectionSpacing,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.account_balance_wallet,
                                color: scheme.onPrimary,
                                size: ext.loginLogoIconSize,
                              ),
                            ),
                            Text('VaultSpend', style: titleStyle),
                          ],
                        ),
                      ),

                      SizedBox(height: ext.loginBrandToWelcomeGap),

                      Column(
                        children: [
                          Text('Create Account', style: headingStyle),
                          SizedBox(height: helperSpacing * 2),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: ext.loginHeaderSubtitleMaxWidth,
                            ),
                            child: Text(
                              'Create your account to enable Cloud sync.',
                              textAlign: TextAlign.center,
                              style: subtitleStyle,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: ext.loginSectionSpacing),

                      if (_localError != null)
                        Container(
                          width: double.infinity,
                          margin: EdgeInsets.only(
                            bottom: ext.loginFieldSpacing,
                          ),
                          padding: EdgeInsets.all(logoBottomSpacing),
                          decoration: BoxDecoration(
                            color: scheme.errorContainer.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(
                              ext.loginCornerRadius,
                            ),
                          ),
                          child: Text(
                            _localError!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onErrorContainer,
                            ),
                          ),
                        ),

                      IgnorePointer(
                        ignoring: busy,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ObsidianTextField(
                              label: 'EMAIL ADDRESS',
                              hintText: 'name@example.com',
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              prefixIcon: const Icon(Icons.mail_outline),
                            ),
                            SizedBox(height: ext.registerFieldSpacing),
                            ObsidianTextField(
                              label: 'PASSWORD',
                              hintText: '••••••••',
                              controller: _password,
                              obscureText: _obscurePassword,
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(
                                left: helperSpacing,
                                top: helperSpacing,
                              ),
                              child: Text(
                                'Must be at least 8 characters long.',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.outline.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                            SizedBox(height: ext.registerFieldSpacing),
                            ObsidianTextField(
                              label: 'CONFIRM PASSWORD',
                              hintText: '••••••••',
                              controller: _password2,
                              obscureText: _obscureConfirmPassword,
                              prefixIcon: const Icon(Icons.key_outlined),
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                  () => _obscureConfirmPassword =
                                      !_obscureConfirmPassword,
                                ),
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                            ),
                            SizedBox(height: ext.registerFieldSpacing),
                            _RegisterCurrencyField(
                              value: _currency,
                              items: _currencies,
                              labels: _currencyLabels,
                              enabled: !busy,
                              cornerRadius: ext.loginCornerRadius,
                              labelSpacing: helperSpacing,
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _currency = value);
                              },
                            ),
                            SizedBox(height: ext.registerPrimaryTopPadding),
                            ObsidianButton(
                              text: 'Create account',
                              onPressed: busy ? null : _submit,
                              isLoading: busy,
                              height: ext.loginPrimaryButtonHeight,
                              borderRadius: ext.loginCornerRadius,
                              gradientColors: [scheme.primary, ext.primaryDark],
                              shadowColor: ext.primaryDark.withValues(
                                alpha: 0.4,
                              ),
                              textColor: scheme.onPrimary,
                              enableShimmer: true,
                              shimmerDuration: const Duration(
                                milliseconds: 4000,
                              ),
                              shimmerPeakOpacity: 0.16,
                              shimmerBandFraction: 0.24,
                              shimmerAngle: 0.78,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: ext.loginFieldSpacing),

                      SizedBox(
                        width: double.infinity,
                        height: ext.loginPrimaryButtonHeight,
                        child: TextButton.icon(
                          onPressed: busy
                              ? null
                              : () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: scheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                ext.loginCornerRadius,
                              ),
                            ),
                          ),
                          icon: Icon(
                            Icons.arrow_back,
                            size: ext.loginLogoIconSize * 0.6,
                          ),
                          label: Text(
                            'Back to sign in',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: ext.loginPageVerticalPadding),

                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: ext.registerFootnoteMaxWidth,
                        ),
                        child: Text(
                          'By creating an account, you agree to our Terms of Service and Privacy Policy regarding cloud data synchronization and encryption protocols.',
                          textAlign: TextAlign.center,
                          style: footnoteStyle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegisterCurrencyField extends StatelessWidget {
  const _RegisterCurrencyField({
    required this.value,
    required this.items,
    required this.labels,
    required this.enabled,
    required this.cornerRadius,
    required this.labelSpacing,
    required this.onChanged,
  });

  final String value;
  final List<String> items;
  final Map<String, String> labels;
  final bool enabled;
  final double cornerRadius;
  final double labelSpacing;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ext = theme.vaultSpend;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: labelSpacing,
            bottom: labelSpacing * 2,
          ),
          child: Text(
            'PREFERRED CURRENCY',
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: ext.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(cornerRadius),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 16,
                child: Icon(
                  Icons.payments_outlined,
                  color: scheme.outline.withValues(alpha: 0.6),
                  size: 20,
                ),
              ),
              Positioned(
                right: 16,
                child: Icon(
                  Icons.expand_more,
                  color: scheme.outline.withValues(alpha: 0.6),
                  size: 20,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 46, right: 36),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    isExpanded: true,
                    icon: const SizedBox.shrink(),
                    borderRadius: BorderRadius.circular(cornerRadius),
                    dropdownColor: ext.surfaceContainerHigh,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                    items: items
                        .map(
                          (c) => DropdownMenuItem<String>(
                            value: c,
                            child: Text(labels[c] ?? c),
                          ),
                        )
                        .toList(),
                    onChanged: enabled ? onChanged : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
