import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/obsidian_button.dart';
import '../../core/widgets/obsidian_text_field.dart';

import 'package:vaultspend/core/firebase/firebase_bootstrap.dart';

import 'auth_providers.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.initialError});

  final String? initialError;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _localError;
  String? _statusMessage;
  bool _submitting = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _localError = widget.initialError;
    _statusMessage = isFirebaseReady
        ? 'Cloud sync is available when you sign in.'
        : 'Cloud sync is not configured yet. Guest mode is still available.';
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _localError = null;
      _statusMessage = null;
      _submitting = true;
    });
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _localError = 'Enter email and password';
        _submitting = false;
      });
      return;
    }
    await ref.read(authControllerProvider.notifier).signIn(email, password);
    if (!mounted) return;
    final next = ref.read(authControllerProvider);
    next.whenOrNull(
      error: (e, _) {
        setState(() {
          _localError = e.toString();
        });
      },
    );
    setState(() => _submitting = false);
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
    final welcomeStyle = theme.textTheme.headlineMedium?.copyWith(
      color: scheme.onSurface,
      fontWeight: FontWeight.w800,
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

    final compactSpacing = ext.loginFieldSpacing / 2;
    final microSpacing = ext.loginFieldSpacing / 3;
    final mediumSpacing = ext.loginFieldSpacing / 1.5;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: Alignment.center,
            child: IgnorePointer(
              child: Container(
                width: ext.loginBackdropGlowSize,
                height: ext.loginBackdropGlowSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      scheme.primary.withValues(alpha: 0.12),
                      scheme.primary.withValues(alpha: 0.0),
                    ],
                  ),
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
                    alignment: Alignment.topCenter,
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
                              margin: EdgeInsets.only(bottom: compactSpacing),
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
                          Text(
                            'Welcome Back',
                            textAlign: TextAlign.center,
                            style: welcomeStyle,
                          ),
                          SizedBox(height: microSpacing),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: ext.loginHeaderSubtitleMaxWidth,
                            ),
                            child: Text(
                              'Sign in to sync your data with Cloud.',
                              textAlign: TextAlign.center,
                              style: subtitleStyle,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: ext.loginSectionSpacing),

                      if (_localError != null)
                        _LoginMessageCard(
                          message: _localError!,
                          backgroundColor: scheme.errorContainer.withValues(
                            alpha: 0.2,
                          ),
                          textColor: scheme.onErrorContainer,
                          cornerRadius: ext.loginCornerRadius,
                          spacing: mediumSpacing,
                          textStyle: theme.textTheme.bodySmall,
                        ),

                      if (_statusMessage != null)
                        _LoginMessageCard(
                          message: _statusMessage!,
                          backgroundColor: scheme.secondaryContainer.withValues(
                            alpha: 0.2,
                          ),
                          textColor: scheme.onSecondaryContainer,
                          cornerRadius: ext.loginCornerRadius,
                          spacing: mediumSpacing,
                          textStyle: theme.textTheme.bodySmall,
                        ),

                      IgnorePointer(
                        ignoring: busy,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ObsidianTextField(
                              label: 'EMAIL',
                              hintText: 'name@company.com',
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              prefixIcon: const Icon(Icons.mail_outline),
                            ),
                            SizedBox(height: ext.loginFieldSpacing),
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
                            SizedBox(height: mediumSpacing),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: busy ? null : () {},
                                style: TextButton.styleFrom(
                                  foregroundColor: scheme.primary,
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Forgot password?',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: ext.loginFieldSpacing),
                            SizedBox(
                              height: ext.loginPrimaryButtonHeight,
                              child: ObsidianButton(
                                text: 'Sign in',
                                onPressed: busy ? null : _submit,
                                isLoading: busy,
                                height: ext.loginPrimaryButtonHeight,
                                borderRadius: ext.loginCornerRadius,
                                gradientColors: [
                                  scheme.primary,
                                  ext.primaryDark,
                                ],
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
                            ),
                            SizedBox(height: ext.loginSectionSpacing),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: ext.loginDividerHorizontalPadding,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                      color: scheme.outlineVariant.withValues(
                                        alpha: 0.15,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: compactSpacing,
                                    ),
                                    child: Text(
                                      'or',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: scheme.outline.withValues(
                                              alpha: 0.6,
                                            ),
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1,
                                          ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      color: scheme.outlineVariant.withValues(
                                        alpha: 0.15,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: ext.loginFieldSpacing),
                            SizedBox(
                              height: ext.loginPrimaryButtonHeight,
                              child: ObsidianButton(
                                text: 'Create account',
                                onPressed: busy
                                    ? null
                                    : () {
                                        Navigator.of(context).push<void>(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const RegisterScreen(),
                                          ),
                                        );
                                      },
                                style: ObsidianButtonStyle.secondary,
                                height: ext.loginPrimaryButtonHeight,
                                borderRadius: ext.loginCornerRadius,
                                borderColor: scheme.primary,
                                textColor: scheme.primary,
                              ),
                            ),
                            SizedBox(height: mediumSpacing),
                            TextButton.icon(
                              onPressed: busy
                                  ? null
                                  : () async {
                                      await ref
                                          .read(
                                            guestModeControllerProvider
                                                .notifier,
                                          )
                                          .enterGuestMode();
                                    },
                              style: TextButton.styleFrom(
                                foregroundColor: scheme.primary,
                              ),
                              icon: Icon(
                                Icons.person_outline,
                                size: ext.loginLogoIconSize * 0.6,
                              ),
                              label: Text(
                                'Continue as guest (local only)',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: ext.loginPageVerticalPadding),

                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: ext.loginFootnoteMaxWidth,
                        ),
                        child: Text(
                          'Local access stores data on this device only. Sign in to enable end-to-end encrypted synchronization across all your Obsidian Vault instances.',
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

class _LoginMessageCard extends StatelessWidget {
  const _LoginMessageCard({
    required this.message,
    required this.backgroundColor,
    required this.textColor,
    required this.cornerRadius,
    required this.spacing,
    this.textStyle,
  });

  final String message;
  final Color backgroundColor;
  final Color textColor;
  final double cornerRadius;
  final double spacing;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: spacing),
      padding: EdgeInsets.all(spacing),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(cornerRadius),
      ),
      child: Text(message, style: textStyle?.copyWith(color: textColor)),
    );
  }
}
