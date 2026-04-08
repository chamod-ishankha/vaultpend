import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/fx/currency_conversion.dart';
import '../../core/fx/fx_providers.dart';
import '../../core/fx/fx_snapshot.dart';
import '../../core/formatters/time_remaining_formatter.dart';
import '../../core/providers.dart';
import '../../core/export/insights_csv_export_service.dart';
import '../../core/export/insights_pdf_export_service.dart';
import '../../core/logging/app_logging.dart';
import '../../core/widgets/obsidian_app_bar.dart';
import '../../core/widgets/obsidian_card.dart';
import '../../core/widgets/responsive_layout.dart';
import '../auth/auth_providers.dart';
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
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: ObsidianAppBar(
        title: const Text('Insights'),
        leading: onOpenDrawer != null
            ? IconButton(icon: const Icon(Icons.menu), onPressed: onOpenDrawer)
            : null,
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Export report',
            icon: const Icon(Icons.download_rounded),
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
          const SizedBox(width: 8),
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

enum _InsightsReportView {
  overview,
  spendingFocus,
  subscriptionFocus,
  billingWatch,
  currencyBreakdown,
}

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
  _InsightsReportView _reportView = _InsightsReportView.overview;

  @override
  void initState() {
    super.initState();
    _loadReportView();
  }

  Future<void> _loadReportView() async {
    final stored = await ref
        .read(tokenStorageProvider)
        .readInsightsReportView();
    final parsed = _reportViewFromStorage(stored);
    if (!mounted) return;
    setState(() {
      _reportView = parsed;
      _applyReportViewDefaults(parsed);
    });
  }

  Future<void> _setReportView(_InsightsReportView view) async {
    setState(() {
      _reportView = view;
      _applyReportViewDefaults(view);
    });
    await ref.read(tokenStorageProvider).writeInsightsReportView(view.name);
  }

  void _applyReportViewDefaults(_InsightsReportView view) {
    switch (view) {
      case _InsightsReportView.overview:
        _range = _InsightsRange.thirtyDays;
        _billingWindow = _BillingWindow.thirtyDays;
        break;
      case _InsightsReportView.spendingFocus:
        _range = _InsightsRange.ninetyDays;
        _billingWindow = _BillingWindow.thirtyDays;
        break;
      case _InsightsReportView.subscriptionFocus:
        _range = _InsightsRange.thirtyDays;
        _billingWindow = _BillingWindow.sixtyDays;
        break;
      case _InsightsReportView.billingWatch:
        _range = _InsightsRange.sevenDays;
        _billingWindow = _BillingWindow.sixtyDays;
        break;
      case _InsightsReportView.currencyBreakdown:
        _range = _InsightsRange.thirtyDays;
        _billingWindow = _BillingWindow.thirtyDays;
        break;
    }
  }

  _InsightsReportView _reportViewFromStorage(String value) {
    return switch (value) {
      'spendingFocus' => _InsightsReportView.spendingFocus,
      'subscriptionFocus' => _InsightsReportView.subscriptionFocus,
      'billingWatch' => _InsightsReportView.billingWatch,
      'currencyBreakdown' => _InsightsReportView.currencyBreakdown,
      _ => _InsightsReportView.overview,
    };
  }

  @override
  Widget build(BuildContext context) {
    final preferredCurrency = ref.watch(preferredCurrencyProvider);
    final fxSnapshot = ref
        .watch(fxRatesProvider)
        .maybeWhen(data: (value) => value, orElse: () => null);
    final normalizedExpenses = widget.data.expenses
        .map(
          (expense) => _convertExpenseToPreferred(
            expense,
            preferredCurrency,
            fxSnapshot,
          ),
        )
        .toList(growable: false);
    final normalizedSubscriptions = widget.data.subscriptions
        .map(
          (subscription) => _convertSubscriptionToPreferred(
            subscription,
            preferredCurrency,
            fxSnapshot,
          ),
        )
        .toList(growable: false);
    final currencyWiseMode =
        _reportView == _InsightsReportView.currencyBreakdown;
    final effectiveExpenses = currencyWiseMode
        ? widget.data.expenses
        : normalizedExpenses;
    final effectiveSubscriptions = currencyWiseMode
        ? widget.data.subscriptions
        : normalizedSubscriptions;
    final now = DateTime.now();
    final filteredExpenses = _filteredExpenses(effectiveExpenses);
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
    for (final s in effectiveSubscriptions) {
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
    for (final subscription in effectiveSubscriptions) {
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

    final largestSubscriptions = effectiveSubscriptions.toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    final recentExpenses = filteredExpenses.toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final recentSubscriptions = effectiveSubscriptions.toList()
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
      effectiveSubscriptions,
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
    final activeTrialCount = effectiveSubscriptions.where((subscription) {
      if (!subscription.isTrial) {
        return false;
      }
      final trialEnds = subscription.trialEndsAt;
      return trialEnds == null || !trialEnds.isBefore(now);
    }).length;
    final expiredTrialCount = effectiveSubscriptions.where((subscription) {
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
    final monthComparison = _buildMonthComparison(effectiveExpenses);
    final increasingCurrencies = monthComparison.rows
        .where((row) => row.delta > 0)
        .length;
    final combinedCurrencyTotals = <String, double>{};
    for (final entry in expenseByCurrency.entries) {
      combinedCurrencyTotals.update(
        entry.key,
        (value) => value + entry.value,
        ifAbsent: () => entry.value,
      );
    }
    for (final entry in monthlyBurnByCurrency.entries) {
      combinedCurrencyTotals.update(
        entry.key,
        (value) => value + entry.value,
        ifAbsent: () => entry.value,
      );
    }
    final combinedCurrencyEntries = combinedCurrencyTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final detailCards = <Widget>[
      if (_reportView == _InsightsReportView.currencyBreakdown)
        _CurrencyBreakdownCard(
          title: 'Currency-wise Breakdown (Spend + Monthly Burn)',
          entries: combinedCurrencyEntries,
          numberFmt: numberFmt,
        ),
      if (_showsSpendingSections(_reportView)) ...[
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
          title: 'Recurring Expenses',
          lines: [
            'Recurring entries in ${_rangeTitle().toLowerCase()}: ${recurringExpenses.length}',
            if (recurringByCurrency.isEmpty)
              'No recurring expense totals yet'
            else
              ...recurringByCurrency.entries.map(
                (e) =>
                    'Recurring spend (${e.key}): ${numberFmt.format(e.value)}',
              ),
          ],
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
      ],
      if (_showsSubscriptionSections(_reportView)) ...[
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
      ],
      if (_showsBillingSections(_reportView))
        _UpcomingBillingCard(
          subscriptions: upcomingBillings,
          totalsByCurrency: upcomingByCurrency,
          trialCount: upcomingTrialCount,
          window: _billingWindow,
          onWindowChanged: (window) => setState(() => _billingWindow = window),
          onSubscriptionTap: (subscription) async {
            await Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) =>
                    AddSubscriptionScreen(subscription: subscription),
              ),
            );
            ref.invalidate(insightsDataProvider);
          },
          numberFmt: numberFmt,
        ),
      if (_showsActivitySections(_reportView))
        _RecentActivityCard(
          recentExpenses: recentExpenses,
          recentSubscriptions: recentSubscriptions,
          numberFmt: numberFmt,
        ),
    ];

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        72 + MediaQuery.paddingOf(context).top,
        16,
        120,
      ),
      children: [
        _ReportViewSelector(
          value: _reportView,
          onChanged: (value) => unawaited(_setReportView(value)),
        ),
        const SizedBox(height: 12),
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

  bool _showsSpendingSections(_InsightsReportView view) {
    return view == _InsightsReportView.overview ||
        view == _InsightsReportView.spendingFocus ||
        view == _InsightsReportView.currencyBreakdown;
  }

  bool _showsSubscriptionSections(_InsightsReportView view) {
    return view == _InsightsReportView.overview ||
        view == _InsightsReportView.subscriptionFocus ||
        view == _InsightsReportView.billingWatch ||
        view == _InsightsReportView.currencyBreakdown;
  }

  bool _showsBillingSections(_InsightsReportView view) {
    return view == _InsightsReportView.overview ||
        view == _InsightsReportView.subscriptionFocus ||
        view == _InsightsReportView.billingWatch;
  }

  bool _showsActivitySections(_InsightsReportView view) {
    return view != _InsightsReportView.billingWatch;
  }

  Expense _convertExpenseToPreferred(
    Expense expense,
    String preferredCurrency,
    FxSnapshot? fxSnapshot,
  ) {
    final converted = convertCurrencyAmount(
      amount: expense.amount,
      from: expense.currency,
      to: preferredCurrency,
      snapshot: fxSnapshot,
    );
    if (converted == null || expense.currency == preferredCurrency) {
      return expense;
    }

    return Expense()
      ..id = expense.id
      ..userId = expense.userId
      ..remoteId = expense.remoteId
      ..categoryId = expense.categoryId
      ..amount = converted
      ..currency = preferredCurrency
      ..occurredAt = expense.occurredAt
      ..note = expense.note
      ..isRecurring = expense.isRecurring;
  }

  Subscription _convertSubscriptionToPreferred(
    Subscription subscription,
    String preferredCurrency,
    FxSnapshot? fxSnapshot,
  ) {
    final converted = convertCurrencyAmount(
      amount: subscription.amount,
      from: subscription.currency,
      to: preferredCurrency,
      snapshot: fxSnapshot,
    );
    if (converted == null || subscription.currency == preferredCurrency) {
      return subscription;
    }

    return Subscription()
      ..id = subscription.id
      ..userId = subscription.userId
      ..remoteId = subscription.remoteId
      ..name = subscription.name
      ..amount = converted
      ..currency = preferredCurrency
      ..cycle = subscription.cycle
      ..nextBillingDate = subscription.nextBillingDate
      ..isTrial = subscription.isTrial
      ..trialEndsAt = subscription.trialEndsAt;
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
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(window).subtract(const Duration(milliseconds: 1));
    final result = subscriptions.where((subscription) {
      final billing = subscription.nextBillingDate;
      return !billing.isBefore(start) && !billing.isAfter(end);
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

  Future<void> _openPicker(BuildContext context) async {
    final options = <_InsightsRange, ({String label, String hint})>{
      _InsightsRange.sevenDays: (label: '7D', hint: 'Last 7 days'),
      _InsightsRange.thirtyDays: (label: '30D', hint: 'Last 30 days'),
      _InsightsRange.ninetyDays: (label: '90D', hint: 'Last 90 days'),
      _InsightsRange.all: (label: 'All', hint: 'All available data'),
    };

    final selected = await showModalBottomSheet<_InsightsRange>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Date range',
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select the time window for insights.',
                  style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                ...options.entries.map((entry) {
                  final selectedRange = value == entry.key;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: selectedRange
                          ? scheme.primaryContainer
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => Navigator.pop(sheetContext, entry.key),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Text(
                                entry.value.label,
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: selectedRange
                                          ? scheme.onPrimaryContainer
                                          : scheme.onSurface,
                                    ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  entry.value.hint,
                                  style: Theme.of(sheetContext)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: selectedRange
                                            ? scheme.onPrimaryContainer
                                                  .withValues(alpha: 0.9)
                                            : scheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                              if (selectedRange)
                                Icon(
                                  Icons.check_circle,
                                  size: 18,
                                  color: scheme.primary,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null) {
      onChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = switch (value) {
      _InsightsRange.sevenDays => '7D',
      _InsightsRange.thirtyDays => '30D',
      _InsightsRange.ninetyDays => '90D',
      _InsightsRange.all => 'All',
    };

    final hint = switch (value) {
      _InsightsRange.sevenDays => 'Last 7 days',
      _InsightsRange.thirtyDays => 'Last 30 days',
      _InsightsRange.ninetyDays => 'Last 90 days',
      _InsightsRange.all => 'All available data',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date range',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openPicker(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: scheme.outlineVariant.withOpacity(0.5),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Icon(
                  Icons.unfold_more_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReportViewSelector extends StatelessWidget {
  const _ReportViewSelector({required this.value, required this.onChanged});

  final _InsightsReportView value;
  final ValueChanged<_InsightsReportView> onChanged;

  Future<void> _openPicker(BuildContext context) async {
    final options = <_InsightsReportView, ({String label, String hint})>{
      _InsightsReportView.overview: (
        label: 'Overview',
        hint: 'Balanced summary',
      ),
      _InsightsReportView.spendingFocus: (
        label: 'Spending',
        hint: 'Expenses and categories',
      ),
      _InsightsReportView.subscriptionFocus: (
        label: 'Subscriptions',
        hint: 'Recurring tracking',
      ),
      _InsightsReportView.billingWatch: (
        label: 'Billing Watch',
        hint: 'Due dates and trials',
      ),
      _InsightsReportView.currencyBreakdown: (
        label: 'Currencies',
        hint: 'Currency-wise breakdown',
      ),
    };

    final selected = await showModalBottomSheet<_InsightsReportView>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Report view',
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pick the report style you want to see.',
                  style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                ...options.entries.map((entry) {
                  final selectedView = entry.key == value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: selectedView
                          ? scheme.primaryContainer
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => Navigator.pop(sheetContext, entry.key),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: selectedView
                                      ? scheme.primary
                                      : scheme.surface,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  switch (entry.key) {
                                    _InsightsReportView.overview =>
                                      Icons.dashboard_outlined,
                                    _InsightsReportView.spendingFocus =>
                                      Icons.trending_up_outlined,
                                    _InsightsReportView.subscriptionFocus =>
                                      Icons.subscriptions_outlined,
                                    _InsightsReportView.billingWatch =>
                                      Icons.event_note_outlined,
                                    _InsightsReportView.currencyBreakdown =>
                                      Icons.currency_exchange,
                                  },
                                  size: 18,
                                  color: selectedView
                                      ? scheme.onPrimary
                                      : scheme.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.value.label,
                                      style: Theme.of(sheetContext)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: selectedView
                                                ? scheme.onPrimaryContainer
                                                : scheme.onSurface,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      entry.value.hint,
                                      style: Theme.of(sheetContext)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: selectedView
                                                ? scheme.onPrimaryContainer
                                                      .withValues(alpha: 0.9)
                                                : scheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              if (selectedView)
                                Icon(
                                  Icons.check_circle,
                                  size: 18,
                                  color: scheme.primary,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null) {
      onChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Report focus',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openPicker(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: scheme.outlineVariant.withOpacity(0.5),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    switch (value) {
                      _InsightsReportView.overview => Icons.grid_view_rounded,
                      _InsightsReportView.spendingFocus =>
                        Icons.insights_rounded,
                      _InsightsReportView.subscriptionFocus =>
                        Icons.auto_awesome_motion_rounded,
                      _InsightsReportView.billingWatch =>
                        Icons.event_note_rounded,
                      _InsightsReportView.currencyBreakdown =>
                        Icons.currency_exchange_rounded,
                    },
                    size: 16,
                    color: scheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        switch (value) {
                          _InsightsReportView.overview => 'Overview',
                          _InsightsReportView.spendingFocus => 'Spending',
                          _InsightsReportView.subscriptionFocus =>
                            'Subscriptions',
                          _InsightsReportView.billingWatch => 'Billing Watch',
                          _InsightsReportView.currencyBreakdown => 'Currencies',
                        },
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        switch (value) {
                          _InsightsReportView.overview => 'Balanced summary',
                          _InsightsReportView.spendingFocus =>
                            'Expenses and categories',
                          _InsightsReportView.subscriptionFocus =>
                            'Recurring tracking',
                          _InsightsReportView.billingWatch =>
                            'Due dates and trials',
                          _InsightsReportView.currencyBreakdown =>
                            'Currency-wise breakdown',
                        },
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.unfold_more_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ObsidianCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (points.isEmpty)
            const Text('No trend data yet')
          else ...[
            Text(
              '${numberFmt.format(points.last.amount)} $valueSuffix',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 140,
              width: double.infinity,
              child: CustomPaint(
                painter: _TrendLineChartPainter(
                  points: points,
                  maxValue: peakValue,
                  lineColor: scheme.primary,
                  fillColor: scheme.primary.withOpacity(0.1),
                  gridColor: scheme.outlineVariant,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMM d').format(points.first.day),
                  style: theme.textTheme.labelSmall,
                ),
                Text(
                  DateFormat('MMM d').format(points.last.day),
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ],
        ],
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
    final theme = Theme.of(context);
    return ObsidianCard(
      level: ObsidianCardTonalLevel.low,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ObsidianCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Month-over-Month Spend',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
                  ? scheme.secondary
                  : isUp
                  ? scheme.error
                  : isDown
                  ? scheme.primary
                  : scheme.outline;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 46,
                      child: Text(
                        row.currency,
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${numberFmt.format(row.previous)} → ${numberFmt.format(row.current)}',
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final peak = entries.isEmpty ? 0.0 : entries.first.value;
    final topEntries = entries.take(6).toList();
    final total = topEntries.fold<double>(0, (sum, entry) => sum + entry.value);

    return ObsidianCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
                    trackColor: scheme.surfaceContainerHighest,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Total',
                          style: theme.textTheme.labelLarge,
                        ),
                        Text(
                          numberFmt.format(total),
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
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
                              backgroundColor: scheme.surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation<Color>(color),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final peak = entries.isEmpty ? 0.0 : entries.first.value;

    return ObsidianCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
                              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
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
                        backgroundColor: scheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = DateTime.now();
    return ObsidianCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Largest Subscriptions',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
                          Text(
                            subscription.name,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          if (subscription.isTrial) ...[
                            const SizedBox(height: 4),
                            Text(
                              trialStatus ?? 'Trial',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: subscription.trialEndsAt != null &&
                                        subscription.trialEndsAt!.isBefore(today)
                                    ? scheme.error
                                    : scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          const SizedBox(height: 2),
                          Text(
                            '${subscription.currency} ${numberFmt.format(subscription.amount)} · ${subscription.cycle}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Next ${DateFormat('MMM d').format(subscription.nextBillingDate)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  String? _trialStatusText(Subscription subscription, DateTime today) {
    if (!subscription.isTrial) {
      return null;
    }
    return formatTrialStatusLabel(subscription.trialEndsAt, now: today);
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

  Future<void> _openWindowPicker(BuildContext context) async {
    final options = <_BillingWindow, ({String label, String hint})>{
      _BillingWindow.sevenDays: (label: '7D', hint: 'Next 7 days'),
      _BillingWindow.thirtyDays: (label: '30D', hint: 'Next 30 days'),
      _BillingWindow.sixtyDays: (label: '60D', hint: 'Next 60 days'),
    };

    final selected = await showModalBottomSheet<_BillingWindow>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Billing window',
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select how far ahead to show due billings.',
                  style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                ...options.entries.map((entry) {
                  final selectedWindow = window == entry.key;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: selectedWindow
                          ? scheme.primaryContainer
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => Navigator.pop(sheetContext, entry.key),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Text(
                                entry.value.label,
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: selectedWindow
                                          ? scheme.onPrimaryContainer
                                          : scheme.onSurface,
                                    ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  entry.value.hint,
                                  style: Theme.of(sheetContext)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: selectedWindow
                                            ? scheme.onPrimaryContainer
                                                  .withValues(alpha: 0.9)
                                            : scheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                              if (selectedWindow)
                                Icon(
                                  Icons.check_circle,
                                  size: 18,
                                  color: scheme.primary,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null) {
      onWindowChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final entries = totalsByCurrency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final dateFmt = DateFormat('MMM d');
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
    final windowLabel = switch (window) {
      _BillingWindow.sevenDays => '7D',
      _BillingWindow.thirtyDays => '30D',
      _BillingWindow.sixtyDays => '60D',
    };
    final overdueCount = subscriptions
        .where(
          (subscription) =>
              _dayDifferenceFromToday(subscription.nextBillingDate, today) < 0,
        )
        .length;
    final expiredTrialCount = subscriptions.where((subscription) {
      if (!subscription.isTrial || subscription.trialEndsAt == null) {
        return false;
      }
      return _dayDifferenceFromToday(subscription.trialEndsAt!, today) < 0;
    }).length;

    return ObsidianCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              _WindowSelector(
                label: windowLabel,
                onTap: () => _openWindowPicker(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (overdueCount > 0 || expiredTrialCount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _UrgentAlert(
                overdueCount: overdueCount,
                expiredTrialCount: expiredTrialCount,
              ),
            ),
          if (entries.isEmpty)
            const Text('No upcoming billings in this window')
          else ...[
            ...entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${entry.key}: ${numberFmt.format(entry.value)}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...displayedSubscriptions.take(5).map((subscription) {
              final daysAway = _dayDifferenceFromToday(
                subscription.nextBillingDate,
                today,
              );
              final isOverdue = daysAway < 0;
              final dueToday = daysAway == 0;
              final dueSoon = daysAway > 0 && daysAway <= 3;
              final urgent = isOverdue || dueToday || dueSoon;
              final trialStatus = _trialStatusText(subscription, today);

              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: (subscription.isTrial
                            ? scheme.tertiary
                            : urgent
                                ? scheme.error
                                : scheme.primary)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    subscription.isTrial
                        ? Icons.hourglass_bottom
                        : isOverdue
                            ? Icons.warning_rounded
                            : urgent
                                ? Icons.notifications_active
                                : Icons.receipt_long,
                    size: 20,
                    color: subscription.isTrial
                        ? scheme.tertiary
                        : urgent
                            ? scheme.error
                            : scheme.primary,
                  ),
                ),
                title: Text(
                  subscription.name,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${dateFmt.format(subscription.nextBillingDate)} · ${subscription.currency} ${numberFmt.format(subscription.amount)}',
                  style: theme.textTheme.bodySmall,
                ),
                trailing: subscription.isTrial
                    ? _TrialStatusChip(
                        label: trialStatus ?? 'Trial',
                        isExpired: _isTrialExpired(subscription, today),
                        isEndingSoon: _isTrialEndingSoon(subscription, today),
                      )
                    : Icon(Icons.chevron_right, size: 16, color: scheme.onSurfaceVariant),
                onTap: () => onSubscriptionTap(subscription),
              );
            }),
          ],
        ],
      ),
    );
  }

  int _dayDifferenceFromToday(DateTime value, DateTime today) {
    return dayDifferenceFromToday(value, now: today);
  }

  String? _trialStatusText(Subscription subscription, DateTime today) {
    if (!subscription.isTrial) {
      return null;
    }
    return formatTrialStatusLabel(subscription.trialEndsAt, now: today);
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dateFmt = DateFormat('MMM d');
    final today = DateTime.now();

    return ObsidianCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (recentExpenses.isEmpty && recentSubscriptions.isEmpty)
            const Text('No recent activity yet')
          else ...[
            if (recentExpenses.isNotEmpty) ...[
              Text(
                'Latest expense',
                style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                '${recentExpenses.first.currency} ${numberFmt.format(recentExpenses.first.amount)} · ${dateFmt.format(recentExpenses.first.occurredAt)}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
            ],
            if (recentSubscriptions.isNotEmpty) ...[
              Text(
                'Next billing',
                style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                '${recentSubscriptions.first.name} · ${dateFmt.format(recentSubscriptions.first.nextBillingDate)}',
                style: theme.textTheme.bodyMedium,
              ),
              if (_trialStatusText(recentSubscriptions.first, today) != null) ...[
                const SizedBox(height: 2),
                Text(
                  _trialStatusText(recentSubscriptions.first, today)!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: recentSubscriptions.first.trialEndsAt != null &&
                            recentSubscriptions.first.trialEndsAt!.isBefore(today)
                        ? scheme.error
                        : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }

  String? _trialStatusText(Subscription subscription, DateTime today) {
    if (!subscription.isTrial) {
      return null;
    }
    return formatTrialStatusLabel(subscription.trialEndsAt, now: today);
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ObsidianCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(line, style: theme.textTheme.bodyMedium),
            ),
          ),
        ],
      ),
    );
  }
}

class _WindowSelector extends StatelessWidget {
  const _WindowSelector({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down, size: 16, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _UrgentAlert extends StatelessWidget {
  const _UrgentAlert({required this.overdueCount, required this.expiredTrialCount});
  final int overdueCount;
  final int expiredTrialCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 20, color: scheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${overdueCount > 0 ? '$overdueCount overdue billings' : ''}${overdueCount > 0 && expiredTrialCount > 0 ? ' & ' : ''}${expiredTrialCount > 0 ? '$expiredTrialCount expired trials' : ''}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
