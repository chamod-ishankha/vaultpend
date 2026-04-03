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
                  return RefreshIndicator(
                    onRefresh: () => _onRefresh(ref),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: items.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final s = items[i];
                        final next = dateFmt.format(s.nextBillingDate);
                        return ListTile(
                          title: Text(s.name),
                          subtitle: Text(
                            [
                              '${s.currency} ${currencyFormat.format(s.amount).trim()} · ${s.cycle}',
                              'Next: $next',
                              if (s.isTrial) 'Trial',
                            ].join(' · '),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'edit') {
                                await _openEditor(context, subscription: s);
                                ref.invalidate(subscriptionListProvider);
                              } else if (v == 'delete') {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete subscription?'),
                                    content: const Text(
                                      'This cannot be undone.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok == true && context.mounted) {
                                  await ref
                                      .read(subscriptionRepositoryProvider)
                                      .delete(s.id);
                                  ref.invalidate(subscriptionListProvider);
                                }
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                          onTap: () async {
                            await _openEditor(context, subscription: s);
                            ref.invalidate(subscriptionListProvider);
                          },
                        );
                      },
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
}
