import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/providers.dart';
import '../../core/export/insights_csv_export_service.dart';
import '../../core/export/insights_pdf_export_service.dart';
import '../../core/logging/app_logging.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../data/models/expense.dart';
import '../../data/models/subscription.dart';
import '../subscriptions/add_subscription_screen.dart';
import '../expenses/expense_providers.dart';
import '../subscriptions/subscription_providers.dart';

final insightsDataProvider = FutureProvider.autoDispose<_InsightsData>((
  ref,
) async {
  final expenses = await ref.watch(expenseListProvider.future);
  final subscriptions = await ref.watch(subscriptionListProvider.future);
  final categories = await ref.watch(categoryListProvider.future);
  return _InsightsData(
    expenses: expenses,
    subscriptions: subscriptions,
    categoryNames: {for (final c in categories) c.id: c.name},
  );
});

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key, this.onOpenDrawer});

  final VoidCallback? onOpenDrawer;
  static const _csvExportService = InsightsCsvExportService();
  static const _pdfExportService = InsightsPdfExportService();

  Future<void> _exportInsightsCsv(BuildContext context, WidgetRef ref) async {
    final logger = ref.read(appLoggerProvider);
    logger.info('insights_csv_export_started');
    try {
      final data = await ref.read(insightsDataProvider.future);
      if (data.expenses.isEmpty && data.subscriptions.isEmpty) {
        logger.info('insights_csv_export_skipped_no_data');
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No insights data to export yet.')),
        );
        return;
      }

      final csv = _csvExportService.buildCsv(
        rangeTitle: 'All Time',
        expenses: data.expenses,
        subscriptions: data.subscriptions,
        categoryNames: data.categoryNames,
      );
      final stamp = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
      final filename = 'vaultspend_insights_$stamp.csv';
      final bytes = Uint8List.fromList(utf8.encode(csv));

      await SharePlus.instance.share(
        ShareParams(
          subject: 'VaultSpend insights export',
          text: 'VaultSpend insights CSV export',
          files: [XFile.fromData(bytes, mimeType: 'text/csv', name: filename)],
        ),
      );

      logger.info('insights_csv_export_succeeded');

      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('CSV export prepared: $filename')));
    } catch (error, stack) {
      logger.warning('insights_csv_export_failed', error, stack);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('CSV export failed: $error')));
    }
  }

  Future<void> _exportInsightsPdf(BuildContext context, WidgetRef ref) async {
    final logger = ref.read(appLoggerProvider);
    logger.info('insights_pdf_export_started');
    try {
      final data = await ref.read(insightsDataProvider.future);
      if (data.expenses.isEmpty && data.subscriptions.isEmpty) {
        logger.info('insights_pdf_export_skipped_no_data');
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No insights data to export yet.')),
        );
        return;
      }

      final pdfDoc = await _pdfExportService.buildPdf(
        rangeTitle: 'All Time',
        expenses: data.expenses,
        subscriptions: data.subscriptions,
        categoryNames: data.categoryNames,
      );
      final stamp = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
      final filename = 'vaultspend_insights_$stamp.pdf';
      final bytes = await pdfDoc.save();

      await SharePlus.instance.share(
        ShareParams(
          subject: 'VaultSpend insights report',
          text: 'VaultSpend insights PDF report',
          files: [
            XFile.fromData(bytes, mimeType: 'application/pdf', name: filename),
          ],
        ),
      );

      logger.info('insights_pdf_export_succeeded');

      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF export prepared: $filename')));
    } catch (error, stack) {
      logger.warning('insights_pdf_export_failed', error, stack);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF export failed: $error')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(insightsDataProvider);

    return Scaffold(
      appBar: AppBar(
        leading: onOpenDrawer != null
            ? IconButton(icon: const Icon(Icons.menu), onPressed: onOpenDrawer)
            : null,
        title: const Text('Insights'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Export report',
            icon: const Icon(Icons.download_outlined),
            onSelected: (value) {
              if (value == 'csv') {
                _exportInsightsCsv(context, ref);
              } else if (value == 'pdf') {
                _exportInsightsPdf(context, ref);
              }
            },
            itemBuilder: (BuildContext context) => const [
              PopupMenuItem<String>(
                value: 'csv',
                child: Row(
                  children: [
                    Icon(Icons.table_chart, size: 18),
                    SizedBox(width: 8),
                    Text('Export as CSV'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf, size: 18),
                    SizedBox(width: 8),
                    Text('Export as PDF'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ResponsiveBody(
        child: async.when(
          data: (data) => _InsightsContent(data: data),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
        ),
      ),
    );
  }
}

enum _InsightsRange { sevenDays, thirtyDays, ninetyDays, all }

enum _BillingWindow { sevenDays, thirtyDays, sixtyDays }

const _insightPalette = [
  Color(0xFF00A6FB),
  Color(0xFFFF006E),
  Color(0xFFFB5607),
  Color(0xFF8338EC),
  Color(0xFF3A86FF),
  Color(0xFF06D6A0),
];

class _InsightsData {
  _InsightsData({
    required this.expenses,
    required this.subscriptions,
    required this.categoryNames,
  });

  final List<Expense> expenses;
  final List<Subscription> subscriptions;
  final Map<int, String> categoryNames;
}

class _InsightsContent extends StatelessWidget {
  const _InsightsContent({required this.data});

  final _InsightsData data;

  @override
  Widget build(BuildContext context) {
    return _InsightsDashboard(data: data);
  }
}

class _InsightsDashboard extends ConsumerStatefulWidget {
  const _InsightsDashboard({required this.data});

  final _InsightsData data;

  @override
  ConsumerState<_InsightsDashboard> createState() => _InsightsDashboardState();
}

class _InsightsDashboardState extends ConsumerState<_InsightsDashboard> {
  _InsightsRange _range = _InsightsRange.thirtyDays;
  _BillingWindow _billingWindow = _BillingWindow.thirtyDays;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final filteredExpenses = _filteredExpenses(widget.data.expenses);
    final expenseByCurrency = <String, double>{};
    for (final e in filteredExpenses) {
      expenseByCurrency.update(
        e.currency,
        (v) => v + e.amount,
        ifAbsent: () => e.amount,
      );
    }

    final expenseCurrencyEntries = expenseByCurrency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final categorySpend = <String, double>{};
    for (final e in filteredExpenses) {
      final name = e.categoryId == null
          ? 'Uncategorized'
          : (widget.data.categoryNames[e.categoryId!] ?? 'Unknown');
      categorySpend.update(name, (v) => v + e.amount, ifAbsent: () => e.amount);
    }

    final topCategories = categorySpend.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final categoryEntries = topCategories;

    final monthlyBurnByCurrency = <String, double>{};
    for (final s in widget.data.subscriptions) {
      final monthly = _estimateMonthlyAmount(s.amount, s.cycle);
      monthlyBurnByCurrency.update(
        s.currency,
        (v) => v + monthly,
        ifAbsent: () => monthly,
      );
    }

    final subscriptionCurrencyEntries = monthlyBurnByCurrency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final cycleSummary = <String, _CycleSummary>{};
    for (final subscription in widget.data.subscriptions) {
      final bucket = _cycleBucket(subscription.cycle);
      final monthly = _estimateMonthlyAmount(
        subscription.amount,
        subscription.cycle,
      );
      cycleSummary.update(
        bucket,
        (summary) => summary.copyWith(
          count: summary.count + 1,
          monthlyBurn: summary.monthlyBurn + monthly,
        ),
        ifAbsent: () => _CycleSummary(count: 1, monthlyBurn: monthly),
      );
    }

    final cycleEntries = cycleSummary.entries.toList()
      ..sort((a, b) => b.value.monthlyBurn.compareTo(a.value.monthlyBurn));

    final largestSubscriptions = widget.data.subscriptions.toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    final recentExpenses = filteredExpenses.toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final recentSubscriptions = widget.data.subscriptions.toList()
      ..sort((a, b) => b.nextBillingDate.compareTo(a.nextBillingDate));
    final recurringExpenses = filteredExpenses.where((e) => e.isRecurring);
    final recurringByCurrency = <String, double>{};
    for (final expense in recurringExpenses) {
      recurringByCurrency.update(
        expense.currency,
        (v) => v + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }

    final upcomingBillings = _upcomingBillings(
      widget.data.subscriptions,
      _billingWindowDuration(_billingWindow),
    );
    final upcomingByCurrency = <String, double>{};
    for (final subscription in upcomingBillings) {
      upcomingByCurrency.update(
        subscription.currency,
        (v) => v + subscription.amount,
        ifAbsent: () => subscription.amount,
      );
    }
    final upcomingTrialCount = upcomingBillings.where((s) => s.isTrial).length;
    final activeTrialCount = widget.data.subscriptions.where((subscription) {
      if (!subscription.isTrial) {
        return false;
      }
      final trialEnds = subscription.trialEndsAt;
      return trialEnds == null || !trialEnds.isBefore(now);
    }).length;
    final expiredTrialCount = widget.data.subscriptions.where((subscription) {
      if (!subscription.isTrial || subscription.trialEndsAt == null) {
        return false;
      }
      final trialEndDay = DateTime(
        subscription.trialEndsAt!.year,
        subscription.trialEndsAt!.month,
        subscription.trialEndsAt!.day,
      );
      final todayDay = DateTime(now.year, now.month, now.day);
      return trialEndDay.difference(todayDay).inDays < 0;
    }).length;

    final numberFmt = NumberFormat('#,##0.00');
    final trendCurrency = _dominantCurrency(filteredExpenses);
    final trendPoints = _buildTrendPoints(
      filteredExpenses,
      currency: trendCurrency,
    );
    final peakTrendValue = trendPoints.isEmpty
        ? 0.0
        : trendPoints.map((e) => e.amount).reduce((a, b) => a > b ? a : b);
    final monthComparison = _buildMonthComparison(widget.data.expenses);
    final increasingCurrencies = monthComparison.rows
        .where((row) => row.delta > 0)
        .length;

    final detailCards = <Widget>[
      _InfoCard(
        title: _rangeTitle(),
        lines: [
          'Expenses logged: ${filteredExpenses.length}',
          if (expenseByCurrency.isEmpty)
            'No expense totals yet'
          else
            ...expenseByCurrency.entries.map(
              (e) => 'Spent (${e.key}): ${numberFmt.format(e.value)}',
            ),
        ],
      ),
      _CurrencyBreakdownCard(
        title: 'Expense Currency Split',
        entries: expenseCurrencyEntries,
        numberFmt: numberFmt,
      ),
      _CategoryDistributionCard(
        title: 'Category Distribution',
        entries: categoryEntries,
        numberFmt: numberFmt,
      ),
      _InfoCard(
        title: 'Subscriptions',
        lines: [
          'Active subscriptions: ${widget.data.subscriptions.length}',
          if (monthlyBurnByCurrency.isEmpty)
            'No subscription totals yet'
          else
            ...monthlyBurnByCurrency.entries.map(
              (e) =>
                  'Est. monthly burn (${e.key}): ${numberFmt.format(e.value)}',
            ),
        ],
      ),
      _InfoCard(
        title: 'Recurring Expenses',
        lines: [
          'Recurring entries in ${_rangeTitle().toLowerCase()}: ${recurringExpenses.length}',
          if (recurringByCurrency.isEmpty)
            'No recurring expense totals yet'
          else
            ...recurringByCurrency.entries.map(
              (e) => 'Recurring spend (${e.key}): ${numberFmt.format(e.value)}',
            ),
        ],
      ),
      _UpcomingBillingCard(
        subscriptions: upcomingBillings,
        totalsByCurrency: upcomingByCurrency,
        trialCount: upcomingTrialCount,
        window: _billingWindow,
        onWindowChanged: (window) => setState(() => _billingWindow = window),
        onSubscriptionTap: (subscription) async {
          await Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => AddSubscriptionScreen(subscription: subscription),
            ),
          );
          ref.invalidate(insightsDataProvider);
        },
        numberFmt: numberFmt,
      ),
      _CurrencyBreakdownCard(
        title: 'Subscription Currency Split',
        entries: subscriptionCurrencyEntries,
        numberFmt: numberFmt,
      ),
      _InfoCard(
        title: 'Subscription Cycle Mix',
        lines: cycleEntries.isEmpty
            ? const ['No subscription cycle data yet']
            : cycleEntries
                  .map(
                    (entry) =>
                        '${entry.key}: ${entry.value.count} items, est. monthly burn ${numberFmt.format(entry.value.monthlyBurn)}',
                  )
                  .toList(),
      ),
      _LargeSubscriptionsCard(
        subscriptions: largestSubscriptions,
        numberFmt: numberFmt,
      ),
      _RecentActivityCard(
        recentExpenses: recentExpenses,
        recentSubscriptions: recentSubscriptions,
        numberFmt: numberFmt,
      ),
      _InfoCard(
        title: 'Top Categories (This Month)',
        lines: topCategories.isEmpty
            ? const ['No category spend yet']
            : topCategories
                  .take(5)
                  .map((e) => '${e.key}: ${numberFmt.format(e.value)}')
                  .toList(),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _RangeSelector(
          value: _range,
          onChanged: (value) => setState(() => _range = value),
        ),
        const SizedBox(height: 12),
        _KeyMetricsStrip(
          metrics: [
            _MetricItem(label: 'Expenses', value: '${filteredExpenses.length}'),
            _MetricItem(
              label: 'Categories',
              value: '${categoryEntries.length}',
            ),
            _MetricItem(
              label: 'Subscriptions',
              value: '${widget.data.subscriptions.length}',
            ),
            _MetricItem(label: 'Trials', value: '$activeTrialCount'),
            _MetricItem(label: 'Trial Expired', value: '$expiredTrialCount'),
            _MetricItem(label: 'MoM Up', value: '$increasingCurrencies'),
          ],
        ),
        const SizedBox(height: 12),
        _TrendChartCard(
          title: _rangeTitle(),
          points: trendPoints,
          peakValue: peakTrendValue,
          valueSuffix: trendCurrency,
          numberFmt: numberFmt,
        ),
        const SizedBox(height: 12),
        _MonthOverMonthCard(comparison: monthComparison, numberFmt: numberFmt),
        const SizedBox(height: 12),
        ..._withSpacing(detailCards),
      ],
    );
  }

  List<Widget> _withSpacing(List<Widget> widgets) {
    final out = <Widget>[];
    for (var i = 0; i < widgets.length; i++) {
      out.add(widgets[i]);
      if (i != widgets.length - 1) {
        out.add(const SizedBox(height: 12));
      }
    }
    return out;
  }

  List<Expense> _filteredExpenses(List<Expense> expenses) {
    final now = DateTime.now();
    final start = _rangeStart(now);
    return expenses.where((e) => !e.occurredAt.isBefore(start)).toList();
  }

  String _rangeTitle() {
    return switch (_range) {
      _InsightsRange.sevenDays => 'Last 7 Days',
      _InsightsRange.thirtyDays => 'Last 30 Days',
      _InsightsRange.ninetyDays => 'Last 90 Days',
      _InsightsRange.all => 'All Time',
    };
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

  List<Subscription> _upcomingBillings(
    List<Subscription> subscriptions,
    Duration window,
  ) {
    final now = DateTime.now();
    final end = now.add(window);
    final result = subscriptions.where((subscription) {
      final billing = subscription.nextBillingDate;
      return !billing.isBefore(now) && !billing.isAfter(end);
    }).toList();
    result.sort((a, b) => a.nextBillingDate.compareTo(b.nextBillingDate));
    return result;
  }

  Duration _billingWindowDuration(_BillingWindow window) {
    return switch (window) {
      _BillingWindow.sevenDays => const Duration(days: 7),
      _BillingWindow.thirtyDays => const Duration(days: 30),
      _BillingWindow.sixtyDays => const Duration(days: 60),
    };
  }

  List<_TrendPoint> _buildTrendPoints(
    List<Expense> expenses, {
    String? currency,
  }) {
    if (expenses.isEmpty) {
      return const [];
    }

    final scoped = currency == null
        ? expenses
        : expenses.where((expense) => expense.currency == currency).toList();
    if (scoped.isEmpty) {
      return const [];
    }

    final byDay = <DateTime, double>{};
    for (final expense in scoped) {
      final day = DateTime(
        expense.occurredAt.year,
        expense.occurredAt.month,
        expense.occurredAt.day,
      );
      byDay.update(
        day,
        (v) => v + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }

    final now = DateTime.now();
    final sortedDays = byDay.keys.toList()..sort();
    final start = _range == _InsightsRange.all
        ? sortedDays.first
        : _rangeStart(now);
    final end = _range == _InsightsRange.all
        ? sortedDays.last
        : DateTime(now.year, now.month, now.day);

    final points = <_TrendPoint>[];
    var cursor = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    while (!cursor.isAfter(endDay)) {
      points.add(_TrendPoint(cursor, byDay[cursor] ?? 0));
      cursor = cursor.add(const Duration(days: 1));
    }
    return points;
  }

  String? _dominantCurrency(List<Expense> expenses) {
    if (expenses.isEmpty) {
      return null;
    }
    final totals = <String, double>{};
    for (final expense in expenses) {
      totals.update(
        expense.currency,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.first.key;
  }

  DateTime _rangeStart(DateTime now) {
    return switch (_range) {
      _InsightsRange.sevenDays => DateTime(now.year, now.month, now.day - 6),
      _InsightsRange.thirtyDays => DateTime(now.year, now.month, now.day - 29),
      _InsightsRange.ninetyDays => DateTime(now.year, now.month, now.day - 89),
      _InsightsRange.all => DateTime.fromMillisecondsSinceEpoch(0),
    };
  }

  _MonthComparison _buildMonthComparison(List<Expense> expenses) {
    final now = DateTime.now();
    final currentStart = DateTime(now.year, now.month, 1);
    final previousStart = DateTime(now.year, now.month - 1, 1);

    final currentByCurrency = <String, double>{};
    final previousByCurrency = <String, double>{};

    for (final expense in expenses) {
      if (!expense.occurredAt.isBefore(currentStart)) {
        currentByCurrency.update(
          expense.currency,
          (v) => v + expense.amount,
          ifAbsent: () => expense.amount,
        );
      } else if (!expense.occurredAt.isBefore(previousStart) &&
          expense.occurredAt.isBefore(currentStart)) {
        previousByCurrency.update(
          expense.currency,
          (v) => v + expense.amount,
          ifAbsent: () => expense.amount,
        );
      }
    }

    final currencies = <String>{
      ...currentByCurrency.keys,
      ...previousByCurrency.keys,
    };
    final rows = <_MonthComparisonRow>[];
    for (final currency in currencies) {
      final current = currentByCurrency[currency] ?? 0;
      final previous = previousByCurrency[currency] ?? 0;
      final delta = current - previous;
      final pct = previous == 0 ? null : (delta / previous) * 100;
      rows.add(
        _MonthComparisonRow(
          currency: currency,
          current: current,
          previous: previous,
          delta: delta,
          pct: pct,
        ),
      );
    }
    rows.sort((a, b) => b.current.compareTo(a.current));
    return _MonthComparison(rows: rows);
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
}

class _TrendPoint {
  const _TrendPoint(this.day, this.amount);

  final DateTime day;
  final double amount;
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

class _MonthComparison {
  const _MonthComparison({required this.rows});

  final List<_MonthComparisonRow> rows;
}

class _MonthComparisonRow {
  const _MonthComparisonRow({
    required this.currency,
    required this.current,
    required this.previous,
    required this.delta,
    required this.pct,
  });

  final String currency;
  final double current;
  final double previous;
  final double delta;
  final double? pct;
}

class _MetricItem {
  const _MetricItem({required this.label, required this.value});

  final String label;
  final String value;
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.value, required this.onChanged});

  final _InsightsRange value;
  final ValueChanged<_InsightsRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in {
          _InsightsRange.sevenDays: '7D',
          _InsightsRange.thirtyDays: '30D',
          _InsightsRange.ninetyDays: '90D',
          _InsightsRange.all: 'All',
        }.entries)
          ChoiceChip(
            label: Text(entry.value),
            selected: value == entry.key,
            onSelected: (_) => onChanged(entry.key),
          ),
      ],
    );
  }
}

class _TrendChartCard extends StatelessWidget {
  const _TrendChartCard({
    required this.title,
    required this.points,
    required this.peakValue,
    required this.valueSuffix,
    required this.numberFmt,
  });

  final String title;
  final List<_TrendPoint> points;
  final double peakValue;
  final String? valueSuffix;
  final NumberFormat numberFmt;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$title Trend',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            if (points.isEmpty)
              const Text('No expense data in this range yet')
            else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Peak: ${numberFmt.format(peakValue)}${valueSuffix == null ? '' : ' $valueSuffix'}',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  Text(
                    'Days: ${points.length}',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 190,
                child: CustomPaint(
                  painter: _TrendLineChartPainter(
                    points: points,
                    maxValue: peakValue,
                    lineColor: _insightPalette.first,
                    fillColor: _insightPalette.first.withValues(alpha: 0.16),
                    gridColor: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('MMM d, yyyy h:mm a').format(points.first.day),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  Text(
                    DateFormat('MMM d, yyyy h:mm a').format(points.last.day),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrendLineChartPainter extends CustomPainter {
  _TrendLineChartPainter({
    required this.points,
    required this.maxValue,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
  });

  final List<_TrendPoint> points;
  final double maxValue;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || maxValue <= 0) {
      return;
    }

    const horizontalPadding = 8.0;
    const verticalPadding = 8.0;
    final chartRect = Rect.fromLTWH(
      horizontalPadding,
      verticalPadding,
      size.width - horizontalPadding * 2,
      size.height - verticalPadding * 2,
    );
    if (chartRect.width <= 0 || chartRect.height <= 0) {
      return;
    }

    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = chartRect.top + (chartRect.height * i / 4);
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
    }

    final pointOffsets = <Offset>[];
    for (var i = 0; i < points.length; i++) {
      final x = points.length == 1
          ? chartRect.center.dx
          : chartRect.left + (chartRect.width * i / (points.length - 1));
      final normalized = points[i].amount / maxValue;
      final y = chartRect.bottom - (normalized * chartRect.height);
      pointOffsets.add(Offset(x, y));
    }

    final linePath = Path()
      ..moveTo(pointOffsets.first.dx, pointOffsets.first.dy);
    for (var i = 1; i < pointOffsets.length; i++) {
      linePath.lineTo(pointOffsets[i].dx, pointOffsets[i].dy);
    }

    final fillPath = Path.from(linePath)
      ..lineTo(pointOffsets.last.dx, chartRect.bottom)
      ..lineTo(pointOffsets.first.dx, chartRect.bottom)
      ..close();

    final fillPaint = Paint()..color = fillColor;
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    if (pointOffsets.length <= 16) {
      final pointPaint = Paint()..color = lineColor;
      for (final offset in pointOffsets) {
        canvas.drawCircle(offset, 3.5, pointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrendLineChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.gridColor != gridColor;
  }
}

class _KeyMetricsStrip extends StatelessWidget {
  const _KeyMetricsStrip({required this.metrics});

  final List<_MetricItem> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        const maxColumns = 4;
        const minTileWidth = 148.0;
        final maxWidth = constraints.maxWidth;
        final estimatedColumns = (maxWidth / (minTileWidth + spacing))
            .floor()
            .clamp(1, maxColumns);
        final columns = estimatedColumns.toInt();
        final tileWidth = (maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: tileWidth,
                child: _MetricTile(label: metric.label, value: metric.value),
              ),
          ],
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthOverMonthCard extends StatelessWidget {
  const _MonthOverMonthCard({
    required this.comparison,
    required this.numberFmt,
  });

  final _MonthComparison comparison;
  final NumberFormat numberFmt;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Month-over-Month Spend',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (comparison.rows.isEmpty)
              const Text('Not enough expense data yet')
            else
              ...comparison.rows.map((row) {
                final isNew = row.pct == null;
                final isUp = row.delta > 0;
                final isDown = row.delta < 0;
                final directionIcon = isNew
                    ? Icons.fiber_new
                    : isUp
                    ? Icons.trending_up
                    : isDown
                    ? Icons.trending_down
                    : Icons.trending_flat;
                final directionColor = isNew
                    ? Theme.of(context).colorScheme.secondary
                    : isUp
                    ? Theme.of(context).colorScheme.error
                    : isDown
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 46,
                        child: Text(
                          row.currency,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${numberFmt.format(row.previous)} -> ${numberFmt.format(row.current)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(directionIcon, size: 18, color: directionColor),
                      if (!isNew) ...[
                        const SizedBox(width: 4),
                        Text(
                          '${row.delta >= 0 ? '+' : ''}${row.pct!.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: directionColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _CategoryDistributionCard extends StatelessWidget {
  const _CategoryDistributionCard({
    required this.title,
    required this.entries,
    required this.numberFmt,
  });

  final String title;
  final List<MapEntry<String, double>> entries;
  final NumberFormat numberFmt;

  @override
  Widget build(BuildContext context) {
    final peak = entries.isEmpty ? 0.0 : entries.first.value;
    final topEntries = entries.take(6).toList();
    final total = topEntries.fold<double>(0, (sum, entry) => sum + entry.value);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 32),
            if (entries.isEmpty)
              const Text('No category spend yet')
            else ...[
              Center(
                child: SizedBox(
                  width: 168,
                  height: 168,
                  child: CustomPaint(
                    painter: _DonutChartPainter(
                      values: [for (final entry in topEntries) entry.value],
                      colors: [
                        for (var i = 0; i < topEntries.length; i++)
                          _insightPalette[i % _insightPalette.length],
                      ],
                      trackColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Total',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          Text(
                            numberFmt.format(total),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...topEntries.asMap().entries.map((mapped) {
                final index = mapped.key;
                final entry = mapped.value;
                final color = _insightPalette[index % _insightPalette.length];
                final pct = total == 0 ? 0 : (entry.value / total) * 100;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.key,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('${pct.toStringAsFixed(1)}%'),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                minHeight: 8,
                                value: peak == 0 ? 0 : entry.value / peak,
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  color,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(numberFmt.format(entry.value)),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  _DonutChartPainter({
    required this.values,
    required this.colors,
    required this.trackColor,
  });

  final List<double> values;
  final List<Color> colors;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) {
      return;
    }
    final total = values.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) {
      return;
    }

    final strokeWidth = size.shortestSide * 0.2;
    final rect = Offset.zero & size;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt
      ..color = trackColor;
    canvas.drawArc(rect, 0, math.pi * 2, false, trackPaint);

    var startAngle = -math.pi / 2;
    const gap = 0.03;

    for (var i = 0; i < values.length; i++) {
      final rawSweep = (values[i] / total) * math.pi * 2;
      final sweepAngle = rawSweep > gap ? rawSweep - gap : rawSweep;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt
        ..color = colors[i % colors.length];
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += rawSweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.colors != colors ||
        oldDelegate.trackColor != trackColor;
  }
}

class _CurrencyBreakdownCard extends StatelessWidget {
  const _CurrencyBreakdownCard({
    required this.title,
    required this.entries,
    required this.numberFmt,
  });

  final String title;
  final List<MapEntry<String, double>> entries;
  final NumberFormat numberFmt;

  @override
  Widget build(BuildContext context) {
    final peak = entries.isEmpty ? 0.0 : entries.first.value;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              const Text('No expense currency data yet')
            else
              ...entries.asMap().entries.map((mapped) {
                final index = mapped.key;
                final entry = mapped.value;
                final color = _insightPalette[index % _insightPalette.length];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                entry.key,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          Text(numberFmt.format(entry.value)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 8,
                          value: peak == 0 ? 0 : entry.value / peak,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _LargeSubscriptionsCard extends StatelessWidget {
  const _LargeSubscriptionsCard({
    required this.subscriptions,
    required this.numberFmt,
  });

  final List<Subscription> subscriptions;
  final NumberFormat numberFmt;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Largest Subscriptions',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (subscriptions.isEmpty)
              const Text('No subscriptions yet')
            else
              ...subscriptions.take(5).map((subscription) {
                final trialStatus = _trialStatusText(subscription, today);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    subscription.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            if (subscription.isTrial) ...[
                              const SizedBox(height: 4),
                              Text(
                                trialStatus ?? 'Trial',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color:
                                          subscription.trialEndsAt != null &&
                                              subscription.trialEndsAt!
                                                  .isBefore(today)
                                          ? Theme.of(context).colorScheme.error
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ],
                            const SizedBox(height: 2),
                            Text(
                              '${subscription.currency} ${numberFmt.format(subscription.amount)} · ${subscription.cycle}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Next ${DateFormat('MMM d, yyyy h:mm a').format(subscription.nextBillingDate)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  String? _trialStatusText(Subscription subscription, DateTime today) {
    if (!subscription.isTrial) {
      return null;
    }
    final trialEnds = subscription.trialEndsAt;
    if (trialEnds == null) {
      return 'Trial';
    }
    final days = _dayDifferenceFromToday(trialEnds, today);
    if (days < 0) {
      return 'Trial expired ${-days}d ago';
    }
    if (days == 0) {
      return 'Trial ends today';
    }
    return 'Trial ends in ${days}d';
  }

  int _dayDifferenceFromToday(DateTime value, DateTime today) {
    final day = DateTime(value.year, value.month, value.day);
    return day.difference(today).inDays;
  }
}

class _UpcomingBillingCard extends StatelessWidget {
  const _UpcomingBillingCard({
    required this.subscriptions,
    required this.totalsByCurrency,
    required this.trialCount,
    required this.window,
    required this.onWindowChanged,
    required this.onSubscriptionTap,
    required this.numberFmt,
  });

  final List<Subscription> subscriptions;
  final Map<String, double> totalsByCurrency;
  final int trialCount;
  final _BillingWindow window;
  final ValueChanged<_BillingWindow> onWindowChanged;
  final ValueChanged<Subscription> onSubscriptionTap;
  final NumberFormat numberFmt;

  @override
  Widget build(BuildContext context) {
    final entries = totalsByCurrency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final dateFmt = DateFormat('MMM d, yyyy h:mm a');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final displayedSubscriptions = [...subscriptions]
      ..sort((left, right) {
        if (left.isTrial != right.isTrial) {
          return left.isTrial ? -1 : 1;
        }

        final leftTrialEnds = left.trialEndsAt;
        final rightTrialEnds = right.trialEndsAt;
        if (left.isTrial && right.isTrial) {
          if (leftTrialEnds == null && rightTrialEnds == null) return 0;
          if (leftTrialEnds == null) return 1;
          if (rightTrialEnds == null) return -1;
          return leftTrialEnds.compareTo(rightTrialEnds);
        }

        return left.nextBillingDate.compareTo(right.nextBillingDate);
      });
    final title = switch (window) {
      _BillingWindow.sevenDays => 'Upcoming Billings (Next 7 Days)',
      _BillingWindow.thirtyDays => 'Upcoming Billings (Next 30 Days)',
      _BillingWindow.sixtyDays => 'Upcoming Billings (Next 60 Days)',
    };
    final overdueCount = subscriptions
        .where(
          (subscription) =>
              _dayDifferenceFromToday(subscription.nextBillingDate, today) < 0,
        )
        .length;
    final dueSoonCount = subscriptions.where((subscription) {
      final daysAway = _dayDifferenceFromToday(
        subscription.nextBillingDate,
        today,
      );
      return daysAway >= 0 && daysAway <= 3;
    }).length;
    final dueWithin24hCount = subscriptions.where((subscription) {
      final diff = subscription.nextBillingDate.difference(now);
      return !diff.isNegative && diff.inHours <= 24;
    }).length;
    final dueWithin48hCount = subscriptions.where((subscription) {
      final diff = subscription.nextBillingDate.difference(now);
      return !diff.isNegative && diff.inHours > 24 && diff.inHours <= 48;
    }).length;
    final expiredTrialCount = subscriptions.where((subscription) {
      if (!subscription.isTrial || subscription.trialEndsAt == null) {
        return false;
      }
      return _dayDifferenceFromToday(subscription.trialEndsAt!, today) < 0;
    }).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in {
                  _BillingWindow.sevenDays: '7D',
                  _BillingWindow.thirtyDays: '30D',
                  _BillingWindow.sixtyDays: '60D',
                }.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: window == entry.key,
                    onSelected: (_) => onWindowChanged(entry.key),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Scheduled payments: ${subscriptions.length}'),
            Text('Trial renewals in window: $trialCount'),
            Text('Overdue: $overdueCount · Due soon: $dueSoonCount'),
            Text('Due <24h: $dueWithin24hCount · Due <48h: $dueWithin48hCount'),
            if (expiredTrialCount > 0)
              Text(
                'Expired trials: $expiredTrialCount',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 8),
            if (entries.isEmpty)
              const Text('No upcoming billings in this window')
            else ...[
              if (trialCount > 0) ...[
                const SizedBox(height: 4),
                _UpcomingTrialSummaryRow(
                  trialCount: trialCount,
                  expiredTrialCount: expiredTrialCount,
                  dueWithin24hCount: dueWithin24hCount,
                ),
                const SizedBox(height: 8),
              ],
              ...entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('${entry.key}: ${numberFmt.format(entry.value)}'),
                ),
              ),
              ...displayedSubscriptions.take(5).map((subscription) {
                final daysAway = _dayDifferenceFromToday(
                  subscription.nextBillingDate,
                  today,
                );
                final isOverdue = daysAway < 0;
                final dueToday = daysAway == 0;
                final dueSoon = daysAway > 0 && daysAway <= 3;
                final urgent = isOverdue || dueToday || dueSoon;
                final billingStatus = isOverdue
                    ? 'Overdue by ${-daysAway}d'
                    : dueToday
                    ? 'Due today'
                    : dueSoon
                    ? 'Due in ${daysAway}d'
                    : null;
                final trialStatus = _trialStatusText(subscription, today);
                final subtitleParts = <String>[
                  '${dateFmt.format(subscription.nextBillingDate)} · ${subscription.currency} ${numberFmt.format(subscription.amount)}',
                  if (trialStatus != null) trialStatus,
                  if (billingStatus != null) billingStatus,
                ];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      subscription.isTrial
                          ? Icons.hourglass_bottom
                          : isOverdue
                          ? Icons.warning_rounded
                          : urgent
                          ? Icons.notifications_active
                          : Icons.receipt_long,
                      color: subscription.isTrial
                          ? Theme.of(context).colorScheme.tertiary
                          : isOverdue
                          ? Theme.of(context).colorScheme.error
                          : urgent
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(subscription.name),
                    subtitle: Text(subtitleParts.join(' · ')),
                    trailing: subscription.isTrial
                        ? _TrialStatusChip(
                            label: trialStatus ?? 'Trial',
                            isExpired: _isTrialExpired(subscription, today),
                            isEndingSoon: _isTrialEndingSoon(
                              subscription,
                              today,
                            ),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: () => onSubscriptionTap(subscription),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  int _dayDifferenceFromToday(DateTime value, DateTime today) {
    final day = DateTime(value.year, value.month, value.day);
    return day.difference(today).inDays;
  }

  String? _trialStatusText(Subscription subscription, DateTime today) {
    if (!subscription.isTrial) {
      return null;
    }
    final trialEnds = subscription.trialEndsAt;
    if (trialEnds == null) {
      return 'Trial';
    }
    final days = _dayDifferenceFromToday(trialEnds, today);
    if (days < 0) {
      return 'Trial expired ${-days}d ago';
    }
    if (days == 0) {
      return 'Trial ends today';
    }
    return 'Trial ends in ${days}d';
  }

  bool _isTrialExpired(Subscription subscription, DateTime today) {
    final trialEnds = subscription.trialEndsAt;
    return subscription.isTrial &&
        trialEnds != null &&
        _dayDifferenceFromToday(trialEnds, today) < 0;
  }

  bool _isTrialEndingSoon(Subscription subscription, DateTime today) {
    final trialEnds = subscription.trialEndsAt;
    if (!subscription.isTrial || trialEnds == null) {
      return false;
    }
    final days = _dayDifferenceFromToday(trialEnds, today);
    return days >= 0 && days <= 7;
  }
}

class _UpcomingTrialSummaryRow extends StatelessWidget {
  const _UpcomingTrialSummaryRow({
    required this.trialCount,
    required this.expiredTrialCount,
    required this.dueWithin24hCount,
  });

  final int trialCount;
  final int expiredTrialCount;
  final int dueWithin24hCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Trials in window: $trialCount · Expired: $expiredTrialCount · Due <24h: $dueWithin24hCount',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: scheme.onSecondaryContainer),
      ),
    );
  }
}

class _TrialStatusChip extends StatelessWidget {
  const _TrialStatusChip({
    required this.label,
    required this.isExpired,
    required this.isEndingSoon,
  });

  final String label;
  final bool isExpired;
  final bool isEndingSoon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = isExpired
        ? scheme.errorContainer
        : isEndingSoon
        ? scheme.tertiaryContainer
        : scheme.secondaryContainer;
    final foreground = isExpired
        ? scheme.onErrorContainer
        : isEndingSoon
        ? scheme.onTertiaryContainer
        : scheme.onSecondaryContainer;

    return Chip(
      label: Text(label),
      backgroundColor: background,
      labelStyle: TextStyle(color: foreground),
      side: BorderSide(color: background),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({
    required this.recentExpenses,
    required this.recentSubscriptions,
    required this.numberFmt,
  });

  final List<Expense> recentExpenses;
  final List<Subscription> recentSubscriptions;
  final NumberFormat numberFmt;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('MMM d, yyyy h:mm a');
    final today = DateTime.now();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Activity',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (recentExpenses.isEmpty && recentSubscriptions.isEmpty)
              const Text('No recent activity yet')
            else ...[
              if (recentExpenses.isNotEmpty) ...[
                Text(
                  'Latest expense',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  '${recentExpenses.first.currency} ${numberFmt.format(recentExpenses.first.amount)} · ${dateFmt.format(recentExpenses.first.occurredAt)}',
                ),
                const SizedBox(height: 12),
              ],
              if (recentSubscriptions.isNotEmpty) ...[
                Text(
                  'Next billing',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  '${recentSubscriptions.first.name} · ${dateFmt.format(recentSubscriptions.first.nextBillingDate)}',
                ),
                if (_trialStatusText(recentSubscriptions.first, today) !=
                    null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _trialStatusText(recentSubscriptions.first, today)!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color:
                          recentSubscriptions.first.trialEndsAt != null &&
                              recentSubscriptions.first.trialEndsAt!.isBefore(
                                today,
                              )
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }

  String? _trialStatusText(Subscription subscription, DateTime today) {
    if (!subscription.isTrial) {
      return null;
    }
    final trialEnds = subscription.trialEndsAt;
    if (trialEnds == null) {
      return 'Trial';
    }
    final days = _dayDifferenceFromToday(trialEnds, today);
    if (days < 0) {
      return 'Trial expired ${-days}d ago';
    }
    if (days == 0) {
      return 'Trial ends today';
    }
    return 'Trial ends in ${days}d';
  }

  int _dayDifferenceFromToday(DateTime value, DateTime today) {
    final day = DateTime(value.year, value.month, value.day);
    return day.difference(today).inDays;
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(line),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
