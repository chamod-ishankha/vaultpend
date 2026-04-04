import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/export/subscription_csv_export_service.dart';
import '../../core/export/subscription_pdf_export_service.dart';
import '../../core/fx/fx_providers.dart';
import '../../core/logging/app_logging.dart';
import '../../core/providers.dart';
import '../../core/widgets/fx_reference_strip.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../data/models/subscription.dart';
import 'add_subscription_screen.dart';
import 'subscription_providers.dart';

class SubscriptionListScreen extends ConsumerStatefulWidget {
  const SubscriptionListScreen({super.key, this.onOpenDrawer});

  final VoidCallback? onOpenDrawer;

  @override
  ConsumerState<SubscriptionListScreen> createState() =>
      _SubscriptionListScreenState();
}

class _SubscriptionListScreenState
    extends ConsumerState<SubscriptionListScreen> {
  static const _csvExportService = SubscriptionCsvExportService();
  static const _pdfExportService = SubscriptionPdfExportService();

  Future<void> _openEditor(
    BuildContext context, {
    Subscription? subscription,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AddSubscriptionScreen(subscription: subscription),
      ),
    );
  }

  Future<void> _onRefresh(WidgetRef ref) async {
    ref.invalidate(subscriptionListProvider);
    ref.invalidate(fxRatesProvider);
    await Future.wait([
      ref.read(subscriptionListProvider.future),
      ref.read(fxRatesProvider.future),
    ]);
  }

  Future<void> _exportSubscriptionsCsv(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final logger = ref.read(appLoggerProvider);
    logger.info('subscription_csv_export_started');
    try {
      final subscriptions = await ref.read(subscriptionListProvider.future);
      if (subscriptions.isEmpty) {
        logger.info('subscription_csv_export_skipped_no_data');
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No subscriptions to export yet.')),
        );
        return;
      }

      final csv = _csvExportService.buildCsv(subscriptions: subscriptions);
      final stamp = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
      final filename = 'vaultspend_subscriptions_$stamp.csv';
      final bytes = Uint8List.fromList(utf8.encode(csv));

      await SharePlus.instance.share(
        ShareParams(
          subject: 'VaultSpend subscriptions export',
          text: 'VaultSpend subscriptions CSV export',
          files: [XFile.fromData(bytes, mimeType: 'text/csv', name: filename)],
        ),
      );

      logger.info('subscription_csv_export_succeeded');

      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('CSV export prepared: $filename')));
    } catch (error, stack) {
      logger.warning('subscription_csv_export_failed', error, stack);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('CSV export failed: $error')));
    }
  }

  Future<void> _exportSubscriptionsPdf(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final logger = ref.read(appLoggerProvider);
    logger.info('subscription_pdf_export_started');
    try {
      final subscriptions = await ref.read(subscriptionListProvider.future);
      if (subscriptions.isEmpty) {
        logger.info('subscription_pdf_export_skipped_no_data');
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No subscriptions to export yet.')),
        );
        return;
      }

      final pdfDoc = await _pdfExportService.buildPdf(
        subscriptions: subscriptions,
      );
      final stamp = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
      final filename = 'vaultspend_subscriptions_$stamp.pdf';
      final bytes = await pdfDoc.save();

      await SharePlus.instance.share(
        ShareParams(
          subject: 'VaultSpend subscriptions report',
          text: 'VaultSpend subscriptions PDF report',
          files: [
            XFile.fromData(bytes, mimeType: 'application/pdf', name: filename),
          ],
        ),
      );

      logger.info('subscription_pdf_export_succeeded');

      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF export prepared: $filename')));
    } catch (error, stack) {
      logger.warning('subscription_pdf_export_failed', error, stack);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF export failed: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(subscriptionListProvider);
    final currencyFormat = NumberFormat.currency(symbol: '');
    final dateFmt = DateFormat('MMM d, yyyy h:mm a');
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        leading: widget.onOpenDrawer != null
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: widget.onOpenDrawer,
              )
            : null,
        title: const Text('Subscriptions'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Export',
            icon: const Icon(Icons.download_outlined),
            onSelected: (value) {
              if (value == 'csv') {
                _exportSubscriptionsCsv(context, ref);
              } else if (value == 'pdf') {
                _exportSubscriptionsPdf(context, ref);
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'csv',
                child: Row(
                  children: [
                    Icon(Icons.table_chart, size: 18),
                    SizedBox(width: 8),
                    Text('Export as CSV'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FxReferenceStrip(),
            Expanded(
              child: async.when(
                data: (items) {
                  if (items.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: () => _onRefresh(ref),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.sizeOf(context).height * 0.25,
                          ),
                          Center(
                            child: Text(
                              'No subscriptions yet.\nTap + to track one.\nPull down to refresh.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final sortedItems = [...items]
                    ..sort((left, right) {
                      if (left.isTrial != right.isTrial) {
                        return left.isTrial ? -1 : 1;
                      }

                      final leftEnds = left.trialEndsAt;
                      final rightEnds = right.trialEndsAt;
                      if (left.isTrial && right.isTrial) {
                        if (leftEnds == null && rightEnds == null) return 0;
                        if (leftEnds == null) return 1;
                        if (rightEnds == null) return -1;
                        return leftEnds.compareTo(rightEnds);
                      }

                      return left.nextBillingDate.compareTo(
                        right.nextBillingDate,
                      );
                    });
                  final trialItems = sortedItems
                      .where((s) => s.isTrial)
                      .toList();
                  final trialSummary = _buildTrialSummary(trialItems);

                  return RefreshIndicator(
                    onRefresh: () => _onRefresh(ref),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        if (trialSummary != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: _TrialSummaryCard(summary: trialSummary),
                          ),
                        for (var i = 0; i < sortedItems.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          _buildSubscriptionListTile(
                            context: context,
                            ref: ref,
                            subscription: sortedItems[i],
                            currencyFormat: currencyFormat,
                            dateFmt: dateFmt,
                            now: now,
                          ),
                        ],
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await _openEditor(context);
          ref.invalidate(subscriptionListProvider);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSubscriptionListTile({
    required BuildContext context,
    required WidgetRef ref,
    required Subscription subscription,
    required NumberFormat currencyFormat,
    required DateFormat dateFmt,
    required DateTime now,
  }) {
    final next = dateFmt.format(subscription.nextBillingDate);
    final isTrial = subscription.isTrial;

    return ListTile(
      leading: Icon(
        isTrial ? Icons.hourglass_bottom : Icons.subscriptions_outlined,
      ),
      title: Text(subscription.name),
      subtitle: Text(
        [
          '${subscription.currency} ${currencyFormat.format(subscription.amount).trim()} · ${subscription.cycle}',
          'Next: $next',
          if (isTrial) _trialStatusLabel(subscription, now),
        ].join(' · '),
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (v) async {
          if (v == 'edit') {
            await _openEditor(context, subscription: subscription);
            ref.invalidate(subscriptionListProvider);
          } else if (v == 'delete') {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete subscription?'),
                content: const Text('This cannot be undone.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
            if (ok == true && context.mounted) {
              await ref
                  .read(subscriptionRepositoryProvider)
                  .delete(subscription.id);
              await ref
                  .read(activityLogServiceProvider)
                  .add(
                    action: 'Subscription deleted',
                    details:
                        '${subscription.name} · ${subscription.currency} ${subscription.amount.toStringAsFixed(2)}',
                  );
              ref.invalidate(subscriptionListProvider);
            }
          } else if (v == 'mark_paid') {
            await _markTrialAsPaid(
              context: context,
              ref: ref,
              subscription: subscription,
            );
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
          if (isTrial)
            const PopupMenuItem(
              value: 'mark_paid',
              child: Text('Mark as paid'),
            ),
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
      onTap: () async {
        await _openEditor(context, subscription: subscription);
        ref.invalidate(subscriptionListProvider);
      },
    );
  }

  Future<void> _markTrialAsPaid({
    required BuildContext context,
    required WidgetRef ref,
    required Subscription subscription,
  }) async {
    final logger = ref.read(appLoggerProvider);
    final trialEndsAtIso =
        subscription.trialEndsAt?.toIso8601String() ?? 'none';
    final nextBillingIso = subscription.nextBillingDate.toIso8601String();
    if (!subscription.isTrial) {
      logger.info(
        'subscription_trial_mark_paid_skipped_not_trial id=${subscription.id} name=${subscription.name} next_billing_at=$nextBillingIso',
      );
      return;
    }

    logger.info(
      'subscription_trial_mark_paid_started id=${subscription.id} name=${subscription.name} trial_ends_at=$trialEndsAtIso next_billing_at=$nextBillingIso',
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Convert trial to paid?'),
        content: Text(
          'This will mark ${subscription.name} as a paid subscription and clear trial fields.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (ok != true) {
      logger.info(
        'subscription_trial_mark_paid_cancelled id=${subscription.id} name=${subscription.name} trial_ends_at=$trialEndsAtIso next_billing_at=$nextBillingIso',
      );
      await ref
          .read(activityLogServiceProvider)
          .add(
            action: 'Trial conversion cancelled',
            details: subscription.name,
          );
      return;
    }

    final updated = Subscription()
      ..id = subscription.id
      ..remoteId = subscription.remoteId
      ..userId = subscription.userId
      ..name = subscription.name
      ..amount = subscription.amount
      ..currency = subscription.currency
      ..cycle = subscription.cycle
      ..nextBillingDate = subscription.nextBillingDate
      ..isTrial = false
      ..trialEndsAt = null;

    try {
      await ref.read(subscriptionRepositoryProvider).put(updated);
      ref.invalidate(subscriptionListProvider);
      logger.info(
        'subscription_trial_mark_paid_succeeded id=${subscription.id} name=${subscription.name} previous_trial_ends_at=$trialEndsAtIso next_billing_at=$nextBillingIso',
      );
      await ref
          .read(activityLogServiceProvider)
          .add(action: 'Trial marked as paid', details: subscription.name);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${subscription.name} marked as paid.')),
      );
    } catch (error, stack) {
      logger.warning(
        'subscription_trial_mark_paid_failed id=${subscription.id} name=${subscription.name} trial_ends_at=$trialEndsAtIso next_billing_at=$nextBillingIso',
        error,
        stack,
      );
      await ref
          .read(activityLogServiceProvider)
          .add(
            action: 'Trial conversion failed',
            details: '${subscription.name}: ${error.toString()}',
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not mark ${subscription.name} as paid.')),
      );
    }
  }

  _TrialSummary? _buildTrialSummary(List<Subscription> trialItems) {
    if (trialItems.isEmpty) {
      return null;
    }

    final now = DateTime.now();
    final expired = trialItems.where((s) {
      final endsAt = s.trialEndsAt;
      return s.isTrial && endsAt != null && endsAt.isBefore(now);
    }).length;
    final endingSoon = trialItems.where((s) {
      final endsAt = s.trialEndsAt;
      if (endsAt == null) return false;
      final remaining = endsAt.difference(now);
      return !remaining.isNegative && remaining <= const Duration(days: 7);
    }).length;
    final missingEndDate = trialItems
        .where((s) => s.trialEndsAt == null)
        .length;

    return _TrialSummary(
      total: trialItems.length,
      expired: expired,
      endingSoon: endingSoon,
      missingEndDate: missingEndDate,
    );
  }

  String _trialStatusLabel(Subscription subscription, DateTime now) {
    final trialEnds = subscription.trialEndsAt;
    if (trialEnds == null) {
      return 'Trial active';
    }

    final remaining = trialEnds.difference(now);
    if (remaining.isNegative) {
      final days = now.difference(trialEnds).inDays;
      return 'Trial expired ${days}d ago';
    }
    if (remaining.inDays == 0) {
      return 'Trial ends today';
    }
    return 'Trial ends in ${remaining.inDays}d';
  }
}

class _TrialSummary {
  const _TrialSummary({
    required this.total,
    required this.expired,
    required this.endingSoon,
    required this.missingEndDate,
  });

  final int total;
  final int expired;
  final int endingSoon;
  final int missingEndDate;
}

class _TrialSummaryCard extends StatelessWidget {
  const _TrialSummaryCard({required this.summary});

  final _TrialSummary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trial monitoring',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: scheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${summary.total} trial subscription${summary.total == 1 ? '' : 's'} tracked',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${summary.endingSoon} ending soon · ${summary.expired} expired · ${summary.missingEndDate} without end date',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSecondaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
