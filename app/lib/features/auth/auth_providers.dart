import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaultspend/core/firebase/firebase_bootstrap.dart';
import 'package:vaultspend/core/logging/app_logging.dart';
import 'package:vaultspend/core/network/network_guard.dart';

import 'auth_session.dart';
import 'sync_status.dart';
import 'token_storage.dart';

const _supportedCurrencies = <String>{'USD', 'EUR', 'LKR'};

String _normalizeCurrencyCode(String value) {
  final code = value.trim().toUpperCase();
  return _supportedCurrencies.contains(code) ? code : 'USD';
}

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
final preferredCurrencyControllerProvider =
    AsyncNotifierProvider<PreferredCurrencyNotifier, String>(
      PreferredCurrencyNotifier.new,
    );

const guestLocalUserId = 'guest-local';

final isGuestModeProvider = Provider<bool>((ref) {
  return ref
      .watch(guestModeControllerProvider)
      .maybeWhen(data: (value) => value, orElse: () => false);
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

final preferredCurrencyProvider = Provider<String>((ref) {
  final fromController = ref.watch(preferredCurrencyControllerProvider).value;
  if (fromController != null) {
    return fromController;
  }
  final fromSession = ref
      .watch(authControllerProvider)
      .value
      ?.user
      .preferredCurrency;
  final code = fromSession?.trim().toUpperCase();
  if (code != null && _supportedCurrencies.contains(code)) {
    return code;
  }
  return 'USD';
});

/// Server-side user id (JWT `sub` / profile `id`). Local Isar data is scoped by this.
final currentUserIdProvider = Provider<String?>((ref) {
  final authUserId = ref
      .watch(authControllerProvider)
      .maybeWhen(data: (session) => session?.user.id, orElse: () => null);
  if (authUserId != null) return authUserId;
  if (ref.watch(isGuestModeProvider)) return guestLocalUserId;
  return null;
});

final syncStatusProvider = FutureProvider.autoDispose<SyncStatus>((ref) async {
  if (ref.watch(isGuestModeProvider)) {
    throw StateError('sync is unavailable in guest mode');
  }
  final session = ref
      .watch(authControllerProvider)
      .maybeWhen(data: (value) => value, orElse: () => null);
  if (session == null) {
    throw StateError('syncStatusProvider requires signed-in session');
  }

  if (!await hasNetworkConnection()) {
    throw StateError('syncStatusProvider offline');
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
        .get()
        .timeout(const Duration(seconds: 4));

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

class PreferredCurrencyNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    return ref.read(tokenStorageProvider).readPreferredCurrency();
  }

  Future<void> refreshFromSession(AuthSession? session) async {
    if (session == null) {
      return;
    }
    final currency = _normalizeCurrencyCode(session.user.preferredCurrency);
    await ref.read(tokenStorageProvider).writePreferredCurrency(currency);
    state = AsyncValue.data(currency);
  }

  Future<void> setPreferredCurrency(String currency) async {
    final logger = ref.read(appLoggerProvider);
    final normalized = _normalizeCurrencyCode(currency);
    await ref.read(tokenStorageProvider).writePreferredCurrency(normalized);

    final authSession = ref.read(authControllerProvider).value;
    if (authSession != null) {
      ref
          .read(authControllerProvider.notifier)
          .updatePreferredCurrencyLocal(normalized);
      try {
        await ref
            .read(authControllerProvider.notifier)
            .persistPreferredCurrency(normalized);
      } catch (error, stack) {
        logger.warning('preferred_currency_cloud_save_failed', error, stack);
      }
      await ref
          .read(activityLogServiceProvider)
          .add(action: 'Preferred currency updated', details: normalized);
    }
    state = AsyncValue.data(normalized);
  }
}

class AuthNotifier extends AsyncNotifier<AuthSession?> {
  static const _terminalRestoreErrorCodes = <String>{
    'invalid-user-token',
    'user-token-expired',
    'user-disabled',
    'user-not-found',
  };

  AuthSession _sessionFromFirebaseUser(
    User user, {
    String preferredCurrency = 'USD',
    String? photoBase64,
  }) {
    final displayName = _normalizeDisplayName(
      user.displayName,
      fallbackEmail: user.email,
    );
    return AuthSession(
      user: AuthUser(
        id: user.uid,
        email: user.email ?? 'unknown@vaultspend.local',
        preferredCurrency: _normalizeCurrency(preferredCurrency),
        displayName: displayName,
        photoBase64: photoBase64,
      ),
    );
  }

  String _normalizeCurrency(String value) {
    return _normalizeCurrencyCode(value);
  }

  String _normalizeDisplayName(String? value, {String? fallbackEmail}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
    final email = fallbackEmail?.trim() ?? '';
    if (email.contains('@')) {
      return email.split('@').first;
    }
    return 'VaultSpend User';
  }

  Future<(String, String?)> _readProfileSettings(User user) async {
    final storage = ref.read(tokenStorageProvider);
    final localCurrency = _normalizeCurrency(await storage.readPreferredCurrency());
    // Note: We don't cache photoBase64 locally in TokenStorage to save space, relies on Firestore.

    if (!isFirebaseReady || !await hasNetworkConnection()) {
      return (localCurrency, null);
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('profile')
          .get()
          .timeout(const Duration(seconds: 4));
      
      final remoteCurrency = _normalizeCurrency(
        (doc.data()?['preferred_currency'] as String?) ?? localCurrency,
      );
      final photoBase64 = doc.data()?['photo_base64'] as String?;
      
      await storage.writePreferredCurrency(remoteCurrency);
      return (remoteCurrency, photoBase64);
    } catch (_) {
      return (localCurrency, null);
    }
  }

  Future<void> _persistPreferredCurrencyForUid(
    String uid,
    String currency,
  ) async {
    if (!isFirebaseReady || !await hasNetworkConnection()) {
      return;
    }
    final normalized = _normalizeCurrency(currency);
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('profile')
        .set({
          'preferred_currency': normalized,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true))
        .timeout(const Duration(seconds: 4));
  }

  Future<void> persistPreferredCurrency(String currency) async {
    final session = state.value;
    if (session == null) {
      return;
    }
    await _persistPreferredCurrencyForUid(session.user.id, currency);
    await ref
        .read(tokenStorageProvider)
        .writePreferredCurrency(_normalizeCurrency(currency));
  }

  void updatePreferredCurrencyLocal(String currency) {
    final session = state.value;
    if (session == null) {
      return;
    }
    final normalized = _normalizeCurrency(currency);
    state = AsyncValue.data(
      AuthSession(
        user: AuthUser(
          id: session.user.id,
          email: session.user.email,
          preferredCurrency: normalized,
          displayName: session.user.displayName,
          photoBase64: session.user.photoBase64,
        ),
      ),
    );
  }

  Future<void> updateProfileBase64(String? base64String) async {
    final logger = ref.read(appLoggerProvider);
    final session = state.value;
    if (session == null) {
      throw StateError('Requires a signed-in session');
    }

    if (!isFirebaseReady || !await hasNetworkConnection()) {
      throw StateError('Needs network connection to update avatar.');
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(session.user.id)
          .collection('settings')
          .doc('profile')
          .set({
            'photo_base64': base64String,
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 4));

      state = AsyncValue.data(
        AuthSession(
          user: AuthUser(
            id: session.user.id,
            email: session.user.email,
            preferredCurrency: session.user.preferredCurrency,
            displayName: session.user.displayName,
            photoBase64: base64String,
          ),
        ),
      );
      
      logger.info('profile_base64_avatar_updated');
    } catch (error, stack) {
      logger.warning('profile_base64_avatar_update_failed', error, stack);
      rethrow;
    }
  }

  @override
  Future<AuthSession?> build() async {
    final logger = ref.read(appLoggerProvider);
    if (!isFirebaseReady) {
      logger.warning('auth_restore_skipped_firebase_not_ready');
      return null;
    }

    final firebaseAuth = ref.read(firebaseAuthProvider);
    final storage = ref.read(tokenStorageProvider);
    final user = firebaseAuth.currentUser;
    if (user == null) {
      logger.fine('auth_restore_skipped_no_token');
      return null;
    }

    // Keep local-first behavior across app restarts: if offline, keep cached user.
    if (!await hasNetworkConnection()) {
      logger.info('auth_restore_offline_cached_session');
      final preferredCurrency = await storage.readPreferredCurrency();
      return _sessionFromFirebaseUser(
        user,
        preferredCurrency: preferredCurrency,
      );
    }

    try {
      await user.reload().timeout(const Duration(seconds: 4));
      final refreshedUser = firebaseAuth.currentUser ?? user;
      final (preferredCurrency, photoBase64) = await _readProfileSettings(refreshedUser);
      logger.info('auth_restored');
      return _sessionFromFirebaseUser(
        refreshedUser,
        preferredCurrency: preferredCurrency,
        photoBase64: photoBase64,
      );
    } on TimeoutException catch (error, stack) {
      logger.warning('auth_restore_timeout_using_cached_session', error, stack);
      final preferredCurrency = await storage.readPreferredCurrency();
      return _sessionFromFirebaseUser(
        firebaseAuth.currentUser ?? user,
        preferredCurrency: preferredCurrency,
      );
    } on FirebaseAuthException catch (error, stack) {
      if (_terminalRestoreErrorCodes.contains(error.code)) {
        logger.warning(
          'auth_restore_failed_terminal_signing_out',
          error,
          stack,
        );
        await firebaseAuth.signOut();
        return null;
      }
      logger.warning(
        'auth_restore_failed_firebase_using_cached_session',
        error,
        stack,
      );
      final preferredCurrency = await storage.readPreferredCurrency();
      return _sessionFromFirebaseUser(
        firebaseAuth.currentUser ?? user,
        preferredCurrency: preferredCurrency,
      );
    } catch (error, stack) {
      logger.warning(
        'auth_restore_failed_unexpected_using_cached_session',
        error,
        stack,
      );
      final preferredCurrency = await storage.readPreferredCurrency();
      return _sessionFromFirebaseUser(
        firebaseAuth.currentUser ?? user,
        preferredCurrency: preferredCurrency,
      );
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
      final (preferredCurrency, photoBase64) = await _readProfileSettings(user);
      await storage.writePreferredCurrency(preferredCurrency);
      await storage.clearGuestMode();
      ref.invalidate(guestModeControllerProvider);
      state = AsyncValue.data(
        _sessionFromFirebaseUser(
            user, 
            preferredCurrency: preferredCurrency,
            photoBase64: photoBase64,
        ),
      );
      await ref
          .read(preferredCurrencyControllerProvider.notifier)
          .refreshFromSession(state.value);
      logger.info('sign_in_succeeded');
      await ref.read(activityLogServiceProvider).syncPendingToDatabase();
      await ref.read(syncIncidentServiceProvider).syncPendingToDatabase();
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
      final normalizedCurrency = _normalizeCurrency(preferredCurrency);
      await _persistPreferredCurrencyForUid(user.uid, normalizedCurrency);
      await storage.writePreferredCurrency(normalizedCurrency);
      await storage.clearGuestMode();
      ref.invalidate(guestModeControllerProvider);
      state = AsyncValue.data(
        AuthSession(
          user: AuthUser(
            id: user.uid,
            email: user.email ?? 'unknown@vaultspend.local',
            preferredCurrency: normalizedCurrency,
            displayName: _normalizeDisplayName(
              user.displayName,
              fallbackEmail: user.email ?? email,
            ),
          ),
        ),
      );
      await ref
          .read(preferredCurrencyControllerProvider.notifier)
          .refreshFromSession(state.value);
      logger.info('sign_up_succeeded');
      await ref.read(activityLogServiceProvider).syncPendingToDatabase();
      await ref.read(syncIncidentServiceProvider).syncPendingToDatabase();
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

  Future<void> updateEmail(String email) async {
    final logger = ref.read(appLoggerProvider);
    final session = state.value;
    if (session == null) {
      throw StateError('updateEmail requires a signed-in session');
    }

    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty) {
      throw ArgumentError.value(email, 'email', 'Email cannot be empty');
    }
    if (normalizedEmail == session.user.email) {
      return;
    }

    final firebaseUser = ref.read(firebaseAuthProvider).currentUser;
    if (firebaseUser == null) {
      throw StateError('updateEmail requires an authenticated Firebase user');
    }

    try {
      await firebaseUser
          .verifyBeforeUpdateEmail(normalizedEmail)
          .timeout(const Duration(seconds: 4));
      logger.info('profile_email_verification_sent');
      await ref
          .read(activityLogServiceProvider)
          .add(
            action: 'Profile email verification sent',
            details: normalizedEmail,
          );
      await firebaseUser.reload().timeout(const Duration(seconds: 4));
      state = AsyncValue.data(
        AuthSession(
          user: AuthUser(
            id: session.user.id,
            email: session.user.email,
            preferredCurrency: session.user.preferredCurrency,
            displayName: session.user.displayName,
            photoBase64: session.user.photoBase64,
          ),
        ),
      );
    } catch (error, stack) {
      logger.warning('profile_email_update_failed', error, stack);
      rethrow;
    }
  }

  Future<void> updateDisplayName(String displayName) async {
    final logger = ref.read(appLoggerProvider);
    final session = state.value;
    if (session == null) {
      throw StateError('updateDisplayName requires a signed-in session');
    }

    final normalized = _normalizeDisplayName(
      displayName,
      fallbackEmail: session.user.email,
    );
    if (normalized == session.user.displayName) {
      return;
    }

    final firebaseUser = ref.read(firebaseAuthProvider).currentUser;
    if (firebaseUser == null) {
      throw StateError(
        'updateDisplayName requires an authenticated Firebase user',
      );
    }

    try {
      await firebaseUser
          .updateDisplayName(normalized)
          .timeout(const Duration(seconds: 4));
      await firebaseUser.reload().timeout(const Duration(seconds: 4));
      state = AsyncValue.data(
        AuthSession(
          user: AuthUser(
            id: session.user.id,
            email: session.user.email,
            preferredCurrency: session.user.preferredCurrency,
            displayName: normalized,
            photoBase64: session.user.photoBase64,
          ),
        ),
      );
      logger.info('profile_display_name_updated');
      await ref
          .read(activityLogServiceProvider)
          .add(action: 'Profile display name updated', details: normalized);
    } catch (error, stack) {
      logger.warning('profile_display_name_update_failed', error, stack);
      rethrow;
    }
  }

  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final logger = ref.read(appLoggerProvider);
    final session = state.value;
    if (session == null) {
      throw StateError('updatePassword requires a signed-in session');
    }

    final current = currentPassword.trim();
    final next = newPassword;
    if (current.isEmpty) {
      throw ArgumentError.value(
        currentPassword,
        'currentPassword',
        'Current password is required',
      );
    }
    if (next.length < 8) {
      throw ArgumentError.value(
        newPassword,
        'newPassword',
        'Password must be at least 8 characters',
      );
    }

    final firebaseUser = ref.read(firebaseAuthProvider).currentUser;
    if (firebaseUser == null) {
      throw StateError(
        'updatePassword requires an authenticated Firebase user',
      );
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: session.user.email,
        password: current,
      );
      await firebaseUser
          .reauthenticateWithCredential(credential)
          .timeout(const Duration(seconds: 6));
      await firebaseUser
          .updatePassword(next)
          .timeout(const Duration(seconds: 4));
      logger.info('profile_password_updated');
      await ref
          .read(activityLogServiceProvider)
          .add(action: 'Profile password updated');
    } catch (error, stack) {
      logger.warning('profile_password_update_failed', error, stack);
      rethrow;
    }
  }
}
