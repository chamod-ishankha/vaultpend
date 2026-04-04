import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/logging/app_logging.dart';
import '../../core/logging/sync_incident_service.dart';

class SyncIncidentScreen extends ConsumerStatefulWidget {
  const SyncIncidentScreen({super.key});

  @override
  ConsumerState<SyncIncidentScreen> createState() => _SyncIncidentScreenState();
}

class _SyncIncidentScreenState extends ConsumerState<SyncIncidentScreen> {
  static const _pageSize = 25;
  final _scrollController = ScrollController();
  final _dateFmt = DateFormat('MMM d, yyyy h:mm a');

  final List<SyncIncidentEntry> _entries = [];
  late Future<List<SyncIncidentEntry>> _summaryFuture;
  DateTime? _cursor;
  bool _hasMore = true;
  bool _loadingInitial = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _summaryFuture = _loadSummary();
    _load(reset: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loadingInitial) {
      return;
    }
    if (_scrollController.position.extentAfter < 280) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (_loadingMore || _loadingInitial && !reset) {
      return;
    }

    if (reset) {
      setState(() {
        _loadingInitial = true;
        _loadingMore = false;
        _error = null;
        _cursor = null;
        _hasMore = true;
        _entries.clear();
      });
    } else {
      setState(() {
        _loadingMore = true;
        _error = null;
      });
    }

    try {
      final page = await ref
          .read(syncIncidentServiceProvider)
          .readPage(pageSize: _pageSize, startAfter: reset ? null : _cursor);

      if (!mounted) return;
      setState(() {
        _entries.addAll(page.entries);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingInitial = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<List<SyncIncidentEntry>> _loadSummary() async {
    try {
      return await ref.read(syncIncidentServiceProvider).readAll();
    } catch (_) {
      return const <SyncIncidentEntry>[];
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear sync incidents?'),
        content: const Text(
          'This removes all recorded sync incidents for this account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await ref.read(syncIncidentServiceProvider).clear();
    _summaryFuture = _loadSummary();
    await _load(reset: true);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Sync incidents cleared.')));
  }

  @override
  Widget build(BuildContext context) {
    final summaryFuture = _summaryFuture;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Incidents'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => _load(reset: true),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Clear incidents',
            onPressed: _clearAll,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: _loadingInitial
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
          ? Center(
              child: Text(
                _error == null
                    ? 'No sync incidents recorded.'
                    : 'Failed to load incidents: $_error',
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                _summaryFuture = _loadSummary();
                await _load(reset: true);
              },
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                children: [
                  FutureBuilder<List<SyncIncidentEntry>>(
                    future: summaryFuture,
                    builder: (context, snapshot) {
                      final incidents =
                          snapshot.data ?? const <SyncIncidentEntry>[];
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          incidents.isEmpty) {
                        return const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        );
                      }

                      if (incidents.isEmpty) {
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              _error == null
                                  ? 'No sync incidents recorded.'
                                  : 'Failed to load incidents: $_error',
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: [
                          _SyncIncidentSummaryCard(
                            incidents: incidents,
                            dateFmt: _dateFmt,
                          ),
                          const SizedBox(height: 12),
                          _EntityTrendSummaryCard(incidents: incidents),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  if (_loadingMore)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ..._entries.map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: ListTile(
                          leading: const Icon(Icons.sync_problem_outlined),
                          title: Text(
                            '${item.entity} ${item.operation} failed',
                          ),
                          subtitle: Text(
                            '${_dateFmt.format(item.timestamp.toLocal())}\nStage: ${item.stage}\nError: ${item.error}',
                          ),
                        ),
                      ),
                    );
                  }),
                  if (_hasMore)
                    Center(
                      child: TextButton(
                        onPressed: _loadingMore ? null : () => _load(),
                        child: const Text('Load more'),
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: Text('End of incidents')),
                    ),
                ],
              ),
            ),
    );
  }
}

class _SyncIncidentSummaryCard extends StatelessWidget {
  const _SyncIncidentSummaryCard({
    required this.incidents,
    required this.dateFmt,
  });

  final List<SyncIncidentEntry> incidents;
  final DateFormat dateFmt;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));
    final daySlots = <DateTime>[
      for (var i = 0; i < 7; i++) start.add(Duration(days: i)),
    ];

    final countByDay = <DateTime, int>{for (final day in daySlots) day: 0};
    final countByEntity = <String, int>{};
    final countByOperation = <String, int>{};
    for (final incident in incidents) {
      final day = DateTime(
        incident.timestamp.year,
        incident.timestamp.month,
        incident.timestamp.day,
      );
      if (countByDay.containsKey(day)) {
        countByDay.update(day, (value) => value + 1);
      }
      countByEntity.update(
        incident.entity,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
      countByOperation.update(
        incident.operation,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    final values = [for (final day in daySlots) countByDay[day] ?? 0];
    final peak = values.fold<int>(0, (max, value) => value > max ? value : max);
    final latest = incidents.first;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Incident summary',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text('Total incidents: ${incidents.length}'),
            Text('Latest: ${dateFmt.format(latest.timestamp.toLocal())}'),
            const SizedBox(height: 12),
            SizedBox(
              height: 88,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < daySlots.length; i++) ...[
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '${values[i]}',
                            style: Theme.of(context).textTheme.labelSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Container(
                            width: 14,
                            height: peak == 0 ? 4 : 42 * (values[i] / peak),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('E').format(daySlots[i]),
                            style: Theme.of(context).textTheme.labelSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (i != daySlots.length - 1) const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            _CountChip(label: 'Entity', counts: countByEntity),
            const SizedBox(height: 8),
            _CountChip(label: 'Operation', counts: countByOperation),
          ],
        ),
      ),
    );
  }
}

