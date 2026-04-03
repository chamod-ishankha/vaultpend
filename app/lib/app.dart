import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/auth_loading_screen.dart';
import 'features/auth/auth_providers.dart';
import 'features/auth/auth_session.dart';
import 'features/auth/login_screen.dart';
import 'features/home/shell_screen.dart';

class VaultSpendApp extends ConsumerStatefulWidget {
  const VaultSpendApp({super.key});

  @override
  ConsumerState<VaultSpendApp> createState() => _VaultSpendAppState();
}

class _VaultSpendAppState extends ConsumerState<VaultSpendApp> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();

    Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _showSplash = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final guestMode = ref.watch(guestModeControllerProvider);

    Widget homeFor(AuthSession? session, bool isGuest) {
      if (session != null || isGuest) {
        return const ShellScreen();
      }
      return const LoginScreen();
    }

    Widget resolvedHome = auth.when(
      data: (session) => guestMode.when(
        data: (isGuest) => homeFor(session, isGuest),
        loading: () => const AuthLoadingScreen(),
        error: (e, _) => LoginScreen(initialError: e.toString()),
      ),
      loading: () => const AuthLoadingScreen(),
      error: (e, _) => LoginScreen(initialError: e.toString()),
    );

    return MaterialApp(
      title: 'VaultSpend',
      debugShowCheckedModeBanner: false,
      theme: buildVaultSpendTheme(brightness: Brightness.light),
      darkTheme: buildVaultSpendTheme(brightness: Brightness.dark),
      themeMode: ThemeMode.dark,
      home: _showSplash ? const _VaultSpendSplashScreen() : resolvedHome,
    );
  }
}

class _VaultSpendSplashScreen extends StatelessWidget {
  const _VaultSpendSplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SizedBox.expand(
        child: Image(
          image: AssetImage('assets/branding/splash.png'),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
