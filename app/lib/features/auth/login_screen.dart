import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
                            'Welcome Back',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sign in to sync your data with Cloud.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),

                      if (_statusMessage != null && _localError == null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 24),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: scheme.secondaryContainer.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: scheme.secondary.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            _statusMessage!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSecondaryContainer,
                            ),
                          ),
                        ),

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
                            label: 'EMAIL',
                            hintText: 'name@company.com',
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: const Icon(Icons.mail_outline),
                          ),
                          const SizedBox(height: 24),
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
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {},
                              child: const Text('Forgot password?'),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ObsidianButton(
                            text: busy ? 'Signing in...' : 'Sign in',
                            onPressed: busy ? () {} : _submit,
                          ),
                        ],
                      ),

                      // Divider
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Row(
                          children: [
                            Expanded(child: Divider(color: scheme.outlineVariant)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'OR',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.outline,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: scheme.outlineVariant)),
                          ],
                        ),
                      ),

                      // Secondary Actions
                      Column(
                        children: [
                          ObsidianButton(
                            text: 'Create account',
                            style: ObsidianButtonStyle.secondary,
                            onPressed: () {
                              Navigator.of(context).push<void>(
                                MaterialPageRoute(
                                  builder: (_) => const RegisterScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          ObsidianButton(
                            text: 'Continue as guest',
                            style: ObsidianButtonStyle.tertiary,
                            onPressed: () async {
                              await ref
                                  .read(guestModeControllerProvider.notifier)
                                  .enterGuestMode();
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 48),

                      Text(
                        'Local access stores data on this device only. Sign in to enable end-to-end encrypted synchronization.',
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