class _EntityTrendSummaryCard extends StatelessWidget {
  const _EntityTrendSummaryCard({required this.incidents});

  final List<SyncIncidentEntry> incidents;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));
    final daySlots = <DateTime>[
      for (var i = 0; i < 7; i++) start.add(Duration(days: i)),
    ];

    const entityOrder = ['category', 'expense', 'subscription'];
    const entityLabels = <String, String>{
      'category': 'Categories',
      'expense': 'Expenses',
      'subscription': 'Subscriptions',
    };

    final countByEntity = <String, int>{};
    final countByOperation = <String, int>{};
    final countByStage = <String, int>{};
    final trendByEntity = <String, Map<DateTime, int>>{};
    final latestByEntity = <String, DateTime>{};

    for (final incident in incidents) {
      countByEntity.update(
        incident.entity,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
      countByOperation.update(
        incident.operation,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
      countByStage.update(
        incident.stage,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
      latestByEntity.update(
        incident.entity,
        (value) =>
            incident.timestamp.isAfter(value) ? incident.timestamp : value,
        ifAbsent: () => incident.timestamp,
      );

      final day = DateTime(
        incident.timestamp.year,
        incident.timestamp.month,
        incident.timestamp.day,
      );
      if (!daySlots.contains(day)) {
        continue;
      }
      final entityTrend = trendByEntity.putIfAbsent(incident.entity, () => {});
      entityTrend.update(day, (value) => value + 1, ifAbsent: () => 1);
    }

    final total = incidents.length;
    final topEntity = countByEntity.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topOperation = countByOperation.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topStage = countByStage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final displayEntities = entityOrder
        .where(countByEntity.containsKey)
        .toList();
    for (final entity in countByEntity.keys) {
      if (!displayEntities.contains(entity)) {
        displayEntities.add(entity);
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Entity conflict trends',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text('Total incidents: $total'),
            Text('Tracked entities: ${countByEntity.length}'),
            if (topEntity.isNotEmpty)
              Text(
                'Most affected: ${topEntity.first.key} (${topEntity.first.value})',
              ),
            if (topOperation.isNotEmpty)
              Text(
                'Top operation: ${topOperation.first.key} (${topOperation.first.value})',
              ),
            if (topStage.isNotEmpty)
              Text(
                'Top stage: ${topStage.first.key} (${topStage.first.value})',
              ),
            const SizedBox(height: 12),
            for (final entity in displayEntities) ...[
              _EntityTrendRow(
                label: entityLabels[entity] ?? entity,
                count: countByEntity[entity] ?? 0,
                days: daySlots,
                dayCounts: trendByEntity[entity] ?? const {},
                latest: latestByEntity[entity],
              ),
              const SizedBox(height: 10),
            ],
            _CountChip(label: 'Stage', counts: countByStage),
            const SizedBox(height: 8),
            _CountChip(label: 'Operation', counts: countByOperation),
          ],
        ),
      ),
    );
  }
}

class _EntityTrendRow extends StatelessWidget {
  const _EntityTrendRow({
    required this.label,
    required this.count,
    required this.days,
    required this.dayCounts,
    required this.latest,
  });

  final String label;
  final int count;
  final List<DateTime> days;
  final Map<DateTime, int> dayCounts;
  final DateTime? latest;

  @override
  Widget build(BuildContext context) {
    final peak = days.fold<int>(0, (max, day) {
      final value = dayCounts[day] ?? 0;
      return value > max ? value : max;
    });
    final lastSeen = latest == null
        ? 'never'
        : DateFormat('MMM d, h:mm a').format(latest!.toLocal());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$label · $count incidents',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              'Last: $lastSeen',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 78,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < days.length; i++) ...[
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${dayCounts[days[i]] ?? 0}',
                        style: Theme.of(context).textTheme.labelSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Container(
                        width: 14,
                        height: peak == 0
                            ? 4
                            : 36 * ((dayCounts[days[i]] ?? 0) / peak),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.tertiary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('E').format(days[i]),
                        style: Theme.of(context).textTheme.labelSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (i != days.length - 1) const SizedBox(width: 6),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label, required this.counts});

  final String label;
  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            Text('No data yet', style: Theme.of(context).textTheme.bodySmall)
          else
            Column(
              children: entries
                  .take(4)
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _formatKey(entry.key),
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${entry.value}',
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

String _formatKey(String value) {
  return value
      .split('_')
      .where((part) => part.isNotEmpty)
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');
}
