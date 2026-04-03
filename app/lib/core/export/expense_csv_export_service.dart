import 'package:csv/csv.dart';

import '../../data/models/expense.dart';

class ExpenseCsvExportService {
  const ExpenseCsvExportService();

  String buildCsv({
    required List<Expense> expenses,
    required Map<int, String> categoryNames,
  }) {
    final rows = <List<Object?>>[
      const [
        'id',
        'occurred_at',
        'currency',
        'amount',
        'category',
        'recurring',
        'note',
        'remote_id',
      ],
      ...expenses.map((expense) {
        final category = expense.categoryId == null
            ? 'Uncategorized'
            : categoryNames[expense.categoryId!] ?? 'Unknown';
        return [
          expense.id,
          expense.occurredAt.toIso8601String(),
          expense.currency,
          expense.amount.toStringAsFixed(2),
          category,
          expense.isRecurring ? 'yes' : 'no',
          expense.note ?? '',
          expense.remoteId ?? '',
        ];
      }),
    ];

    return const ListToCsvConverter(eol: '\n').convert(rows);
  }
}
