import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../data/models/expense.dart';
import '../../data/models/subscription.dart';

class InsightsPdfExportService {
  const InsightsPdfExportService();

  Future<pw.Document> buildPdf({
    required String rangeTitle,
    required List<Expense> expenses,
    required List<Subscription> subscriptions,
    required Map<int, String> categoryNames,
  }) async {
    final doc = pw.Document();
    final themePrimary = PdfColor.fromInt(0xFF0F766E);
    final currencyFmt = NumberFormat.currency(symbol: '');
    final timestamp = DateFormat('MMM d, yyyy h:mm a').format(DateTime.now());

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
    final largestSubscriptions = [...subscriptions]
      ..sort((a, b) => b.amount.compareTo(a.amount));
    final recentExpenses = [...expenses]
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    final totalExpenseAmount = expenses.fold<double>(
      0,
      (sum, expense) => sum + expense.amount,
    );
    final totalMonthlyBurn = subscriptions.fold<double>(
      0,
      (sum, subscription) =>
          sum + _estimateMonthlyAmount(subscription.amount, subscription.cycle),
    );

    final logoBytes = await rootBundle.load('assets/branding/logo.png');
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(16),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: pw.BoxDecoration(color: themePrimary),
              child: pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Container(
                  height: 120,
                  width: 180,
                  child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                ),
              ),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Generated: $timestamp',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.Text(
            'Range: $rangeTitle',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.Divider(),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _summaryTile('Expenses', '${expenses.length}'),
              _summaryTile('Subscriptions', '${subscriptions.length}'),
              _summaryTile(
                'Total Spend',
                currencyFmt.format(totalExpenseAmount).trim(),
              ),
              _summaryTile(
                'Monthly Burn',
                currencyFmt.format(totalMonthlyBurn).trim(),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          ..._sectionTable(
            title: 'Expense Currency Split',
            headers: const ['Currency', 'Amount'],
            rows: expenseCurrencyEntries
                .map(
                  (entry) => [
                    entry.key,
                    currencyFmt.format(entry.value).trim(),
                  ],
                )
                .toList(),
          ),
          ..._sectionTable(
            title: 'Category Distribution',
            headers: const ['Category', 'Amount'],
            rows: categoryEntries
                .map(
                  (entry) => [
                    entry.key,
                    currencyFmt.format(entry.value).trim(),
                  ],
                )
                .toList(),
          ),
          ..._sectionTable(
            title: 'Subscription Currency Split',
            headers: const ['Currency', 'Amount'],
            rows: subscriptionCurrencyEntries
                .map(
                  (entry) => [
                    entry.key,
                    currencyFmt.format(entry.value).trim(),
                  ],
                )
                .toList(),
          ),
          ..._sectionTable(
            title: 'Subscription Cycle Mix',
            headers: const ['Cycle', 'Items', 'Est. Monthly Burn'],
            rows: cycleEntries
                .map(
                  (entry) => [
                    entry.key,
                    entry.value.count.toString(),
                    currencyFmt.format(entry.value.monthlyBurn).trim(),
                  ],
                )
                .toList(),
          ),
          ..._sectionTable(
            title: 'Recurring Expense Currency Split',
            headers: const ['Currency', 'Amount'],
            rows: recurringExpenseEntries
                .map(
                  (entry) => [
                    entry.key,
                    currencyFmt.format(entry.value).trim(),
                  ],
                )
                .toList(),
          ),
          ..._sectionTable(
            title: 'Upcoming Billing Currency Split',
            headers: const ['Currency', 'Amount'],
            rows: upcomingCurrencyEntries
                .map(
                  (entry) => [
                    entry.key,
                    currencyFmt.format(entry.value).trim(),
                  ],
                )
                .toList(),
          ),
          ..._sectionTable(
            title: 'Upcoming Billings',
            headers: const [
              'Name',
              'Currency',
              'Amount',
              'Cycle',
              'Next Billing',
              'Trial',
            ],
            rows: upcomingBillings
                .map(
                  (subscription) => [
                    subscription.name,
                    subscription.currency,
                    currencyFmt.format(subscription.amount).trim(),
                    subscription.cycle,
                    DateFormat(
                      'MMM d, yyyy h:mm a',
                    ).format(subscription.nextBillingDate),
                    subscription.isTrial ? 'Yes' : 'No',
                  ],
                )
                .toList(),
          ),
          ..._sectionTable(
            title: 'Largest Subscriptions',
            headers: const [
              'Name',
              'Currency',
              'Amount',
              'Cycle',
              'Next Billing',
              'Trial',
            ],
            rows: largestSubscriptions
                .take(10)
                .map(
                  (subscription) => [
                    subscription.name,
                    subscription.currency,
                    currencyFmt.format(subscription.amount).trim(),
                    subscription.cycle,
                    DateFormat(
                      'MMM d, yyyy h:mm a',
                    ).format(subscription.nextBillingDate),
                    subscription.isTrial ? 'Yes' : 'No',
                  ],
                )
                .toList(),
          ),
          ..._sectionTable(
            title: 'Recent Expenses',
            headers: const [
              'Date',
              'Category',
              'Currency',
              'Amount',
              'Recurring',
              'Note',
            ],
            rows: recentExpenses.take(20).map((expense) {
              final category = expense.categoryId == null
                  ? 'Uncategorized'
                  : categoryNames[expense.categoryId!] ?? 'Unknown';
              return [
                DateFormat('MMM d, yyyy h:mm a').format(expense.occurredAt),
                category,
                expense.currency,
                currencyFmt.format(expense.amount).trim(),
                expense.isRecurring ? 'Yes' : 'No',
                expense.note ?? '',
              ];
            }).toList(),
          ),
        ],
      ),
    );

    return doc;
  }

  pw.Widget _summaryTile(String title, String value) {
    return pw.Container(
      width: 120,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  List<pw.Widget> _sectionTable({
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    return [
      pw.SizedBox(height: 16),
      pw.Text(
        title,
        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 8),
      pw.TableHelper.fromTextArray(
        headers: headers,
        data: rows,
        headerStyle: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 9,
          color: PdfColors.white,
        ),
        headerDecoration: pw.BoxDecoration(color: PdfColors.teal700),
        rowDecoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
        ),
        cellHeight: 20,
        cellAlignment: pw.Alignment.centerLeft,
        cellPadding: const pw.EdgeInsets.all(4),
      ),
    ];
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

  List<MapEntry<String, _CycleSummary>> _sortedCycleEntries(
    Map<String, _CycleSummary> totals,
  ) {
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.monthlyBurn.compareTo(a.value.monthlyBurn));
    return entries;
  }

  List<MapEntry<String, double>> _sortedEntries(Map<String, double> totals) {
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
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
