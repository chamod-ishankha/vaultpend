import 'package:flutter/material.dart';

/// Shown while restoring session from secure storage.
class AuthLoadingScreen extends StatelessWidget {
  const AuthLoadingScreen({super.key});

  static const _bg = Color(0xFF0B0B0F);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: _bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/branding/app_icon.png',
              width: 96,
              height: 96,
              filterQuality: FilterQuality.high,
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading…',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
