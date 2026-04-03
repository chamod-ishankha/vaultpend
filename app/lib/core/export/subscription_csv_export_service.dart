import 'package:csv/csv.dart';

import '../../data/models/subscription.dart';

class SubscriptionCsvExportService {
  const SubscriptionCsvExportService();

  String buildCsv({required List<Subscription> subscriptions}) {
    final rows = <List<Object?>>[
      const [
        'id',
        'name',
        'currency',
        'amount',
        'cycle',
        'next_billing_date',
        'is_trial',
        'trial_ends_at',
        'remote_id',
      ],
      ...subscriptions.map(
        (subscription) => [
          subscription.id,
          subscription.name,
          subscription.currency,
          subscription.amount.toStringAsFixed(2),
          subscription.cycle,
          subscription.nextBillingDate.toIso8601String(),
          subscription.isTrial ? 'yes' : 'no',
          subscription.trialEndsAt?.toIso8601String() ?? '',
          subscription.remoteId ?? '',
        ],
      ),
    ];

    return const ListToCsvConverter(eol: '\n').convert(rows);
  }
}
