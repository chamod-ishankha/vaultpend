import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kGuestMode = 'vaultspend_guest_mode';
const _kRemindersEnabled = 'vaultspend_reminders_enabled';
const _kSubscriptionRemindersEnabled =
    'vaultspend_subscription_reminders_enabled';
const _kRecurringExpenseRemindersEnabled =
    'vaultspend_recurring_expense_reminders_enabled';

class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
    : _s =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  final FlutterSecureStorage _s;

  Future<bool> readGuestMode() async {
    final value = await _s.read(key: _kGuestMode);
    return value == 'true';
  }

  Future<void> writeGuestMode(bool enabled) =>
      _s.write(key: _kGuestMode, value: enabled ? 'true' : 'false');

  Future<void> clearGuestMode() => _s.delete(key: _kGuestMode);

  Future<bool> readRemindersEnabled() async {
    final value = await _s.read(key: _kRemindersEnabled);
    if (value == null) {
      return true;
    }
    return value == 'true';
  }

  Future<void> writeRemindersEnabled(bool enabled) =>
      _s.write(key: _kRemindersEnabled, value: enabled ? 'true' : 'false');

  Future<bool> readSubscriptionRemindersEnabled() async {
    final value = await _s.read(key: _kSubscriptionRemindersEnabled);
    if (value == null) {
      return true;
    }
    return value == 'true';
  }

  Future<void> writeSubscriptionRemindersEnabled(bool enabled) => _s.write(
    key: _kSubscriptionRemindersEnabled,
    value: enabled ? 'true' : 'false',
  );

  Future<bool> readRecurringExpenseRemindersEnabled() async {
    final value = await _s.read(key: _kRecurringExpenseRemindersEnabled);
    if (value == null) {
      return true;
    }
    return value == 'true';
  }

  Future<void> writeRecurringExpenseRemindersEnabled(bool enabled) => _s.write(
    key: _kRecurringExpenseRemindersEnabled,
    value: enabled ? 'true' : 'false',
  );
}
