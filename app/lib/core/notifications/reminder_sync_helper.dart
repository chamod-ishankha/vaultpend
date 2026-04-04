import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_providers.dart';
import '../logging/app_logging.dart';
import '../providers.dart';

Future<void> syncRemindersNow(
  WidgetRef ref, {
  required String reason,
}) async {
  final logger = ref.read(appLoggerProvider);
  final uid = ref.read(currentUserIdProvider);
  if (uid == null) {
    logger.info('reminder_manual_sync_skipped_no_user reason=$reason');
    return;
  }

  final service = ref.read(reminderServiceProvider);
  final remindersEnabled = ref.read(remindersEnabledProvider);
  final subscriptionsEnabled = ref.read(subscriptionRemindersEnabledProvider);
  final recurringEnabled = ref.read(recurringExpenseRemindersEnabledProvider);

  if (!remindersEnabled) {
    await service.cancelManagedReminders();
    logger.info('reminder_manual_sync_cancelled_master_off reason=$reason');
    return;
  }

  try {
    logger.info(
      'reminder_manual_sync_started '
      'reason=$reason '
      'subscriptionsEnabled=$subscriptionsEnabled '
      'recurringEnabled=$recurringEnabled',
    );

    final subscriptions = await ref.read(subscriptionRepositoryProvider).getAll();
    final expenses = await ref.read(expenseRepositoryProvider).getAll();

    await service.syncGlobalReminders(
      subscriptions: subscriptions,
      expenses: expenses,
      includeSubscriptions: subscriptionsEnabled,
      includeRecurringExpenses: recurringEnabled,
    );

    logger.info(
      'reminder_manual_sync_completed '
      'reason=$reason '
      'subscriptions=${subscriptions.length} '
      'expenses=${expenses.length}',
    );
  } catch (error, stack) {
    logger.warning('reminder_manual_sync_failed reason=$reason', error, stack);
  }
}
