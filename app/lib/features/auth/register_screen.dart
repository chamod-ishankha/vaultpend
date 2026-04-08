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

  static const _currencies = ['LKR', 'USD', 'EUR', 'GBP', 'JPY'];

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

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Ambient Glow
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 600,
              height: 600,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primary.withOpacity(0.05),
              ),
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                  child: const SizedBox.shrink(),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    children: [
                      // Logo Area
                      Column(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                colors: [scheme.primary, scheme.primaryContainer],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: scheme.primary.withOpacity(0.15),
                                  blurRadius: 40,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.account_balance_wallet,
                              color: Color(0xFF003732),
                              size: 32,
                            ),
                          ),
                          Text(
                            'VaultSpend',
                            style: theme.textTheme.displaySmall?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.5,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 48),

                      // Header Section
                      Column(
                        children: [
                          Text(
                            'Create Account',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Join the Obsidian series for secure finance.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),

                      if (_localError != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 24),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: scheme.errorContainer.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: scheme.error.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            _localError!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onErrorContainer,
                            ),
                          ),
                        ),

                      // Form
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ObsidianTextField(
                            label: 'EMAIL ADDRESS',
                            hintText: 'name@example.com',
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: const Icon(Icons.mail_outline),
                          ),
                          const SizedBox(height: 20),
                          ObsidianTextField(
                            label: 'PASSWORD',
                            hintText: '••••••••',
                            controller: _password,
                            obscureText: _obscurePassword,
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ObsidianTextField(
                            label: 'CONFIRM PASSWORD',
                            hintText: '••••••••',
                            controller: _password2,
                            obscureText: _obscureConfirmPassword,
                            prefixIcon: const Icon(Icons.key_outlined),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // Currency dropdown custom implementation
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 4, bottom: 8),
                                child: Text(
                                  'PREFERRED CURRENCY',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: ext.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _currency,
                                    isExpanded: true,
                                    dropdownColor: ext.surfaceContainerHigh,
                                    icon: const Icon(Icons.expand_more),
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: scheme.onSurface,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    items: _currencies.map((c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c),
                                    )).toList(),
                                    onChanged: busy ? null : (v) => setState(() => _currency = v ?? 'USD'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 32),
                          
                          ObsidianButton(
                            text: busy ? 'Creating account...' : 'Create account',
                            onPressed: busy ? () {} : _submit,
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      ObsidianButton(
                        text: 'Back to sign in',
                        style: ObsidianButtonStyle.tertiary,
                        onPressed: () => Navigator.of(context).pop(),
                      ),

                      const SizedBox(height: 48),

                      Text(
                        'By creating an account, you agree to our Terms of Service regarding end-to-end encrypted synchronization.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.outline,
                          height: 1.6,
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

