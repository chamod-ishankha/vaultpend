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

                      return _SyncIncidentSummaryCard(
                        incidents: incidents,
                        dateFmt: _dateFmt,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  if (_loadingMore)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ..._entries.asMap().entries.map((mapped) {
                    final item = mapped.value;
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
              height: 100,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < daySlots.length; i++) ...[
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('${values[i]}'),
                          const SizedBox(height: 4),
                          Container(
                            width: 16,
                            height: peak == 0 ? 4 : 64 * (values[i] / peak),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(DateFormat('E').format(daySlots[i])),
                        ],
                      ),
                    ),
                    if (i != daySlots.length - 1) const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _CountChip(label: 'Category', counts: countByEntity),
                _CountChip(label: 'Operation', counts: countByOperation),
              ],
            ),
          ],
        ),
      ),
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
    final top = entries
        .take(3)
        .map((entry) => '${entry.key}: ${entry.value}')
        .join(' · ');

    return Chip(label: Text('$label $top'));
  }
}
