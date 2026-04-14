import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'core/notifications/subscription_reminder_service.dart';
import 'core/theme/app_theme.dart';
import 'data/models/expense.dart';
import 'data/models/subscription.dart';
import 'features/auth/auth_loading_screen.dart';
import 'features/auth/auth_providers.dart';
import 'features/auth/auth_session.dart';
import 'features/auth/login_screen.dart';
import 'features/home/shell_screen.dart';
import 'features/splash/splash_screen.dart';
import 'core/providers.dart';

final _logger = Logger('VaultSpend.AppReminders');

class VaultSpendApp extends ConsumerStatefulWidget {
  const VaultSpendApp({super.key});

  @override
  ConsumerState<VaultSpendApp> createState() => _VaultSpendAppState();
}

class _VaultSpendAppState extends ConsumerState<VaultSpendApp>
    with WidgetsBindingObserver {
  bool _animationComplete = false;
  final _reminderService = SubscriptionReminderService();
  Timer? _reminderSyncTicker;
  String _lastGlobalReminderSignature = '';
  bool _syncInFlight = false;
  ProviderSubscription<String?>? _userIdSub;
  ProviderSubscription<bool>? _remindersEnabledSub;
  ProviderSubscription<bool>? _subscriptionRemindersEnabledSub;
  ProviderSubscription<bool>? _recurringExpenseRemindersEnabledSub;

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

    _remindersEnabledSub = ref.listenManual<bool>(remindersEnabledProvider, (
      previous,
      next,
    ) {
      if (previous != next) {
        _lastGlobalReminderSignature = '';
      }
      if (next) {
        unawaited(_syncRemindersGlobally());
      } else {
        unawaited(_reminderService.cancelManagedReminders());
      }
    }, fireImmediately: true);

    _subscriptionRemindersEnabledSub = ref.listenManual<bool>(
      subscriptionRemindersEnabledProvider,
      (previous, next) {
        if (previous != next) {
          _lastGlobalReminderSignature = '';
          unawaited(_syncRemindersGlobally());
        }
      },
      fireImmediately: true,
    );

    _recurringExpenseRemindersEnabledSub = ref.listenManual<bool>(
      recurringExpenseRemindersEnabledProvider,
      (previous, next) {
        if (previous != next) {
          _lastGlobalReminderSignature = '';
          unawaited(_syncRemindersGlobally());
        }
      },
      fireImmediately: true,
    );
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
    _remindersEnabledSub?.close();
    _subscriptionRemindersEnabledSub?.close();
    _recurringExpenseRemindersEnabledSub?.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _syncRemindersGlobally() async {
    if (!mounted || _syncInFlight) {
      return;
    }

    final scopedUserId = ref.read(currentUserIdProvider);
    if (scopedUserId == null) {
      _logger.info('app_global_reminder_sync_skipped_no_user_scope');
      return;
    }

    final remindersEnabled = ref.read(remindersEnabledProvider);
    if (!remindersEnabled) {
      await _reminderService.cancelManagedReminders();
      _lastGlobalReminderSignature = '';
      return;
    }
    final subscriptionRemindersEnabled = ref.read(
      subscriptionRemindersEnabledProvider,
    );
    final recurringExpenseRemindersEnabled = ref.read(
      recurringExpenseRemindersEnabledProvider,
    );

    _logger.info(
      'app_global_reminder_sync_started '
      'remindersEnabled=$remindersEnabled '
      'subscriptionRemindersEnabled=$subscriptionRemindersEnabled '
      'recurringExpenseRemindersEnabled=$recurringExpenseRemindersEnabled',
    );

    _syncInFlight = true;
    try {
      final subscriptions = await ref
          .read(subscriptionRepositoryProvider)
          .getAll();
      final expenses = await ref.read(expenseRepositoryProvider).getAll();
      final signature = _signatureFor(subscriptions, expenses);
      if (signature == _lastGlobalReminderSignature) {
        _logger.info('app_global_reminder_sync_skipped_same_signature');
        return;
      }

      await _reminderService.syncGlobalReminders(
        subscriptions: subscriptions,
        expenses: expenses,
        includeSubscriptions: subscriptionRemindersEnabled,
        includeRecurringExpenses: recurringExpenseRemindersEnabled,
      );
      _lastGlobalReminderSignature = signature;
      _logger.info('app_global_reminder_sync_completed');
    } catch (error, stack) {
      _logger.warning('app_global_reminder_sync_failed', error, stack);
      // Reminder sync should never block app startup or navigation.
    } finally {
      _syncInFlight = false;
    }
  }

  String _signatureFor(
    List<Subscription> subscriptions,
    List<Expense> expenses,
  ) {
    final remindersEnabled = ref.read(remindersEnabledProvider);
    final subscriptionRemindersEnabled = ref.read(
      subscriptionRemindersEnabledProvider,
    );
    final recurringExpenseRemindersEnabled = ref.read(
      recurringExpenseRemindersEnabledProvider,
    );

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

    return '$remindersEnabled|$subscriptionRemindersEnabled|$recurringExpenseRemindersEnabled||$subSignature||$recurringExpenseSignature';
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

    // Logic: Only hide splash when:
    // 1. Animation is complete
    // 2. Auth state is decided (not loading)
    // 3. GuestMode state is decided (not loading)
    final bool authLoaded = !auth.isLoading && !guestMode.isLoading;
    final bool showSplash = !_animationComplete || !authLoaded;

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
      color: const Color(0xFF131317), // Prevents white flash before theme init
      theme: buildVaultSpendTheme(brightness: Brightness.light),
      darkTheme: buildVaultSpendTheme(brightness: Brightness.dark),
      themeMode: ThemeMode.dark,
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        switchInCurve: Curves.easeIn,
        switchOutCurve: Curves.easeOut,
        child: showSplash
            ? SplashScreen(
                key: const ValueKey('splash'),
                onComplete: () {
                  if (mounted) setState(() => _animationComplete = true);
                },
              )
            : KeyedSubtree(
                key: const ValueKey('app_home'),
                child: resolvedHome,
              ),
      ),
    );
  }
}
