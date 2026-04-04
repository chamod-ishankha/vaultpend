import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/logging/activity_log_service.dart';
import '../../core/logging/app_logging.dart';

final activityLogListProvider =
    FutureProvider.autoDispose<List<ActivityLogEntry>>((ref) {
      return ref.watch(activityLogServiceProvider).readAll();
    });

class ActivityLogScreen extends ConsumerWidget {
  const ActivityLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(activityLogListProvider);
    final dateFmt = DateFormat('MMM d, yyyy h:mm a');

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
                    'This removes all local activity records.',
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
              ref.invalidate(activityLogListProvider);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Activity log cleared.')),
              );
            },
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: logsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load log: $error')),
        data: (logs) {
          if (logs.isEmpty) {
            return const Center(child: Text('No activity recorded yet.'));
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(activityLogListProvider);
              await ref.read(activityLogListProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: logs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = logs[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.history),
                    title: Text(item.action),
                    subtitle: Text(
                      [
                        dateFmt.format(item.timestamp.toLocal()),
                        if (item.details != null &&
                            item.details!.trim().isNotEmpty)
                          item.details!.trim(),
                      ].join(' · '),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
