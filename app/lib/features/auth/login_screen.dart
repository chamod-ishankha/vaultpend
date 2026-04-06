import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

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
    
    final scheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<VaultSpendThemeExtension>()!;

    final _primary = scheme.primary;
    final _primaryDark = ext.primaryDark;
    final _primaryContainer = scheme.primaryContainer;
    final _surface = scheme.surface;
    final _onSurface = scheme.onSurface;
    final _onSurfaceVariant = scheme.onSurfaceVariant;
    final _surfaceContainerHighest = ext.surfaceContainerHighest;
    final _outlineVariant = scheme.outlineVariant;
    final _outline = scheme.outline;
    final _errorContainer = scheme.errorContainer;
    final _onErrorContainer = scheme.onErrorContainer;
    final _secondaryContainer = scheme.secondaryContainer;
    final _onSecondaryContainer = scheme.onSecondaryContainer;

    return Scaffold(
      backgroundColor: _surface,
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
                color: _primary.withOpacity(0.05),
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
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
                                  colors: [_primary, _primaryContainer],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _primary.withOpacity(0.15),
                                    blurRadius: 40,
                                    spreadRadius: 0,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet,
                                color: Color(0xFF003732), // text-on-primary
                                size: 36,
                              ),
                            ),
                            Text(
                              'VaultSpend',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w900,
                                fontSize: 36,
                                color: _primary,
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
                              'Welcome Back',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w700,
                                fontSize: 24,
                                color: _onSurface,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Sign in to sync your data with Cloud.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: _onSurfaceVariant,
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
                            color: _errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _localError!,
                            style: GoogleFonts.inter(color: _onErrorContainer),
                          ),
                        ),

                      if (_statusMessage != null && _localError == null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 24),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _secondaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _statusMessage!,
                            style: GoogleFonts.inter(
                                color: _onSecondaryContainer),
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
                              'EMAIL',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                color: _onSurfaceVariant.withOpacity(0.8),
                              ),
                            ),
                          ),
                          TextField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            style: GoogleFonts.inter(color: _onSurface),
                            decoration: InputDecoration(
                              hintText: 'name@company.com',
                              hintStyle:
                                  GoogleFonts.inter(color: _outline.withOpacity(0.4)),
                              filled: true,
                              fillColor: _surfaceContainerHighest.withOpacity(0.5),
                              prefixIcon: Icon(
                                Icons.mail_outline,
                                color: _outline.withOpacity(0.6),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16, horizontal: 16),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: _outlineVariant.withOpacity(0.2),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: _primary.withOpacity(0.5),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Password Field
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 8),
                            child: Text(
                              'PASSWORD',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                color: _onSurfaceVariant.withOpacity(0.8),
                              ),
                            ),
                          ),
                          TextField(
                            controller: _password,
                            obscureText: _obscurePassword,
                            style: GoogleFonts.inter(color: _onSurface),
                            onSubmitted: (_) => busy ? null : _submit(),
                            decoration: InputDecoration(
                              hintText: '••••••••',
                              hintStyle:
                                  GoogleFonts.inter(color: _outline.withOpacity(0.4)),
                              filled: true,
                              fillColor: _surfaceContainerHighest.withOpacity(0.5),
                              prefixIcon: Icon(
                                Icons.lock_outline,
                                color: _outline.withOpacity(0.6),
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
                                  color: _outline.withOpacity(0.6),
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16, horizontal: 16),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: _outlineVariant.withOpacity(0.2),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: _primary.withOpacity(0.5),
                                ),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {},
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 8,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Forgot password?',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Login Button
                          Container(
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(
                                colors: [_primary, _primaryDark],
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
                                          'Sign in',
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

                      // Divider
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 1,
                                color: _outlineVariant.withOpacity(0.15),
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'OR',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                  color: _outline.withOpacity(0.6),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 1,
                                color: _outlineVariant.withOpacity(0.15),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Secondary Actions
                      Column(
                        children: [
                          OutlinedButton(
                            onPressed: busy
                                ? null
                                : () {
                                    Navigator.of(context).push<void>(
                                      MaterialPageRoute(
                                        builder: (_) => const RegisterScreen(),
                                      ),
                                    );
                                  },
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 56),
                              side: const BorderSide(color: Color(0xFF0D9488)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Create account',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: const Color(0xFF0D9488),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextButton.icon(
                            onPressed: busy
                                ? null
                                : () async {
                                    await ref
                                        .read(guestModeControllerProvider.notifier)
                                        .enterGuestMode();
                                  },
                            style: TextButton.styleFrom(
                              minimumSize: const Size(double.infinity, 56),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: Icon(
                              Icons.person_outline,
                              color: _primary,
                            ),
                            label: Text(
                              'Continue as guest (local only)',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: _primary,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Footnote
                      Padding(
                        padding: const EdgeInsets.only(top: 48),
                        child: Text(
                          'Local access stores data on this device only. Sign in to enable end-to-end encrypted synchronization across all your Obsidian Vault instances.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            height: 1.6,
                            color: _outline.withOpacity(0.6),
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
