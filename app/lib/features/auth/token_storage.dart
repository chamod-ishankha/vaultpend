import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kGuestMode = 'vaultspend_guest_mode';
const _kRemindersEnabled = 'vaultspend_reminders_enabled';
const _kSubscriptionRemindersEnabled =
    'vaultspend_subscription_reminders_enabled';
const _kRecurringExpenseRemindersEnabled =
    'vaultspend_recurring_expense_reminders_enabled';
const _kInsightsReportView = 'vaultspend_insights_report_view';
const _kPreferredCurrency = 'vaultspend_preferred_currency';

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

  Future<String> readInsightsReportView() async {
    final value = await _s.read(key: _kInsightsReportView);
    return value == null || value.trim().isEmpty ? 'overview' : value;
  }

  Future<void> writeInsightsReportView(String value) => _s.write(
    key: _kInsightsReportView,
    value: value.trim().isEmpty ? 'overview' : value.trim(),
  );

  Future<String> readPreferredCurrency() async {
    final value = await _s.read(key: _kPreferredCurrency);
    final code = value?.trim().toUpperCase();
    if (code == 'LKR' || code == 'USD' || code == 'EUR') {
      return code!;
    }
    return 'USD';
  }

  Future<void> writePreferredCurrency(String value) =>
      _s.write(key: _kPreferredCurrency, value: value.trim().toUpperCase());
}
