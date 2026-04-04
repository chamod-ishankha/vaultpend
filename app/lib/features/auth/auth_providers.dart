import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaultspend/core/firebase/firebase_bootstrap.dart';
import 'package:vaultspend/core/logging/app_logging.dart';

import 'auth_session.dart';
import 'sync_status.dart';
import 'token_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());
final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final authControllerProvider =
    AsyncNotifierProvider<AuthNotifier, AuthSession?>(AuthNotifier.new);

final guestModeControllerProvider =
    AsyncNotifierProvider<GuestModeNotifier, bool>(GuestModeNotifier.new);
final remindersEnabledControllerProvider =
    AsyncNotifierProvider<RemindersEnabledNotifier, bool>(
      RemindersEnabledNotifier.new,
    );
final subscriptionRemindersEnabledControllerProvider =
    AsyncNotifierProvider<SubscriptionRemindersEnabledNotifier, bool>(
      SubscriptionRemindersEnabledNotifier.new,
    );
final recurringExpenseRemindersEnabledControllerProvider =
    AsyncNotifierProvider<RecurringExpenseRemindersEnabledNotifier, bool>(
      RecurringExpenseRemindersEnabledNotifier.new,
    );

const guestLocalUserId = 'guest-local';

final isGuestModeProvider = Provider<bool>((ref) {
  return ref.watch(guestModeControllerProvider).maybeWhen(
        data: (value) => value,
        orElse: () => false,
      );
});

final remindersEnabledProvider = Provider<bool>((ref) {
  return ref.watch(remindersEnabledControllerProvider).value ?? true;
});

final subscriptionRemindersEnabledProvider = Provider<bool>((ref) {
  return ref.watch(subscriptionRemindersEnabledControllerProvider).value ??
      true;
});

final recurringExpenseRemindersEnabledProvider = Provider<bool>((ref) {
  return ref.watch(recurringExpenseRemindersEnabledControllerProvider).value ??
      true;
});

/// Server-side user id (JWT `sub` / profile `id`). Local Isar data is scoped by this.
final currentUserIdProvider = Provider<String?>((ref) {
  final authUserId = ref.watch(authControllerProvider).maybeWhen(
    data: (session) => session?.user.id,
    orElse: () => null,
  );
  if (authUserId != null) return authUserId;
  if (ref.watch(isGuestModeProvider)) return guestLocalUserId;
  return null;
});

final syncStatusProvider = FutureProvider.autoDispose<SyncStatus>((ref) async {
  if (ref.watch(isGuestModeProvider)) {
    throw StateError('sync is unavailable in guest mode');
  }
  final session = ref.watch(authControllerProvider).maybeWhen(
    data: (value) => value,
    orElse: () => null,
  );
  if (session == null) {
    throw StateError('syncStatusProvider requires signed-in session');
  }

  DateTime? coerceDate(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  Future<SyncStatusSection> readCollectionSection(String collection) async {
    final query = await FirebaseFirestore.instance
        .collection('users')
        .doc(session.user.id)
        .collection(collection)
        .get();

    DateTime? latest;
    for (final doc in query.docs) {
      final updatedAt = coerceDate(doc.data()['updated_at']);
      if (updatedAt != null && (latest == null || updatedAt.isAfter(latest))) {
        latest = updatedAt;
      }
    }

    return SyncStatusSection(count: query.docs.length, lastUpdatedAt: latest);
  }

  final results = await Future.wait([
    readCollectionSection('categories'),
    readCollectionSection('expenses'),
    readCollectionSection('subscriptions'),
  ]);

  return SyncStatus(
    categories: results[0],
    expenses: results[1],
    subscriptions: results[2],
  );
});

class GuestModeNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    return ref.read(tokenStorageProvider).readGuestMode();
  }

  Future<void> enterGuestMode() async {
    final logger = ref.read(appLoggerProvider);
    final storage = ref.read(tokenStorageProvider);
    await ref.read(firebaseAuthProvider).signOut();
    await storage.writeGuestMode(true);
    state = const AsyncValue.data(true);
    logger.info('guest_mode_enabled');
    await ref
        .read(activityLogServiceProvider)
        .add(
          action: 'Guest mode enabled',
          details: 'Signed out and switched to local-only mode.',
        );
  }

  Future<void> exitGuestMode() async {
    final logger = ref.read(appLoggerProvider);
    final storage = ref.read(tokenStorageProvider);
    await storage.clearGuestMode();
    state = const AsyncValue.data(false);
    logger.info('guest_mode_disabled');
    await ref
        .read(activityLogServiceProvider)
        .add(
          action: 'Guest mode disabled',
          details: 'Account sign-in is now available.',
        );
  }
}

class RemindersEnabledNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    return ref.read(tokenStorageProvider).readRemindersEnabled();
  }

  Future<void> setEnabled(bool enabled) async {
    final logger = ref.read(appLoggerProvider);
    await ref.read(tokenStorageProvider).writeRemindersEnabled(enabled);
    state = AsyncValue.data(enabled);
    logger.info('reminders_enabled_set value=$enabled');
    await ref
        .read(activityLogServiceProvider)
        .add(action: 'Renewal reminders ${enabled ? 'enabled' : 'disabled'}');
  }
}

class SubscriptionRemindersEnabledNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    return ref.read(tokenStorageProvider).readSubscriptionRemindersEnabled();
  }

  Future<void> setEnabled(bool enabled) async {
    final logger = ref.read(appLoggerProvider);
    await ref
        .read(tokenStorageProvider)
        .writeSubscriptionRemindersEnabled(enabled);
    state = AsyncValue.data(enabled);
    logger.info('subscription_reminders_enabled_set value=$enabled');
    await ref
        .read(activityLogServiceProvider)
        .add(
          action: 'Subscription reminders ${enabled ? 'enabled' : 'disabled'}',
        );
  }
}

class RecurringExpenseRemindersEnabledNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    return ref
        .read(tokenStorageProvider)
        .readRecurringExpenseRemindersEnabled();
  }

  Future<void> setEnabled(bool enabled) async {
    final logger = ref.read(appLoggerProvider);
    await ref
        .read(tokenStorageProvider)
        .writeRecurringExpenseRemindersEnabled(enabled);
    state = AsyncValue.data(enabled);
    logger.info('recurring_expense_reminders_enabled_set value=$enabled');
    await ref
        .read(activityLogServiceProvider)
        .add(action: 'Recurring reminders ${enabled ? 'enabled' : 'disabled'}');
  }
}

class AuthNotifier extends AsyncNotifier<AuthSession?> {
  AuthSession _sessionFromFirebaseUser(User user) {
    return AuthSession(
      user: AuthUser(
        id: user.uid,
        email: user.email ?? 'unknown@vaultspend.local',
        preferredCurrency: 'USD',
      ),
    );
  }

  @override
  Future<AuthSession?> build() async {
    final logger = ref.read(appLoggerProvider);
    if (!isFirebaseReady) {
      logger.warning('auth_restore_skipped_firebase_not_ready');
      return null;
    }

    final firebaseAuth = ref.read(firebaseAuthProvider);
    final user = firebaseAuth.currentUser;
    if (user == null) {
      logger.fine('auth_restore_skipped_no_token');
      return null;
    }

    try {
      await user.reload();
      final refreshedUser = firebaseAuth.currentUser ?? user;
      logger.info('auth_restored');
      return _sessionFromFirebaseUser(refreshedUser);
    } on FirebaseAuthException catch (error, stack) {
      logger.warning('auth_restore_failed_firebase', error, stack);
      await firebaseAuth.signOut();
      return null;
    } catch (error, stack) {
      logger.warning('auth_restore_failed_unexpected', error, stack);
      await firebaseAuth.signOut();
      return null;
    }
  }

  Future<void> signIn(String email, String password) async {
    final logger = ref.read(appLoggerProvider);
    logger.info('sign_in_started');
    state = const AsyncValue.loading();
    try {
      if (!isFirebaseReady) {
        throw StateError(
          'Firebase is not initialized. Check Firebase app configuration.',
        );
      }
      final firebaseAuth = ref.read(firebaseAuthProvider);
      final storage = ref.read(tokenStorageProvider);
      final cred = await firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = cred.user;
      if (user == null) {
        throw StateError('Firebase sign-in did not return a user.');
      }
      await storage.clearGuestMode();
      ref.invalidate(guestModeControllerProvider);
      state = AsyncValue.data(_sessionFromFirebaseUser(user));
      logger.info('sign_in_succeeded');
      await ref
          .read(activityLogServiceProvider)
          .add(action: 'Signed in', details: user.email ?? email);
    } catch (error, stack) {
      logger.warning('sign_in_failed', error, stack);
      state = AsyncValue.error(error, stack);
      await ref
          .read(activityLogServiceProvider)
          .add(action: 'Sign-in failed', details: error.toString());
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    String preferredCurrency = 'USD',
  }) async {
    final logger = ref.read(appLoggerProvider);
    logger.info('sign_up_started');
    state = const AsyncValue.loading();
    try {
      if (!isFirebaseReady) {
        throw StateError(
          'Firebase is not initialized. Check Firebase app configuration.',
        );
      }
      final firebaseAuth = ref.read(firebaseAuthProvider);
      final storage = ref.read(tokenStorageProvider);
      final cred = await firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = cred.user;
      if (user == null) {
        throw StateError('Firebase sign-up did not return a user.');
      }
      await storage.clearGuestMode();
      ref.invalidate(guestModeControllerProvider);
      state = AsyncValue.data(
        AuthSession(
          user: AuthUser(
            id: user.uid,
            email: user.email ?? 'unknown@vaultspend.local',
            preferredCurrency: preferredCurrency,
          ),
        ),
      );
      logger.info('sign_up_succeeded');
      await ref
          .read(activityLogServiceProvider)
          .add(action: 'Account created', details: user.email ?? email);
    } catch (error, stack) {
      logger.warning('sign_up_failed', error, stack);
      state = AsyncValue.error(error, stack);
      await ref
          .read(activityLogServiceProvider)
          .add(action: 'Sign-up failed', details: error.toString());
    }
  }

  Future<void> signOut() async {
    final logger = ref.read(appLoggerProvider);
    final storage = ref.read(tokenStorageProvider);
    final session = state.value;
    await ref.read(firebaseAuthProvider).signOut();
    await storage.clearGuestMode();
    state = const AsyncValue.data(null);
    ref.invalidate(guestModeControllerProvider);
    logger.info('sign_out_completed');
    await ref
        .read(activityLogServiceProvider)
        .add(action: 'Signed out', details: session?.user.email);
  }
}
