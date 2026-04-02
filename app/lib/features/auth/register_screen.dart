import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
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
                        color: Theme.of(context).colorScheme.onErrorContainer,
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
                labelText: 'Password (min 8 characters)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _password2,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _currency,
              decoration: const InputDecoration(
                labelText: 'Preferred currency',
                border: OutlineInputBorder(),
              ),
              items: _currencies
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: busy
                  ? null
                  : (v) => setState(() => _currency = v ?? 'USD'),
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
                    : const Text('Register'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
