import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/obsidian_app_bar.dart';
import '../../core/widgets/obsidian_button.dart';
import '../../core/widgets/obsidian_card.dart';
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
  final _incidentStampFmt = DateFormat('MMM d, yyyy • HH:mm:ss');

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
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Clear sync incidents?'),
        content: const Text(
          'This removes all recorded sync incidents for this account.',
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final summaryFuture = _summaryFuture;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: ObsidianAppBar(
        centerTitle: false,
        title: Text(
          'Sync Incidents',
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
            tooltip: 'Clear incidents',
            onPressed: _clearAll,
            icon: const Icon(Icons.delete_sweep_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _summaryFuture = _loadSummary();
          await _load(reset: true);
        },
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 18),
          children: [
            FutureBuilder<List<SyncIncidentEntry>>(
              future: summaryFuture,
              builder: (context, snapshot) {
                final allIncidents =
                    snapshot.data ?? const <SyncIncidentEntry>[];
                final status = _buildIncidentStatus(allIncidents);

                if (snapshot.connectionState == ConnectionState.waiting &&
                    allIncidents.isEmpty &&
                    _loadingInitial) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                return _CurrentStatusCard(
                  status: status,
                  recentCriticalCount: _countRecentCriticalIncidents(
                    allIncidents,
                  ),
                  hasData: allIncidents.isNotEmpty,
                );
              },
            ),
            const SizedBox(height: 18),
            _SectionLabel(
              icon: Icons.sync_problem_rounded,
              text: 'Recent Failures',
              trailingText: 'Sort: Newest First',
            ),
            const SizedBox(height: 10),
            if (_loadingInitial)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 22),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_entries.isEmpty)
              ObsidianCard(
                level: ObsidianCardTonalLevel.low,
                child: Text(
                  _error == null
                      ? 'No sync incidents recorded.'
                      : 'Failed to load incidents: $_error',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              Column(
                children: _entries
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _FailureIncidentCard(
                          entry: item,
                          dateFmt: _incidentStampFmt,
                        ),
                      ),
                    )
                    .toList(),
              ),
            if (_loadingMore)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_hasMore)
              Center(
                child: TextButton(
                  onPressed: _loadingMore ? null : () => _load(),
                  child: const Text('Load older incidents'),
                ),
              ),
            const SizedBox(height: 8),
            ObsidianButton(
              onPressed: () => _load(reset: true),
              text: 'Refresh Incident Log',
              style: ObsidianButtonStyle.primary,
            ),
            const SizedBox(height: 10),
            Text(
              'Logs are retained for 30 days. Contact VaultSpend Infrastructure for detailed forensics.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  _IncidentStatus _buildIncidentStatus(List<SyncIncidentEntry> incidents) {
    if (incidents.isEmpty) {
      return const _IncidentStatus(
        title: 'Syncing Healthy',
        description:
            'No sync failures detected in the current retention window.',
        icon: Icons.cloud_done_rounded,
        severity: _IncidentStatusSeverity.healthy,
      );
    }

    final critical24h = _countRecentCriticalIncidents(incidents);
    if (critical24h > 0) {
      return _IncidentStatus(
        title: 'Syncing Suspended',
        description:
            '$critical24h critical authentication failures detected in the last 24 hours. Manual intervention required.',
        icon: Icons.cloud_off_rounded,
        severity: _IncidentStatusSeverity.critical,
      );
    }

    return const _IncidentStatus(
      title: 'Syncing Degraded',
      description:
          'Recent sync incidents were detected. Monitoring and retry systems are active.',
      icon: Icons.cloud_queue_rounded,
      severity: _IncidentStatusSeverity.warning,
    );
  }

  int _countRecentCriticalIncidents(List<SyncIncidentEntry> incidents) {
    final threshold = DateTime.now().subtract(const Duration(hours: 24));
    return incidents.where((incident) {
      if (incident.timestamp.isBefore(threshold)) {
        return false;
      }
      final normalized =
          '${incident.stage} ${incident.operation} ${incident.error}'
              .toLowerCase();
      return normalized.contains('auth') ||
          normalized.contains('unauthorized') ||
          normalized.contains('token');
    }).length;
  }
}

class _CurrentStatusCard extends StatelessWidget {
  const _CurrentStatusCard({
    required this.status,
    required this.recentCriticalCount,
    required this.hasData,
  });

