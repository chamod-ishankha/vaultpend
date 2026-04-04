import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../auth/auth_session.dart';
import '../auth/login_screen.dart';

class ProfileUpdateScreen extends ConsumerStatefulWidget {
  const ProfileUpdateScreen({super.key});

  @override
  ConsumerState<ProfileUpdateScreen> createState() =>
      _ProfileUpdateScreenState();
}

class _ProfileUpdateScreenState extends ConsumerState<ProfileUpdateScreen> {
  static const _currencies = ['LKR', 'USD', 'EUR'];

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  ProviderSubscription<AsyncValue<AuthSession?>>? _authSubscription;
  bool _hydrated = false;
  bool _saving = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String _selectedCurrency = 'USD';
  String? _statusMessage;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _authSubscription = ref.listenManual<AsyncValue<AuthSession?>>(
      authControllerProvider,
      (previous, next) {
        next.whenOrNull(
          data: (session) {
            if (session != null) {
              _hydrateFromSession(session);
            }
            return null;
          },
        );
      },
    );

    final session = ref.read(authControllerProvider).value;
    if (session != null) {
      _hydrateFromSession(session);
    } else {
      _selectedCurrency = ref.read(preferredCurrencyProvider);
    }
  }

  @override
  void dispose() {
    _authSubscription?.close();
    _emailController.dispose();
    _displayNameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _hydrateFromSession(AuthSession session) {
    if (_hydrated) {
      return;
    }
    _hydrated = true;
    _emailController.text = session.user.email;
    _displayNameController.text = session.user.displayName;
    _selectedCurrency = session.user.preferredCurrency;
  }

  bool get _passwordChangeRequested {
    return _currentPasswordController.text.isNotEmpty ||
        _newPasswordController.text.isNotEmpty ||
        _confirmPasswordController.text.isNotEmpty;
  }

  String? _validateDisplayName(String? value) {
    final displayName = value?.trim() ?? '';
    if (displayName.isEmpty) {
      return 'Display name is required';
    }
    if (displayName.length < 2) {
      return 'Display name must be at least 2 characters';
    }
    return null;
  }

  String? _validateCurrentPassword(String? value) {
    if (!_passwordChangeRequested) {
      return null;
    }
    if ((value ?? '').isEmpty) {
      return 'Enter current password';
    }
    return null;
  }

  String? _validateNewPassword(String? value) {
    if (!_passwordChangeRequested) {
      return null;
    }
    final text = value ?? '';
    if (text.isEmpty) {
      return 'Enter new password';
    }
    if (text.length < 8) {
      return 'New password must be at least 8 characters';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (!_passwordChangeRequested) {
      return null;
    }
    if ((value ?? '').isEmpty) {
      return 'Confirm new password';
    }
    if (value != _newPasswordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  String _friendlyError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'requires-recent-login':
          return 'Please sign in again before updating your email.';
        case 'invalid-email':
          return 'Enter a valid email address.';
        case 'email-already-in-use':
          return 'That email address is already in use.';
        case 'operation-not-allowed':
          return 'Email updates are not enabled for this account.';
        case 'wrong-password':
        case 'invalid-credential':
          return 'Current password is incorrect.';
        case 'weak-password':
          return 'New password is too weak.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
      }
    }
    return error.toString();
  }

  Future<void> _save() async {
    final session = ref.read(authControllerProvider).value;
    if (session == null) {
      return;
    }
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final displayName = _displayNameController.text.trim();
    final currency = _selectedCurrency;
    final displayNameChanged = displayName != session.user.displayName;
    final currencyChanged = currency != session.user.preferredCurrency;
    final passwordChangeRequested = _passwordChangeRequested;

    if (!displayNameChanged && !currencyChanged && !passwordChangeRequested) {
      setState(() {
        _statusMessage = 'No changes to save.';
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _saving = true;
      _statusMessage = null;
      _errorMessage = null;
    });

    try {
      if (displayNameChanged) {
        await ref
            .read(authControllerProvider.notifier)
            .updateDisplayName(displayName);
      }
      if (currencyChanged) {
        await ref
            .read(preferredCurrencyControllerProvider.notifier)
            .setPreferredCurrency(currency);
      }
      if (passwordChangeRequested) {
        await ref
            .read(authControllerProvider.notifier)
            .updatePassword(
              currentPassword: _currentPasswordController.text,
              newPassword: _newPasswordController.text,
            );
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = passwordChangeRequested
            ? 'Profile and password updated.'
            : 'Profile updated.';
        _hydrated = true;
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile saved.')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = _friendlyError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _reset() {
    final session = ref.read(authControllerProvider).value;
    if (session == null) {
      return;
    }
    setState(() {
      _emailController.text = session.user.email;
      _displayNameController.text = session.user.displayName;
      _selectedCurrency = session.user.preferredCurrency;
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _statusMessage = null;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final session = authState.value;
    final busy = _saving || authState.isLoading;
    final signedIn = session != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Account Profile')),
      body: authState.isLoading && session == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              children: [
                Text(
                  'Profile details',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              child: Icon(
                                Icons.person_outline,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    signedIn
                                        ? session.user.displayName
                                        : 'Guest mode',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    signedIn
                                        ? session.user.email
                                        : 'Sign in to edit your account profile.',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (signedIn) ...[
                          Text(
                            'Account ID',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(session.user.id),
                          const SizedBox(height: 10),
                          Text(
                            'Current preferred currency',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(session.user.preferredCurrency),
                        ],
                        if (_statusMessage != null) ...[
                          const SizedBox(height: 12),
                          _MessageBanner(
                            message: _statusMessage!,
                            color: Theme.of(
                              context,
                            ).colorScheme.secondaryContainer,
                            foreground: Theme.of(
                              context,
                            ).colorScheme.onSecondaryContainer,
                          ),
                        ],
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 12),
                          _MessageBanner(
                            message: _errorMessage!,
                            color: Theme.of(context).colorScheme.errorContainer,
                            foreground: Theme.of(
                              context,
                            ).colorScheme.onErrorContainer,
                          ),
                        ],
                        if (!signedIn) ...[
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: busy
                                ? null
                                : () {
                                    Navigator.of(context).push<void>(
                                      MaterialPageRoute<void>(
                                        builder: (_) => const LoginScreen(),
                                      ),
                                    );
                                  },
                            icon: const Icon(Icons.login_outlined),
                            label: const Text('Sign in to edit profile'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (signedIn) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Editable fields',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _emailController,
                              enabled: false,
                              readOnly: true,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              decoration: const InputDecoration(
                                labelText: 'Email address',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Email updates are disabled. Use sign-in verification flows if account email needs to change.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _displayNameController,
                              enabled: !busy,
                              decoration: const InputDecoration(
                                labelText: 'Display name',
                                border: OutlineInputBorder(),
                              ),
                              validator: _validateDisplayName,
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedCurrency,
                              decoration: const InputDecoration(
                                labelText: 'Preferred currency',
                                border: OutlineInputBorder(),
                              ),
                              items: _currencies
                                  .map(
                                    (currency) => DropdownMenuItem(
                                      value: currency,
                                      child: Text(currency),
                                    ),
                                  )
                                  .toList(),
                              onChanged: busy
                                  ? null
                                  : (value) {
                                      if (value == null) {
                                        return;
                                      }
                                      setState(() {
                                        _selectedCurrency = value;
                                      });
                                    },
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'This currency is used as the base for new amounts and account-wide display.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Change password',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _currentPasswordController,
                              enabled: !busy,
                              obscureText: _obscureCurrentPassword,
                              decoration: InputDecoration(
                                labelText: 'Current password',
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  tooltip: _obscureCurrentPassword
                                      ? 'Show password'
                                      : 'Hide password',
                                  onPressed: () {
                                    setState(() {
                                      _obscureCurrentPassword =
                                          !_obscureCurrentPassword;
                                    });
                                  },
                                  icon: Icon(
                                    _obscureCurrentPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                ),
                              ),
                              validator: _validateCurrentPassword,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _newPasswordController,
                              enabled: !busy,
                              obscureText: _obscureNewPassword,
                              decoration: InputDecoration(
                                labelText: 'New password',
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  tooltip: _obscureNewPassword
                                      ? 'Show password'
                                      : 'Hide password',
                                  onPressed: () {
                                    setState(() {
                                      _obscureNewPassword =
                                          !_obscureNewPassword;
                                    });
                                  },
                                  icon: Icon(
                                    _obscureNewPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                ),
                              ),
                              validator: _validateNewPassword,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _confirmPasswordController,
                              enabled: !busy,
                              obscureText: _obscureConfirmPassword,
                              decoration: InputDecoration(
                                labelText: 'Confirm new password',
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  tooltip: _obscureConfirmPassword
                                      ? 'Show password'
                                      : 'Hide password',
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
                                  ),
                                ),
                              ),
                              validator: _validateConfirmPassword,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Leave password fields empty if you do not want to change it.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton(
                                    onPressed: busy ? null : _save,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      child: busy
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Text('Save profile'),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                TextButton(
                                  onPressed: busy ? null : _reset,
                                  child: const Text('Reset'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({
    required this.message,
    required this.color,
    required this.foreground,
  });

  final String message;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: foreground),
      ),
    );
  }
}
