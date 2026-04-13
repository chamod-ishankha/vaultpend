import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/widgets/obsidian_app_bar.dart';
import '../../core/widgets/obsidian_button.dart';
import '../../core/widgets/obsidian_card.dart';
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
    if (!mounted) {
      _hydrated = true;
      _emailController.text = session.user.email;
      _displayNameController.text = session.user.displayName;
      _selectedCurrency = session.user.preferredCurrency;
      return;
    }

    setState(() {
      _hydrated = true;
      _emailController.text = session.user.email;
      _displayNameController.text = session.user.displayName;
      _selectedCurrency = session.user.preferredCurrency;
    });
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

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    try {
      final xFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 150,
        maxHeight: 150,
        imageQuality: 50,
      );
      if (xFile == null) return;

      setState(() { _saving = true; });
      final bytes = await xFile.readAsBytes();
      final base64String = base64Encode(bytes);
      
      await ref.read(authControllerProvider.notifier).updateProfileBase64(base64String);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() { _errorMessage = _friendlyError(e); });
    } finally {
      if (mounted) setState(() { _saving = false; });
    }
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

  String _compactAccountId(String id) {
    if (id.length <= 14) {
      return id;
    }
    return '${id.substring(0, 8)}...${id.substring(id.length - 4)}';
  }

  void _showEditHint() {
    setState(() {
      _statusMessage = 'Use the editable fields below to update your profile.';
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final authState = ref.watch(authControllerProvider);
    final session = authState.value;
    final user = session?.user;
    final busy = _saving || authState.isLoading;
    final signedIn = session != null;

    return Scaffold(
      appBar: ObsidianAppBar(
        centerTitle: false,
        title: Text(
          'Account Profile',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
              color: scheme.surfaceContainerLow,
            ),
            clipBehavior: Clip.antiAlias,
            child: user?.photoBase64 != null
                ? Image.memory(
                    base64Decode(user!.photoBase64!),
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                  )
                : Icon(Icons.person, size: 18, color: scheme.primary),
          ),
        ],
      ),
      body: authState.isLoading && session == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              children: [
                _SectionHeader(label: 'PROFILE DETAILS', color: scheme.primary),
                const SizedBox(height: 8),
                ObsidianCard(
                  level: ObsidianCardTonalLevel.low,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Stack(
                          children: [
                            Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: scheme.outlineVariant,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: user?.photoBase64 != null
                                  ? Image.memory(
                                      base64Decode(user!.photoBase64!),
                                      width: 88,
                                      height: 88,
                                      fit: BoxFit.cover,
                                    )
                                  : Icon(
                                      Icons.person_rounded,
                                      size: 44,
                                      color: scheme.primary,
                                    ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Material(
                                color: scheme.primary,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: signedIn && !busy
                                      ? _pickAndUploadAvatar
                                      : null,
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Icon(
                                      Icons.edit_rounded,
                                      size: 14,
                                      color: scheme.onPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          user?.displayName ?? 'Guest mode',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: Text(
                          user?.email ??
                              'Sign in to edit your account profile.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (user != null) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _ProfileDetailCorner(
                                label: 'ACCOUNT ID',
                                value: _compactAccountId(user.id),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ProfileDetailCorner(
                                label: 'CURRENCY',
                                value: user.preferredCurrency,
                                alignEnd: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (_statusMessage != null) ...[
                        const SizedBox(height: 16),
                        _MessageBanner(
                          message: _statusMessage!,
                          color: scheme.secondaryContainer.withValues(
                            alpha: 0.5,
                          ),
                          foreground: scheme.onSecondaryContainer,
                          icon: Icons.check_circle_outline_rounded,
                        ),
                      ],
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        _MessageBanner(
                          message: _errorMessage!,
                          color: scheme.errorContainer.withValues(alpha: 0.5),
                          foreground: scheme.onErrorContainer,
                          icon: Icons.error_outline_rounded,
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
                  const SizedBox(height: 20),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionHeader(
                          label: 'EDITABLE FIELDS',
                          color: scheme.primary,
                        ),
                        const SizedBox(height: 8),
                        ObsidianCard(
                          level: ObsidianCardTonalLevel.low,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _InputHeader(
                                label: 'EMAIL ADDRESS',
                                color: scheme.primary,
                              ),
                              const SizedBox(height: 8),
                              _ProfileInputField(
                                controller: _emailController,
                                hintText: 'Email address',
                                readOnly: true,
                                enabled: false,
                                prefixIcon: Icons.lock_outline_rounded,
                                iconColor: scheme.outline,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Email cannot be changed for security purpose.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant.withValues(
                                    alpha: 0.75,
                                  ),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _InputHeader(
                                label: 'DISPLAY NAME',
                                color: scheme.primary,
                              ),
                              const SizedBox(height: 8),
                              _ProfileInputField(
                                controller: _displayNameController,
                                hintText: 'Name',
                                prefixIcon: Icons.person_rounded,
                                iconColor: scheme.primary,
                                onChanged: busy ? null : (_) {},
                                validator: _validateDisplayName,
                              ),
                              const SizedBox(height: 16),
                              _InputHeader(
                                label: 'PREFERRED CURRENCY',
                                color: scheme.primary,
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedCurrency,
                                decoration: InputDecoration(
                                  hintText: 'Select currency',
                                  prefixIcon: Icon(
                                    Icons.currency_exchange_rounded,
                                    color: scheme.primary,
                                    size: 20,
                                  ),
                                  hintStyle: theme.textTheme.bodyLarge
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant
                                            .withValues(alpha: 0.6),
                                      ),
                                  filled: true,
                                  fillColor: scheme.surfaceContainerHighest,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 14,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: scheme.outlineVariant,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: scheme.outlineVariant,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: scheme.primary,
                                    ),
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
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _SectionHeader(
                          label: 'SECURITY SETTINGS',
                          color: scheme.error,
                        ),
                        const SizedBox(height: 8),
                        ObsidianCard(
                          level: ObsidianCardTonalLevel.low,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CHANGE PASSWORD',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: scheme.error,
                                  letterSpacing: 0.6,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _ProfileInputField(
                                controller: _currentPasswordController,
                                hintText: 'Current Password',
                                obscureText: _obscureCurrentPassword,
                                validator: _validateCurrentPassword,
                                prefixIcon: Icons.lock_outline_rounded,
                                iconColor: scheme.error,
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
                              _ProfileInputField(
                                controller: _newPasswordController,
                                hintText: 'New Password',
                                obscureText: _obscureNewPassword,
                                validator: _validateNewPassword,
                                prefixIcon: Icons.lock_outline_rounded,
                                iconColor: scheme.error,
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
                              _ProfileInputField(
                                controller: _confirmPasswordController,
                                hintText: 'Confirm New Password',
                                obscureText: _obscureConfirmPassword,
                                validator: _validateConfirmPassword,
                                prefixIcon: Icons.lock_outline_rounded,
                                iconColor: scheme.error,
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
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        ObsidianButton(
                          onPressed: busy ? null : _save,
                          text: 'SAVE PROFILE',
                          isLoading: busy,
                          style: ObsidianButtonStyle.primary,
                          width: double.infinity,
                          enableShimmer: true,
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: TextButton(
                            onPressed: busy ? null : _reset,
                            child: Text(
                              'RESET ALL CHANGES',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: scheme.onSurfaceVariant.withValues(
                                  alpha: 0.7,
                                ),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      label,
      style: theme.textTheme.labelLarge?.copyWith(
        letterSpacing: 0.9,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );
  }
}

class _InputHeader extends StatelessWidget {
  const _InputHeader({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      label,
      style: theme.textTheme.labelMedium?.copyWith(
        color: color,
        letterSpacing: 0.7,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ProfileDetailCorner extends StatelessWidget {
  const _ProfileDetailCorner({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: alignEnd
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.primary,
              letterSpacing: 0.7,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileInputField extends StatelessWidget {
  const _ProfileInputField({
    required this.controller,
    required this.hintText,
    this.prefixIcon,
    this.iconColor,
    this.validator,
    this.onChanged,
    this.suffixIcon,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData? prefixIcon;
  final Color? iconColor;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final Widget? suffixIcon;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled
              ? scheme.outlineVariant
              : scheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        readOnly: readOnly,
        obscureText: obscureText,
        validator: validator,
        onChanged: onChanged,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: enabled
              ? scheme.onSurface
              : scheme.onSurfaceVariant.withValues(alpha: 0.8),
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: theme.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
          ),
          prefixIcon: prefixIcon == null
              ? null
              : Icon(prefixIcon, size: 20, color: iconColor ?? scheme.primary),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          errorStyle: const TextStyle(height: 0, fontSize: 0),
        ),
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({
    required this.message,
    required this.color,
    required this.foreground,
    required this.icon,
  });

  final String message;
  final Color color;
  final Color foreground;
  final IconData icon;

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
          Icon(icon, size: 20, color: foreground),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