  final _IncidentStatus status;
  final int recentCriticalCount;
  final bool hasData;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final (accent, chipBackground, chipForeground) = switch (status.severity) {
      _IncidentStatusSeverity.healthy => (
        scheme.primary,
        scheme.primaryContainer.withValues(alpha: 0.55),
        scheme.onPrimaryContainer,
      ),
      _IncidentStatusSeverity.warning => (
        scheme.tertiary,
        scheme.tertiaryContainer.withValues(alpha: 0.65),
        scheme.onTertiaryContainer,
      ),
      _IncidentStatusSeverity.critical => (
        scheme.error,
        scheme.errorContainer.withValues(alpha: 0.78),
        scheme.onErrorContainer,
      ),
    };

    return ObsidianCard(
      level: ObsidianCardTonalLevel.high,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(icon: status.icon, text: 'Current Status'),
          const SizedBox(height: 14),
          Text(
            status.title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            status.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: chipBackground,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  hasData
                      ? '$recentCriticalCount critical / 24h'
                      : 'No active incidents',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: chipForeground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FailureIncidentCard extends StatelessWidget {
  const _FailureIncidentCard({required this.entry, required this.dateFmt});

  final SyncIncidentEntry entry;
  final DateFormat dateFmt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final incidentTitle = _buildIncidentTitle(entry);
    final incidentIcon = _iconForIncident(entry);
    final metaLabel = _metaLabelForIncident(entry);

    return ObsidianCard(
      level: ObsidianCardTonalLevel.low,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(incidentIcon, color: scheme.error),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  incidentTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'ID: #SYN-${entry.id}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            entry.error,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  dateFmt.format(entry.timestamp.toLocal()).toUpperCase(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                metaLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.icon,
    required this.text,
    this.trailingText,
  });

  final IconData icon;
  final String text;
  final String? trailingText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (trailingText != null)
          Text(
            trailingText!,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

enum _IncidentStatusSeverity { healthy, warning, critical }

class _IncidentStatus {
  const _IncidentStatus({
    required this.title,
    required this.description,
    required this.icon,
    required this.severity,
  });

  final String title;
  final String description;
  final IconData icon;
  final _IncidentStatusSeverity severity;
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

String _buildIncidentTitle(SyncIncidentEntry entry) {
  final normalized = '${entry.operation} ${entry.stage} ${entry.error}'
      .toLowerCase();
  if (normalized.contains('auth') || normalized.contains('unauthorized')) {
    return 'API Authentication failed';
  }
  if (normalized.contains('timeout') || normalized.contains('network')) {
    return 'Connection timed out';
  }
  if (normalized.contains('decrypt') || normalized.contains('hash')) {
    return 'Decryption Error';
  }
  if (normalized.contains('storage') || normalized.contains('quota')) {
    return 'Remote Storage Full';
  }
  return '${_formatKey(entry.entity)} ${_formatKey(entry.operation)} failed';
}

String _metaLabelForIncident(SyncIncidentEntry entry) {
  final normalized = '${entry.operation} ${entry.stage} ${entry.error}'
      .toLowerCase();
  if (normalized.contains('auth')) {
    return '401 Unauthorized';
  }
  if (normalized.contains('network') || normalized.contains('timeout')) {
    return 'Network: TLS 1.3';
  }
  if (normalized.contains('decrypt') || normalized.contains('hash')) {
    return 'Integrity: FAIL';
  }
  if (normalized.contains('storage') || normalized.contains('quota')) {
    return 'Storage: Quota';
  }
  return 'Stage: ${_formatKey(entry.stage)}';
}

IconData _iconForIncident(SyncIncidentEntry entry) {
  final normalized = '${entry.operation} ${entry.stage} ${entry.error}'
      .toLowerCase();
  if (normalized.contains('auth')) {
    return Icons.lock_person_rounded;
  }
  if (normalized.contains('network') || normalized.contains('timeout')) {
    return Icons.cloud_off_rounded;
  }
  if (normalized.contains('decrypt') || normalized.contains('hash')) {
    return Icons.shield_outlined;
  }
  if (normalized.contains('storage') || normalized.contains('quota')) {
    return Icons.storage_rounded;
  }
  return Icons.sync_problem_rounded;
}
