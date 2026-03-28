import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/auth_loading_screen.dart';
import 'features/auth/auth_providers.dart';
import 'features/auth/login_screen.dart';
import 'features/home/shell_screen.dart';

class VaultSpendApp extends ConsumerWidget {
  const VaultSpendApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    return MaterialApp(
      title: 'VaultSpend',
      debugShowCheckedModeBanner: false,
      theme: buildVaultSpendTheme(brightness: Brightness.light),
      darkTheme: buildVaultSpendTheme(brightness: Brightness.dark),
      themeMode: ThemeMode.dark,
      home: auth.when(
        data: (session) => session == null
            ? const LoginScreen()
            : const ShellScreen(),
        loading: () => const AuthLoadingScreen(),
        error: (e, _) => LoginScreen(initialError: e.toString()),
      ),
    );
  }
}
