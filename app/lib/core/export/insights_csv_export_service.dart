import 'package:csv/csv.dart';

import '../../data/models/expense.dart';
import '../../data/models/subscription.dart';

class InsightsCsvExportService {
  const InsightsCsvExportService();

  String buildCsv({
    required String rangeTitle,
    required List<Expense> expenses,
    required List<Subscription> subscriptions,
    required Map<int, String> categoryNames,
  }) {
    final expenseCurrencyEntries = _sortedEntries(_sumByCurrency(expenses));
    final categoryEntries = _sortedEntries(
      _categorySpend(expenses, categoryNames),
    );
    final subscriptionCurrencyEntries = _sortedEntries(
      _subscriptionCurrencyTotals(subscriptions),
    );
    final cycleEntries = _sortedCycleEntries(_cycleSummary(subscriptions));
    final recurringExpenseEntries = _sortedEntries(
      _sumByCurrency(expenses.where((expense) => expense.isRecurring)),
    );
    final upcomingBillings = _upcomingBillings(subscriptions);
    final upcomingCurrencyEntries = _sortedEntries(
      _subscriptionCurrencyTotals(upcomingBillings),
    );

    final rows = <List<Object?>>[];

    void addSection(String title) {
      rows.add([title]);
    }

    void addHeader(List<String> header) {
      rows.add(header);
    }

    addSection('Insights Report');
    addHeader(['metric', 'value']);
    rows.add(['range', rangeTitle]);
    rows.add(['expenses', expenses.length]);
    rows.add(['subscriptions', subscriptions.length]);
    rows.add([
      'recurring_expenses',
      expenses.where((e) => e.isRecurring).length,
    ]);
    rows.add(['upcoming_billings_30d', upcomingBillings.length]);
    rows.add([
      'upcoming_trial_billings_30d',
      upcomingBillings.where((s) => s.isTrial).length,
    ]);

    addSection('Expense Currency Split');
    addHeader(['currency', 'amount']);
    rows.addAll(
      expenseCurrencyEntries.map(
        (entry) => [entry.key, entry.value.toStringAsFixed(2)],
      ),
    );

    addSection('Category Distribution');
    addHeader(['category', 'amount']);
    rows.addAll(
      categoryEntries.map(
        (entry) => [entry.key, entry.value.toStringAsFixed(2)],
      ),
    );

    addSection('Subscription Currency Split');
    addHeader(['currency', 'amount']);
    rows.addAll(
      subscriptionCurrencyEntries.map(
        (entry) => [entry.key, entry.value.toStringAsFixed(2)],
      ),
    );

    addSection('Subscription Cycle Mix');
    addHeader(['cycle', 'items', 'est_monthly_burn']);
    rows.addAll(
      cycleEntries.map((entry) {
        final summary = entry.value;
        return [
          entry.key,
          summary.count,
          summary.monthlyBurn.toStringAsFixed(2),
        ];
      }),
    );

    addSection('Recurring Expense Currency Split');
    addHeader(['currency', 'amount']);
    rows.addAll(
      recurringExpenseEntries.map(
        (entry) => [entry.key, entry.value.toStringAsFixed(2)],
      ),
    );

    addSection('Upcoming Billing Currency Split');
    addHeader(['currency', 'amount']);
    rows.addAll(
      upcomingCurrencyEntries.map(
        (entry) => [entry.key, entry.value.toStringAsFixed(2)],
      ),
    );

    addSection('Upcoming Billings');
    addHeader(['name', 'currency', 'amount', 'cycle', 'next_billing', 'trial']);
    rows.addAll(
      upcomingBillings.map(
        (subscription) => [
          subscription.name,
          subscription.currency,
          subscription.amount.toStringAsFixed(2),
          subscription.cycle,
          subscription.nextBillingDate.toIso8601String(),
          subscription.isTrial ? 'yes' : 'no',
        ],
      ),
    );

    addSection('Largest Subscriptions');
    addHeader(['name', 'currency', 'amount', 'cycle', 'next_billing', 'trial']);
    final largestSubscriptions = [...subscriptions]
      ..sort((a, b) => b.amount.compareTo(a.amount));
    rows.addAll(
      largestSubscriptions
          .take(10)
          .map(
            (subscription) => [
              subscription.name,
              subscription.currency,
              subscription.amount.toStringAsFixed(2),
              subscription.cycle,
              subscription.nextBillingDate.toIso8601String(),
              subscription.isTrial ? 'yes' : 'no',
            ],
          ),
    );

    addSection('Recent Expenses');
    addHeader(['date', 'category', 'currency', 'amount', 'recurring', 'note']);
    final recentExpenses = [...expenses]
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    rows.addAll(
      recentExpenses.take(20).map((expense) {
        final category = expense.categoryId == null
            ? 'Uncategorized'
            : categoryNames[expense.categoryId!] ?? 'Unknown';
        return [
          expense.occurredAt.toIso8601String(),
          category,
          expense.currency,
          expense.amount.toStringAsFixed(2),
          expense.isRecurring ? 'yes' : 'no',
          expense.note ?? '',
        ];
      }),
    );

    return const ListToCsvConverter(eol: '\n').convert(rows);
  }

