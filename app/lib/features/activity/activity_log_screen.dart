import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/obsidian_app_bar.dart';
import '../../core/widgets/obsidian_button.dart';
import '../../core/widgets/obsidian_card.dart';
import '../../core/logging/activity_log_service.dart';
import '../../core/logging/app_logging.dart';

class ActivityLogScreen extends ConsumerStatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  ConsumerState<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends ConsumerState<ActivityLogScreen> {
  static const _pageSize = 25;
  final _scrollController = ScrollController();
  final _timeFmt = DateFormat('h:mm a');
  final _fullFmt = DateFormat('MMM d, yyyy h:mm a');

  final List<ActivityLogEntry> _entries = [];
  DateTime? _cursor;
  bool _hasMore = true;
  bool _loadingInitial = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
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
          .read(activityLogServiceProvider)
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

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Clear activity log?'),
        content: const Text(
          'This removes all activity records for this account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ObsidianButton(
            onPressed: () => Navigator.pop(ctx, true),
            text: 'Clear',
            style: ObsidianButtonStyle.primary,
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await ref.read(activityLogServiceProvider).clear();
    await _load(reset: true);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Activity log cleared.')));
  }

  Map<String, List<ActivityLogEntry>> _groupEntriesForTimeline() {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfYesterday = startOfToday.subtract(const Duration(days: 1));

    final today = <ActivityLogEntry>[];
    final yesterday = <ActivityLogEntry>[];
    final earlier = <ActivityLogEntry>[];

    for (final entry in _entries) {
      final local = entry.timestamp.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      if (day == startOfToday) {
        today.add(entry);
      } else if (day == startOfYesterday) {
        yesterday.add(entry);
      } else {
        earlier.add(entry);
      }
    }

    final grouped = <String, List<ActivityLogEntry>>{};
    if (today.isNotEmpty) {
      grouped['Today'] = today;
    }
    if (yesterday.isNotEmpty) {
      grouped['Yesterday'] = yesterday;
    }
    if (earlier.isNotEmpty) {
      grouped['Earlier'] = earlier;
    }
    return grouped;
  }

  String _formatTimelineStamp(DateTime timestamp) {
    final local = timestamp.toLocal();
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfTomorrow = startOfToday.add(const Duration(days: 1));
    final startOfYesterday = startOfToday.subtract(const Duration(days: 1));

    if (!local.isBefore(startOfToday) && local.isBefore(startOfTomorrow)) {
      return _timeFmt.format(local).toUpperCase();
    }
    if (!local.isBefore(startOfYesterday) && local.isBefore(startOfToday)) {
      return '${DateFormat('MMM d').format(local)} · ${_timeFmt.format(local).toUpperCase()}';
    }
    return _fullFmt.format(local);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final grouped = _groupEntriesForTimeline();

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: ObsidianAppBar(
        centerTitle: false,
        title: Text(
          'Activity Log',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => _load(reset: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Clear activity log',
            onPressed: _clearAll,
            icon: const Icon(Icons.delete_sweep_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => _load(reset: true),
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(
                12,
                14,
                12,
                110,
              ), // extra bottom padding for card
              children: [
                if (_loadingInitial)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 30),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_entries.isEmpty)
                  _ActivityLogEmptyState(error: _error)
                else ...[
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.errorContainer.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Could not refresh latest entries. Showing available records.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onErrorContainer,
                        ),
                      ),
                    ),
                  for (final group in grouped.entries) ...[
                    _TimelineGroupHeader(label: group.key),
                    const SizedBox(height: 10),
                    ...group.value.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ActivityTimelineCard(
                          entry: entry,
                          stamp: _formatTimelineStamp(entry.timestamp),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                ],
                if (!_loadingInitial)
                  if (_loadingMore)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_hasMore)
                    Center(
                      child: TextButton(
                        onPressed: () => _load(),
                        child: const Text('Load older activity'),
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Center(child: Text('End of activity log')),
                    ),
                if (!_loadingInitial) const SizedBox(height: 8),
                // Data Retention card moved out of scroll area
              ],
            ),
          ),
          if (!_loadingInitial)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _ActivityRetentionCard(),
              ),
            ),
        ],
      ),
    );
  }
}

