import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../data/models/expense.dart';
import '../../data/models/subscription.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(insightsDataProvider);

    return Scaffold(
      appBar: AppBar(
        leading: onOpenDrawer != null
            ? IconButton(icon: const Icon(Icons.menu), onPressed: onOpenDrawer)
            : null,
        title: const Text('Insights'),
      ),
      body: async.when(
        data: (data) => _InsightsContent(data: data),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
      ),
    );
  }
}

enum _InsightsRange { sevenDays, thirtyDays, ninetyDays, all }

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

class _InsightsDashboard extends StatefulWidget {
  const _InsightsDashboard({required this.data});

  final _InsightsData data;

  @override
  State<_InsightsDashboard> createState() => _InsightsDashboardState();
}

class _InsightsDashboardState extends State<_InsightsDashboard> {
  _InsightsRange _range = _InsightsRange.thirtyDays;

  @override
  Widget build(BuildContext context) {
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

    final numberFmt = NumberFormat('#,##0.00');
    final trendPoints = _buildTrendPoints(filteredExpenses);
    final peakTrendValue = trendPoints.isEmpty
        ? 0.0
        : trendPoints.map((e) => e.amount).reduce((a, b) => a > b ? a : b);
    final monthComparison = _buildMonthComparison(widget.data.expenses);
    final increasingCurrencies = monthComparison.rows
        .where((row) => row.delta > 0)
        .length;

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
            _MetricItem(label: 'MoM Up', value: '$increasingCurrencies'),
          ],
        ),
        const SizedBox(height: 12),
        _TrendChartCard(
          title: _rangeTitle(),
          points: trendPoints,
          peakValue: peakTrendValue,
          numberFmt: numberFmt,
        ),
        const SizedBox(height: 12),
        _MonthOverMonthCard(comparison: monthComparison, numberFmt: numberFmt),
        const SizedBox(height: 12),
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
        const SizedBox(height: 12),
        _CurrencyBreakdownCard(
          title: 'Expense Currency Split',
          entries: expenseCurrencyEntries,
          numberFmt: numberFmt,
        ),
        const SizedBox(height: 12),
        _CategoryDistributionCard(
          title: 'Category Distribution',
          entries: categoryEntries,
          numberFmt: numberFmt,
        ),
        const SizedBox(height: 12),
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
        const SizedBox(height: 12),
        _CurrencyBreakdownCard(
          title: 'Subscription Currency Split',
          entries: subscriptionCurrencyEntries,
          numberFmt: numberFmt,
        ),
        const SizedBox(height: 12),
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
        const SizedBox(height: 12),
        _LargeSubscriptionsCard(
          subscriptions: largestSubscriptions,
          numberFmt: numberFmt,
        ),
        const SizedBox(height: 12),
        _RecentActivityCard(
          recentExpenses: recentExpenses,
          recentSubscriptions: recentSubscriptions,
          numberFmt: numberFmt,
        ),
        const SizedBox(height: 12),
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
    );
  }

  List<Expense> _filteredExpenses(List<Expense> expenses) {
    final now = DateTime.now();
    final start = switch (_range) {
      _InsightsRange.sevenDays => DateTime(now.year, now.month, now.day - 6),
      _InsightsRange.thirtyDays => DateTime(now.year, now.month, now.day - 29),
      _InsightsRange.ninetyDays => DateTime(now.year, now.month, now.day - 89),
      _InsightsRange.all => DateTime.fromMillisecondsSinceEpoch(0),
    };
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

  List<_TrendPoint> _buildTrendPoints(List<Expense> expenses) {
    if (expenses.isEmpty) {
      return const [];
    }

    final byDay = <DateTime, double>{};
    for (final expense in expenses) {
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

    final days = byDay.keys.toList()..sort();
    return [for (final day in days) _TrendPoint(day, byDay[day] ?? 0)];
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
    required this.numberFmt,
  });

  final String title;
  final List<_TrendPoint> points;
  final double peakValue;
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
            else
              SizedBox(
                height: 180,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final point in points) ...[
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              numberFmt.format(point.amount),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 120,
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                width: 18,
                                height: peakValue == 0
                                    ? 0
                                    : 120 * (point.amount / peakValue),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              DateFormat.MMMd().format(point.day),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _KeyMetricsStrip extends StatelessWidget {
  const _KeyMetricsStrip({required this.metrics});

  final List<_MetricItem> metrics;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final metric in metrics)
          _MetricTile(label: metric.label, value: metric.value),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.sizeOf(context).width - 48) / 2;
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
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
              const Text('No category spend yet')
            else
              ...entries
                  .take(6)
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  entry.key,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 8),
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
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
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
              ...entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            entry.key,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
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
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
              ...subscriptions
                  .take(5)
                  .map(
                    (subscription) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  subscription.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
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
                            'Next ${DateFormat.MMMd().format(subscription.nextBillingDate)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
          ],
        ),
      ),
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
    final dateFmt = DateFormat.yMMMd().add_jm();

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
              ],
            ],
          ],
        ),
      ),
    );
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