  Map<String, double> _sumByCurrency(Iterable<Expense> expenses) {
    final totals = <String, double>{};
    for (final expense in expenses) {
      totals.update(
        expense.currency,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }
    return totals;
  }

  Map<String, double> _categorySpend(
    Iterable<Expense> expenses,
    Map<int, String> categoryNames,
  ) {
    final totals = <String, double>{};
    for (final expense in expenses) {
      final name = expense.categoryId == null
          ? 'Uncategorized'
          : categoryNames[expense.categoryId!] ?? 'Unknown';
      totals.update(
        name,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }
    return totals;
  }

  Map<String, double> _subscriptionCurrencyTotals(
    Iterable<Subscription> subscriptions,
  ) {
    final totals = <String, double>{};
    for (final subscription in subscriptions) {
      totals.update(
        subscription.currency,
        (value) => value + subscription.amount,
        ifAbsent: () => subscription.amount,
      );
    }
    return totals;
  }

  Map<String, _CycleSummary> _cycleSummary(List<Subscription> subscriptions) {
    final summary = <String, _CycleSummary>{};
    for (final subscription in subscriptions) {
      final bucket = _cycleBucket(subscription.cycle);
      final monthly = _estimateMonthlyAmount(
        subscription.amount,
        subscription.cycle,
      );
      summary.update(
        bucket,
        (current) => current.copyWith(
          count: current.count + 1,
          monthlyBurn: current.monthlyBurn + monthly,
        ),
        ifAbsent: () => _CycleSummary(count: 1, monthlyBurn: monthly),
      );
    }
    return summary;
  }

  List<Subscription> _upcomingBillings(List<Subscription> subscriptions) {
    final now = DateTime.now();
    final end = now.add(const Duration(days: 30));
    final upcoming = subscriptions.where((subscription) {
      final billing = subscription.nextBillingDate;
      return !billing.isBefore(now) && !billing.isAfter(end);
    }).toList();
    upcoming.sort((a, b) => a.nextBillingDate.compareTo(b.nextBillingDate));
    return upcoming;
  }

  String _cycleBucket(String cycle) {
    final lower = cycle.toLowerCase();
    if (lower.contains('annual') || lower.contains('yearly')) {
      return 'Annual';
    }
    if (lower.contains('month')) {
      return 'Monthly';
    }
    if (lower.contains('week') &&
        (lower.contains('bi-') || lower.contains('biweek'))) {
      return 'Bi-weekly';
    }
    if (lower.contains('week')) {
      return 'Weekly';
    }
    if (lower.contains('day')) {
      return 'Daily';
    }
    return cycle.isEmpty ? 'Other' : cycle;
  }

  double _estimateMonthlyAmount(double amount, String cycle) {
    final lower = cycle.toLowerCase();
    if (lower.contains('annual') || lower.contains('yearly')) {
      return amount / 12;
    }
    if (lower.contains('month')) {
      return amount;
    }
    if (lower.contains('week')) {
      return amount * 4.33;
    }
    if (lower.contains('day')) {
      return amount * 30;
    }
    if (lower.contains('bi-week') || lower.contains('biweek')) {
      return amount * 2.17;
    }
    return amount;
  }

  List<MapEntry<String, double>> _sortedEntries(Map<String, double> totals) {
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  List<MapEntry<String, _CycleSummary>> _sortedCycleEntries(
    Map<String, _CycleSummary> totals,
  ) {
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.monthlyBurn.compareTo(a.value.monthlyBurn));
    return entries;
  }
}

class _CycleSummary {
  const _CycleSummary({required this.count, required this.monthlyBurn});

  final int count;
  final double monthlyBurn;

  _CycleSummary copyWith({int? count, double? monthlyBurn}) {
    return _CycleSummary(
      count: count ?? this.count,
      monthlyBurn: monthlyBurn ?? this.monthlyBurn,
    );
  }
}
