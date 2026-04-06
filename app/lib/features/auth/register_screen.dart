import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
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

  static const _currencies = ['LKR', 'USD', 'EUR'];

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

    final scheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<VaultSpendThemeExtension>()!;

    final primary = scheme.primary;
    final primaryDark = ext.primaryDark;
    final primaryContainer = scheme.primaryContainer;
    final surface = scheme.surface;
    final onSurface = scheme.onSurface;
    final onSurfaceVariant = scheme.onSurfaceVariant;
    final surfaceContainerHighest = ext.surfaceContainerHighest;
    final surfaceContainerHigh = ext.surfaceContainerHigh;
    final outlineVariant = scheme.outlineVariant;
    final outline = scheme.outline;
    final errorContainer = scheme.errorContainer;
    final onErrorContainer = scheme.onErrorContainer;

    return Scaffold(
      backgroundColor: surface,
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
                color: primary.withOpacity(0.05),
              ),
              child: Theme.of(context).platform == TargetPlatform.iOS
                  ? BackdropFilter(
                      filter: const ColorFilter.mode(
                        Colors.transparent,
                        BlendMode.dstOut,
                      ),
                      child: const SizedBox.shrink(),
                    )
                  : const SizedBox.shrink(),
            ),
          ),

          // Use ImageFilter properly for full background
          BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 60, sigmaY: 60),
            child: const SizedBox.shrink(),
          ),

          // Decorative Element
          Positioned(
            top: 0,
            right: 0,
            width: 400,
            height: 400,
            child: Opacity(
              opacity: 0.2,
              child: Image.network(
                'https://lh3.googleusercontent.com/aida-public/AB6AXuCIRLKwSpB0ZRi_7JHvgshSn1VKc1a28MtBztuYJ2xr20JoDM3qQxam6aAUYUP2MfWxg5Y1vnzFyENKUsHIHJT1EjdyflQyaeVHo4Duc4hWmtAUWCLAzu_KrH9nxndUJVBASq1Bj6CEOe1FlYBeePyWjVA_nsxlsY5nL8a8l5kZIu-4kdY5acMRW14Pi6PswvxI9WiPbdTVso7HpNW_dzJDkrvBvd26HiRmrXz3SEYvYiVDUoDj8I-FZl1rZonwTHQlsiOlrg6upQtl',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    children: [
                      // Logo Area
                      Container(
                        height: 150,
                        alignment: Alignment.center,
                        margin: const EdgeInsets.only(bottom: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(
                                  colors: [primary, primaryContainer],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: primary.withOpacity(0.15),
                                    blurRadius: 40,
                                    spreadRadius: 0,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet,
                                color: Color(0xFF003732), // on-primary
                                size: 36,
                              ),
                            ),
                            Text(
                              'VaultSpend',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w900,
                                fontSize: 36,
                                color: primary,
                                letterSpacing: -1.5,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Header Section
                      Container(
                        margin: const EdgeInsets.only(bottom: 40),
                        child: Column(
                          children: [
                            Text(
                              'Create Account',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w700,
                                fontSize: 24,
                                color: onSurface,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Create your account to enable Cloud sync.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: onSurfaceVariant,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (_localError != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 24),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _localError!,
                            style: GoogleFonts.inter(color: onErrorContainer),
                          ),
                        ),

                      // Form
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Email Field
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 8),
                            child: Text(
                              'EMAIL ADDRESS',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                color: onSurfaceVariant.withOpacity(0.8),
                              ),
                            ),
                          ),
                          TextField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            style: GoogleFonts.inter(color: onSurface),
                            decoration: InputDecoration(
                              hintText: 'name@example.com',
                              hintStyle: GoogleFonts.inter(
                                  color: outline.withOpacity(0.4)),
                              filled: true,
                              fillColor:
                                  surfaceContainerHighest.withOpacity(0.5),
                              prefixIcon: Icon(
                                Icons.mail_outline,
                                color: outline.withOpacity(0.6),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16, horizontal: 16),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: outlineVariant.withOpacity(0.2),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: primary.withOpacity(0.5),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Password Field
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 8),
                            child: Text(
                              'PASSWORD',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                color: onSurfaceVariant.withOpacity(0.8),
                              ),
                            ),
                          ),
                          TextField(
                            controller: _password,
                            obscureText: _obscurePassword,
                            style: GoogleFonts.inter(color: onSurface),
                            decoration: InputDecoration(
                              hintText: '••••••••',
                              hintStyle: GoogleFonts.inter(
                                  color: outline.withOpacity(0.4)),
                              filled: true,
                              fillColor:
                                  surfaceContainerHighest.withOpacity(0.5),
                              prefixIcon: Icon(
                                Icons.lock_outline,
                                color: outline.withOpacity(0.6),
                              ),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: outline.withOpacity(0.6),
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16, horizontal: 16),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: outlineVariant.withOpacity(0.2),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: primary.withOpacity(0.5),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                                left: 4, top: 4, bottom: 20),
                            child: Text(
                              'Must be at least 8 characters long.',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: outline.withOpacity(0.6),
                              ),
                            ),
                          ),

                          // Confirm Password Field
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 8),
                            child: Text(
                              'CONFIRM PASSWORD',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                color: onSurfaceVariant.withOpacity(0.8),
                              ),
                            ),
                          ),
                          TextField(
                            controller: _password2,
                            obscureText: _obscureConfirmPassword,
                            style: GoogleFonts.inter(color: onSurface),
                            onSubmitted: (_) => busy ? null : _submit(),
                            decoration: InputDecoration(
                              hintText: '••••••••',
                              hintStyle: GoogleFonts.inter(
                                  color: outline.withOpacity(0.4)),
                              filled: true,
                              fillColor:
                                  surfaceContainerHighest.withOpacity(0.5),
                              prefixIcon: Icon(
                                Icons.key_outlined,
                                color: outline.withOpacity(0.6),
                              ),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _obscureConfirmPassword =
                                        !_obscureConfirmPassword;
                                  });
                                },
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: outline.withOpacity(0.6),
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16, horizontal: 16),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: outlineVariant.withOpacity(0.2),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: primary.withOpacity(0.5),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Currency Selector
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 8),
                            child: Text(
                              'PREFERRED CURRENCY',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                color: onSurfaceVariant.withOpacity(0.8),
                              ),
                            ),
                          ),
                          DropdownButtonFormField<String>(
                            value: _currency,
                            dropdownColor: surfaceContainerHigh,
                            icon: Icon(
                              Icons.expand_more,
                              color: outline.withOpacity(0.6),
                            ),
                            style: GoogleFonts.inter(color: onSurface),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor:
                                  surfaceContainerHighest.withOpacity(0.5),
                              prefixIcon: Icon(
                                Icons.payments_outlined,
                                color: outline.withOpacity(0.6),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16, horizontal: 16),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: outlineVariant.withOpacity(0.2),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: primary.withOpacity(0.5),
                                ),
                              ),
                            ),
                            items: _currencies
                                .map((c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(
                                          '$c - ${c == 'USD' ? 'United States Dollar' : c == 'LKR' ? 'Sri Lankan Rupee' : 'Euro'}'),
                                    ))
                                .toList(),
                            onChanged: busy
                                ? null
                                : (v) => setState(() => _currency = v ?? 'USD'),
                          ),
                          const SizedBox(height: 24),

                          // Create Account Button
                          Container(
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(
                                colors: [primary, primaryDark],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x33FFFFFF), // inset top glow
                                  offset: Offset(0, 1),
                                ),
                                BoxShadow(
                                  color: Color(0x66006a61),
                                  blurRadius: 20,
                                  offset: Offset(0, 10),
                                  spreadRadius: -5,
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: busy ? null : _submit,
                                child: Center(
                                  child: busy
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF003732),
                                          ),
                                        )
                                      : Text(
                                          'Create account',
                                          style: GoogleFonts.manrope(
                                            fontWeight: FontWeight.w900,
                                            color: const Color(0xFF003732),
                                            fontSize: 16,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Secondary Actions
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: TextButton.icon(
                          onPressed: busy
                              ? null
                              : () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(double.infinity, 56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            foregroundColor: primary,
                          ),
                          icon: const Icon(Icons.arrow_back),
                          label: Text(
                            'Back to sign in',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),

                      // Footnote
                      Padding(
                        padding: const EdgeInsets.only(top: 48),
                        child: Text(
                          'By creating an account, you agree to our Terms of Service and Privacy Policy regarding cloud data synchronization and encryption protocols.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            height: 1.6,
                            color: outline.withOpacity(0.6),
                          ),
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

