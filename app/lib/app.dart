import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/notifications/subscription_reminder_service.dart';
import 'core/theme/app_theme.dart';
import 'data/models/expense.dart';
import 'data/models/subscription.dart';
import 'features/auth/auth_loading_screen.dart';
import 'features/auth/auth_providers.dart';
import 'features/auth/auth_session.dart';
import 'features/auth/login_screen.dart';
import 'features/home/shell_screen.dart';
import 'core/providers.dart';

class VaultSpendApp extends ConsumerStatefulWidget {
  const VaultSpendApp({super.key});

  @override
  ConsumerState<VaultSpendApp> createState() => _VaultSpendAppState();
}

class _VaultSpendAppState extends ConsumerState<VaultSpendApp>
    with WidgetsBindingObserver {
  bool _showSplash = true;
  final _reminderService = SubscriptionReminderService();
  Timer? _reminderSyncTicker;
  String _lastGlobalReminderSignature = '';
  bool _syncInFlight = false;
  ProviderSubscription<String?>? _userIdSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_reminderService.initialize());
      unawaited(_syncRemindersGlobally());
      _reminderSyncTicker = Timer.periodic(const Duration(minutes: 2), (_) {
        unawaited(_syncRemindersGlobally());
      });
    });

    _userIdSub = ref.listenManual<String?>(currentUserIdProvider, (
      previous,
      next,
    ) {
      if (previous != next) {
        _lastGlobalReminderSignature = '';
      }
      if (next != null) {
        unawaited(_syncRemindersGlobally());
      }
    }, fireImmediately: true);

    Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _showSplash = false;
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncRemindersGlobally());
    }
  }

  @override
  void dispose() {
    _reminderSyncTicker?.cancel();
    _userIdSub?.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _syncRemindersGlobally() async {
    if (!mounted || _syncInFlight) {
      return;
    }

    _syncInFlight = true;
    try {
      final subscriptions = await ref
          .read(subscriptionRepositoryProvider)
          .getAll();
      final expenses = await ref.read(expenseRepositoryProvider).getAll();
      final signature = _signatureFor(subscriptions, expenses);
      if (signature == _lastGlobalReminderSignature) {
        return;
      }

      await _reminderService.syncGlobalReminders(
        subscriptions: subscriptions,
        expenses: expenses,
      );
      _lastGlobalReminderSignature = signature;
    } catch (_) {
      // Reminder sync should never block app startup or navigation.
    } finally {
      _syncInFlight = false;
    }
  }

  String _signatureFor(
    List<Subscription> subscriptions,
    List<Expense> expenses,
  ) {
    final subSignature = subscriptions
        .map(
          (s) =>
              '${s.id}:${s.name}:${s.nextBillingDate.toIso8601String()}:${s.isTrial}:${s.trialEndsAt?.toIso8601String() ?? ''}',
        )
        .join('|');

    final recurringExpenseSignature = expenses
        .where((e) => e.isRecurring)
        .map(
          (e) =>
              '${e.id}:${e.occurredAt.toIso8601String()}:${e.amount}:${e.currency}',
        )
        .join('|');

    return '$subSignature||$recurringExpenseSignature';
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
