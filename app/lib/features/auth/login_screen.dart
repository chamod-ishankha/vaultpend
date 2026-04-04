import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaultspend/core/firebase/firebase_bootstrap.dart';

import 'auth_providers.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.initialError});

  final String? initialError;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _localError;
  String? _statusMessage;
  bool _submitting = false;

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

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.center,
                  child: Image.asset(
                    'assets/branding/logo.png',
                    height: 150,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to sync your data with Cloud.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                if (_localError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Material(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _localError!,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_statusMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Material(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _statusMessage!,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ),
                  ),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => busy ? null : _submit(),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: busy ? null : _submit,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Sign in'),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: busy
                      ? null
                      : () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => const RegisterScreen(),
                            ),
                          );
                        },
                  child: const Text('Create account'),
                ),
                TextButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          await ref
                              .read(guestModeControllerProvider.notifier)
                              .enterGuestMode();
                        },
                  icon: const Icon(Icons.person_outline),
                  label: const Text('Continue as guest (local only)'),
                ),
                const SizedBox(height: 24),
                Text(
                  'Expenses and subscriptions work offline on this device. Sign in to enable Cloud sync across devices.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