class _TimelineGroupHeader extends StatelessWidget {
  const _TimelineGroupHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Divider(
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: scheme.outline,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ],
    );
  }
}

class _ActivityTimelineCard extends StatelessWidget {
  const _ActivityTimelineCard({required this.entry, required this.stamp});

  final ActivityLogEntry entry;
  final String stamp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final visual = _describeActivity(context, entry.action);
    final details = entry.details?.trim();
    final description = (details == null || details.isEmpty)
        ? 'No additional details recorded.'
        : details;
    final amountChip = _extractAmountChip(details);

    return ObsidianCard(
      level: ObsidianCardTonalLevel.low,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: visual.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(visual.icon, color: visual.foreground, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        entry.action,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      stamp,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.outline,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                if (amountChip != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      amountChip,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityLogEmptyState extends StatelessWidget {
  const _ActivityLogEmptyState({required this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            'Failed to load log: $error',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 34),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.surfaceContainerLowest,
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                color: scheme.outline,
                size: 42,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No activity recorded yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your vault history will appear here once you start managing your finances.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityRetentionCard extends StatelessWidget {
  const _ActivityRetentionCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      height: 126,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.03)),
        gradient: LinearGradient(
          colors: [scheme.surfaceContainerLow, scheme.surfaceContainerLowest],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -60,
            bottom: -60,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primary.withValues(alpha: 0.05),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.14),
                    blurRadius: 64,
                    spreadRadius: 8,
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final shieldSize = constraints.maxHeight * 0.65;
                  final lockSize = shieldSize * 0.45;
                  return Align(
                    alignment: Alignment.centerRight,
                    child: Transform.translate(
                      offset: const Offset(-9, 3),
                      child: Transform.rotate(
                        angle: 0.2,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              Icons.shield,
                              size: shieldSize,
                              color: scheme.primary.withAlpha(77), // alpha: 0.3
                            ),
                            Icon(
                              Icons.lock,
                              size: lockSize,
                              color: scheme.primary.withAlpha(120),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 92, 18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Data Retention',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Logs are automatically encrypted and stored for 90 days for your security.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityVisualDescriptor {
  const _ActivityVisualDescriptor({
    required this.icon,
    required this.foreground,
    required this.background,
  });

  final IconData icon;
  final Color foreground;
  final Color background;
}

_ActivityVisualDescriptor _describeActivity(
  BuildContext context,
  String action,
) {
  final scheme = Theme.of(context).colorScheme;
  final normalized = action.toLowerCase();

  if (normalized.contains('expense')) {
    return _ActivityVisualDescriptor(
      icon: Icons.receipt_long_rounded,
      foreground: scheme.primary,
      background: scheme.primary.withValues(alpha: 0.15),
    );
  }
  if (normalized.contains('subscription')) {
    return _ActivityVisualDescriptor(
      icon: Icons.subscriptions_rounded,
      foreground: scheme.secondary,
      background: scheme.secondaryContainer.withValues(alpha: 0.32),
    );
  }
  if (normalized.contains('category')) {
    return _ActivityVisualDescriptor(
      icon: Icons.category_rounded,
      foreground: scheme.tertiary,
      background: scheme.tertiaryContainer.withValues(alpha: 0.35),
    );
  }
  if (normalized.contains('export') || normalized.contains('report')) {
    return _ActivityVisualDescriptor(
      icon: Icons.history_rounded,
      foreground: scheme.error,
      background: scheme.errorContainer.withValues(alpha: 0.35),
    );
  }
  return _ActivityVisualDescriptor(
    icon: Icons.history_rounded,
    foreground: scheme.primary,
    background: scheme.primaryContainer.withValues(alpha: 0.32),
  );
}

String? _extractAmountChip(String? details) {
  if (details == null || details.trim().isEmpty) {
    return null;
  }
  final match = RegExp(r'[-+]?\$\d+(?:\.\d{2})?').firstMatch(details);
  return match?.group(0);
}
