import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/obsidian_app_bar.dart';
import '../../core/widgets/obsidian_button.dart';
import '../../core/widgets/obsidian_card.dart';
import '../../core/widgets/obsidian_text_field.dart';
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final authState = ref.watch(authControllerProvider);
    final session = authState.value;
    final busy = _saving || authState.isLoading;
    final signedIn = session != null;

    return Scaffold(
      appBar: const ObsidianAppBar(title: Text('Account Profile')),
      body: authState.isLoading && session == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              children: [
                Text(
                  'Profile details',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                ObsidianCard(
                  level: ObsidianCardTonalLevel.low,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: scheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.person_rounded,
                              size: 28,
                              color: scheme.primary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  signedIn
                                      ? session.user.displayName
                                      : 'Guest mode',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  signedIn
                                      ? session.user.email
                                      : 'Sign in to edit your account profile.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (signedIn) ...[
                        const SizedBox(height: 20),
                        _InfoField(label: 'Account ID', value: session.user.id),
                        const SizedBox(height: 12),
                        _InfoField(
                          label: 'Preferred currency',
                          value: session.user.preferredCurrency,
                        ),
                      ],
                      if (_statusMessage != null) ...[
                        const SizedBox(height: 16),
                        _MessageBanner(
                          message: _statusMessage!,
                          color: scheme.secondaryContainer.withOpacity(0.5),
                          foreground: scheme.onSecondaryContainer,
                        ),
                      ],
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        _MessageBanner(
                          message: _errorMessage!,
                          color: scheme.errorContainer.withOpacity(0.5),
                          foreground: scheme.onErrorContainer,
                        ),
                      ],
                      if (!signedIn) ...[
                        const SizedBox(height: 16),
                        ObsidianButton(
                          onPressed: busy
                              ? null
                              : () {
                                  Navigator.of(context).push<void>(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const LoginScreen(),
                                    ),
                                  );
                                },
                          text: 'Sign in to edit profile',
                          style: ObsidianButtonStyle.primary,
                          width: double.infinity,
                        ),
                      ],
                    ],
                  ),
                ),
                if (signedIn) ...[
                  Text(
                    'Editable fields',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ObsidianCard(
                    level: ObsidianCardTonalLevel.low,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ObsidianTextField(
                            controller: _emailController,
                            label: 'Email address',
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Email updates are disabled. Use sign-in verification flows if account email needs to change.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ObsidianTextField(
                            controller: _displayNameController,
                            label: 'Display name',
                            onChanged: busy ? null : (_) {},
                            validator: _validateDisplayName,
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _selectedCurrency,
                            decoration: InputDecoration(
                              labelText: 'Preferred currency',
                              labelStyle: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: scheme.outlineVariant),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: scheme.outlineVariant),
                              ),
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
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Change password',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ObsidianTextField(
                            controller: _currentPasswordController,
                            label: 'Current password',
                            obscureText: _obscureCurrentPassword,
                            validator: _validateCurrentPassword,
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _obscureCurrentPassword =
                                      !_obscureCurrentPassword;
                                });
                              },
                              icon: Icon(
                                _obscureCurrentPassword
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ObsidianTextField(
                            controller: _newPasswordController,
                            label: 'New password',
                            obscureText: _obscureNewPassword,
                            validator: _validateNewPassword,
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _obscureNewPassword =
                                      !_obscureNewPassword;
                                });
                              },
                              icon: Icon(
                                _obscureNewPassword
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ObsidianTextField(
                            controller: _confirmPasswordController,
                            label: 'Confirm new password',
                            obscureText: _obscureConfirmPassword,
                            validator: _validateConfirmPassword,
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword;
                                });
                              },
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Leave password fields empty if you do not want to change it.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: ObsidianButton(
                                  onPressed: busy ? null : _save,
                                  text: 'Save Changes',
                                  isLoading: busy,
                                  style: ObsidianButtonStyle.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              ObsidianButton(
                                onPressed: busy ? null : _reset,
                                text: 'Reset',
                                style: ObsidianButtonStyle.tertiary,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _InfoField extends StatelessWidget {
  const _InfoField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 20, color: foreground),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
