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
import '../../data/models/expense.dart';
import '../../data/models/subscription.dart';
import '../auth/auth_providers.dart';
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: false,
      appBar: ObsidianAppBar(
        centerTitle: false,
        title: Text(
          'Insights',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        leading: onOpenDrawer != null
            ? IconButton(icon: const Icon(Icons.menu), onPressed: onOpenDrawer)
            : null,
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Export',
            icon: const Icon(Icons.ios_share_rounded),
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
                    Icon(Icons.table_chart_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Export as CSV'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Export as PDF'),
                  ],
                ),
              ),
            ],
          ),
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
              color: scheme.surfaceContainerLow,
            ),
            child: Icon(Icons.person, size: 18, color: scheme.primary),
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
    final bottomPadding = math.max(
      120.0,
      MediaQuery.paddingOf(context).bottom + kBottomNavigationBarHeight + 24,
    );
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
    final today = DateTime(now.year, now.month, now.day);
    final upcomingSubscriptions =
        effectiveSubscriptions
            .where(
              (subscription) => !DateTime(
                subscription.nextBillingDate.year,
                subscription.nextBillingDate.month,
                subscription.nextBillingDate.day,
              ).isBefore(today),
            )
            .toList()
          ..sort((a, b) => a.nextBillingDate.compareTo(b.nextBillingDate));
    final overdueSubscriptions =
        effectiveSubscriptions
            .where(
              (subscription) => DateTime(
                subscription.nextBillingDate.year,
                subscription.nextBillingDate.month,
                subscription.nextBillingDate.day,
              ).isBefore(today),
            )
            .toList()
          ..sort((a, b) => b.nextBillingDate.compareTo(a.nextBillingDate));
    final recentSubscriptions = [
      ...upcomingSubscriptions,
      ...overdueSubscriptions,
    ];
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
          title: 'Top Categories (${_rangeTitle()})',
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
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding),
      children: [
        ObsidianCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ControlSectionLabel(
                icon: Icons.tune_rounded,
                label: 'Report View',
              ),
              const SizedBox(height: 8),
              _ReportViewSelector(
                value: _reportView,
                onChanged: (value) => unawaited(_setReportView(value)),
              ),
              const SizedBox(height: 14),
              const _ControlSectionLabel(
                icon: Icons.date_range_rounded,
                label: 'Date Range',
              ),
              const SizedBox(height: 8),
              _RangeSelector(
                value: _range,
                onChanged: (value) => setState(() => _range = value),
              ),
            ],
          ),
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
        (lower.contains('bi-') ||
            lower.contains('biweek') ||
            lower.contains('bi week'))) {
      return 'Bi-weekly';
    }
    if (lower.contains('fortnight')) {
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
    if (lower.contains('bi-week') ||
        lower.contains('biweek') ||
        lower.contains('bi week') ||
        lower.contains('fortnight')) {
      return amount * 2.17;
    }
    if (lower.contains('week')) {
      return amount * 4.33;
    }
    if (lower.contains('day')) {
      return amount * 30;
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

class _ControlSectionLabel extends StatelessWidget {
  const _ControlSectionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: scheme.primary),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.value, required this.onChanged});

  final _InsightsRange value;
  final ValueChanged<_InsightsRange> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final options = <(_InsightsRange, String)>[
      (_InsightsRange.sevenDays, '7D'),
      (_InsightsRange.thirtyDays, '30D'),
      (_InsightsRange.ninetyDays, '90D'),
      (_InsightsRange.all, 'All'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final option in options)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _SegmentPill(
                          label: option.$2,
                          selected: value == option.$1,
                          onPressed: () => onChanged(option.$1),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ReportViewSelector extends StatelessWidget {
  const _ReportViewSelector({required this.value, required this.onChanged});

  final _InsightsReportView value;
  final ValueChanged<_InsightsReportView> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final options = <({_InsightsReportView view, String label, IconData icon})>[
      (
        view: _InsightsReportView.overview,
        label: 'Overview',
        icon: Icons.dashboard_outlined,
      ),
      (
        view: _InsightsReportView.spendingFocus,
        label: 'Spending',
        icon: Icons.paid_outlined,
      ),
      (
        view: _InsightsReportView.subscriptionFocus,
        label: 'Subscriptions',
        icon: Icons.subscriptions_outlined,
      ),
      (
        view: _InsightsReportView.billingWatch,
        label: 'Billing',
        icon: Icons.calendar_month_outlined,
      ),
      (
        view: _InsightsReportView.currencyBreakdown,
        label: 'Currency',
        icon: Icons.currency_exchange,
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final option in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () => onChanged(option.view),
                borderRadius: BorderRadius.circular(999),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: value == option.view
                        ? scheme.secondaryContainer
                        : scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: value == option.view
                          ? scheme.secondary.withValues(alpha: 0.45)
                          : scheme.outlineVariant.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        option.icon,
                        size: 14,
                        color: value == option.view
                            ? scheme.onSecondaryContainer
                            : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        option.label,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: value == option.view
                              ? scheme.onSecondaryContainer
                              : scheme.onSurfaceVariant,
                          fontWeight: value == option.view
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SegmentPill extends StatelessWidget {
  const _SegmentPill({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? scheme.primary.withValues(alpha: 0.28)
                : Colors.transparent,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.12),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: selected
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
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
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Daily spend trend',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          if (points.isEmpty)
            const Text('No trend data yet')
          else ...[
            Text(
              _formatTrendHeadline(numberFmt, points.last.amount, valueSuffix),
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
                  fillColor: scheme.primary.withValues(alpha: 0.1),
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

  String _formatTrendHeadline(
    NumberFormat formatter,
    double amount,
    String? suffix,
  ) {
    final formattedAmount = formatter.format(amount);
    if (suffix == null || suffix.isEmpty) {
      return formattedAmount;
    }
    return '$formattedAmount $suffix';
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: metrics.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final metric = metrics[index];
          return Container(
            width: 154,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.25),
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 2,
                    color: scheme.primary.withValues(alpha: 0.28),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _iconForLabel(metric.label),
                            size: 14,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              metric.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        metric.value,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  IconData _iconForLabel(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('expense')) return Icons.paid_outlined;
    if (lower.contains('category')) return Icons.category_outlined;
    if (lower.contains('subscription')) return Icons.subscriptions_outlined;
    if (lower.contains('trial')) return Icons.hourglass_bottom_outlined;
    if (lower.contains('mom')) return Icons.trending_up_rounded;
    return Icons.insights_outlined;
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
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
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
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
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
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
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
                        Text('Total', style: theme.textTheme.labelLarge),
                        Text(
                          numberFmt.format(total),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
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
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
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
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
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
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
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
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
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
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (subscription.isTrial) ...[
                            const SizedBox(height: 4),
                            Text(
                              trialStatus ?? 'Trial',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color:
                                    subscription.trialEndsAt != null &&
                                        subscription.trialEndsAt!.isBefore(
                                          today,
                                        )
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
    required this.window,
    required this.onWindowChanged,
    required this.onSubscriptionTap,
    required this.numberFmt,
  });

  final List<Subscription> subscriptions;
  final Map<String, double> totalsByCurrency;
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
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
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
                    color:
                        (subscription.isTrial
                                ? scheme.tertiary
                                : urgent
                                ? scheme.error
                                : scheme.primary)
                            .withValues(alpha: 0.1),
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
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
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
                    : Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
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
    final nextSubscription = recentSubscriptions.isEmpty
        ? null
        : recentSubscriptions.first;
    final nextBillingDays = nextSubscription == null
        ? null
        : dayDifferenceFromToday(nextSubscription.nextBillingDate, now: today);
    final nextBillingLabel = switch (nextBillingDays) {
      null => 'Next billing',
      < 0 => 'Billing overdue',
      _ => 'Next billing',
    };

    return ObsidianCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (recentExpenses.isEmpty && recentSubscriptions.isEmpty)
            const Text('No recent activity yet')
          else ...[
            if (recentExpenses.isNotEmpty) ...[
              Text(
                'Latest expense',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
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
                nextBillingLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: nextBillingDays != null && nextBillingDays < 0
                      ? scheme.error
                      : null,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${recentSubscriptions.first.name} · ${dateFmt.format(recentSubscriptions.first.nextBillingDate)}',
                style: theme.textTheme.bodyMedium,
              ),
              if (_trialStatusText(recentSubscriptions.first, today) !=
                  null) ...[
                const SizedBox(height: 2),
                Text(
                  _trialStatusText(recentSubscriptions.first, today)!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color:
                        recentSubscriptions.first.trialEndsAt != null &&
                            recentSubscriptions.first.trialEndsAt!.isBefore(
                              today,
                            )
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
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
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
  const _UrgentAlert({
    required this.overdueCount,
    required this.expiredTrialCount,
  });
  final int overdueCount;
  final int expiredTrialCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.error.withValues(alpha: 0.3)),
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
