import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
  final _dateFmt = DateFormat('MMM d, yyyy h:mm a');

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Log'),
        actions: [
          IconButton(
            tooltip: 'Clear activity log',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear activity log?'),
                  content: const Text(
                    'This removes all activity records for this account.',
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

              await ref.read(activityLogServiceProvider).clear();
              await _load(reset: true);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Activity log cleared.')),
              );
            },
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
                    ? 'No activity recorded yet.'
                    : 'Failed to load log: $_error',
              ),
            )
          : RefreshIndicator(
              onRefresh: () => _load(reset: true),
              child: ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: _entries.length + 1,
                separatorBuilder: (_, index) => index == _entries.length - 1
                    ? const SizedBox.shrink()
                    : const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  if (index == _entries.length) {
                    if (_loadingMore) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (!_hasMore) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: Text('End of activity log')),
                      );
                    }
                    return Center(
                      child: TextButton(
                        onPressed: () => _load(),
                        child: const Text('Load more'),
                      ),
                    );
                  }

                  final item = _entries[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.history),
                      title: Text(item.action),
                      subtitle: Text(
                        [
                          _dateFmt.format(item.timestamp.toLocal()),
                          if (item.details != null &&
                              item.details!.trim().isNotEmpty)
                            item.details!.trim(),
                        ].join(' · '),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
