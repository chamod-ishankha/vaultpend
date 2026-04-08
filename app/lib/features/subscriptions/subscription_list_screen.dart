import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/export/subscription_csv_export_service.dart';
import '../../core/export/subscription_pdf_export_service.dart';
import '../../core/fx/currency_conversion.dart';
import '../../core/fx/fx_providers.dart';
import '../../core/fx/fx_snapshot.dart';
import '../../core/logging/app_logging.dart';
import '../../core/widgets/fx_reference_strip.dart';
import '../../core/widgets/obsidian_app_bar.dart';
import '../../core/widgets/obsidian_card.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../data/models/subscription.dart';
import '../auth/auth_providers.dart';
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

  Future<void> _exportSubscriptionsCsv(BuildContext context, WidgetRef ref) async {
    final logger = ref.read(appLoggerProvider);
    logger.info('subscription_csv_export_started');
    try {
      final subscriptions = await ref.read(subscriptionListProvider.future);
      if (subscriptions.isEmpty) return;
      final csv = _csvExportService.buildCsv(subscriptions: subscriptions);
      final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final bytes = Uint8List.fromList(utf8.encode(csv));
      await SharePlus.instance.share(ShareParams(
        subject: 'Subscriptions Export',
        text: 'VaultSpend CSV Export',
        files: [XFile.fromData(bytes, mimeType: 'text/csv', name: 'subs_$stamp.csv')],
      ));
      logger.info('subscription_csv_export_succeeded');
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _exportSubscriptionsPdf(BuildContext context, WidgetRef ref) async {
    final logger = ref.read(appLoggerProvider);
    logger.info('subscription_pdf_export_started');
    try {
      final subscriptions = await ref.read(subscriptionListProvider.future);
      if (subscriptions.isEmpty) return;
      final pdfDoc = await _pdfExportService.buildPdf(subscriptions: subscriptions);
      final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final bytes = await pdfDoc.save();
      await SharePlus.instance.share(ShareParams(
        subject: 'Subscriptions Report',
        text: 'VaultSpend PDF Export',
        files: [XFile.fromData(bytes, mimeType: 'application/pdf', name: 'subs_$stamp.pdf')],
      ));
      logger.info('subscription_pdf_export_succeeded');
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(subscriptionListProvider);
    final currencyFormat = NumberFormat.currency(symbol: '');
    final preferredCurrency = ref.watch(preferredCurrencyProvider);
    final fxSnapshot = ref.watch(fxRatesProvider).maybeWhen(data: (v) => v, orElse: () => null);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: ObsidianAppBar(
        leading: widget.onOpenDrawer != null
            ? IconButton(icon: const Icon(Icons.menu), onPressed: widget.onOpenDrawer)
            : null,
        title: const Text('Subscriptions'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Export',
            icon: const Icon(Icons.download_rounded),
            onSelected: (v) {
              if (v == 'csv') _exportSubscriptionsCsv(context, ref);
              if (v == 'pdf') _exportSubscriptionsPdf(context, ref);
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'csv', child: Text('Export as CSV')),
              const PopupMenuItem(value: 'pdf', child: Text('Export as PDF')),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ResponsiveBody(
        child: Column(
          children: [
            const FxReferenceStrip(),
            Expanded(
              child: async.when(
                data: (items) {
                  if (items.isEmpty) {
                    return _buildEmptyState(theme, scheme);
                  }

                  final trialItems = items.where((s) => s.isTrial).toList();
                  final sortedItems = [...items]..sort((a, b) => a.isTrial == b.isTrial 
                      ? a.nextBillingDate.compareTo(b.nextBillingDate)
                      : (a.isTrial ? -1 : 1));

                  return RefreshIndicator(
                    onRefresh: () => _onRefresh(ref),
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      children: [
                        // Hero Card
                        _TrialHeroCard(trialItems: trialItems),
                        
                        const SizedBox(height: 32),
                        
                        // Active Pipeline Header
                        Text(
                          'ACTIVE PIPELINE',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.outline,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        ...sortedItems.map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _SubscriptionCard(
                            subscription: s,
                            currencyFormat: currencyFormat,
                            preferredCurrency: preferredCurrency,
                            fxSnapshot: fxSnapshot,
                            onTap: () => _openEditor(context, subscription: s),
                          ),
                        )),
                        const SizedBox(height: 100),
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
        onPressed: () => _openEditor(context),
        backgroundColor: scheme.primary,
        foregroundColor: const Color(0xFF003732),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme scheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.subscriptions_outlined, size: 64, color: scheme.outline.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('No subscriptions found', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Track your trials and monthly billing.', style: theme.textTheme.bodyMedium?.copyWith(color: scheme.outline)),
        ],
      ),
    );
  }
}

class _TrialHeroCard extends StatelessWidget {
  final List<Subscription> trialItems;
  const _TrialHeroCard({required this.trialItems});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final activeTrials = trialItems.length;

    return ObsidianCard(
      level: ObsidianCardTonalLevel.high,
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary.withOpacity(0.1),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.query_stats_rounded, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  'TRIAL MONITORING ACTIVE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  activeTrials.toString(),
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'ACTIVE TRIALS',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurface.withOpacity(0.7),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                _buildEfficiencyBadge(activeTrials),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Monitoring trial conversions automatically to prevent platform leakage.',
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

  Widget _buildEfficiencyBadge(int trials) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.greenAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.2)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_user_rounded, color: Colors.greenAccent, size: 14),
          SizedBox(width: 4),
          Text(
            'HEALTHY',
            style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w800, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  final Subscription subscription;
  final NumberFormat currencyFormat;
  final String preferredCurrency;
  final FxSnapshot? fxSnapshot;
  final VoidCallback onTap;

  const _SubscriptionCard({
    required this.subscription,
    required this.currencyFormat,
    required this.preferredCurrency,
    required this.fxSnapshot,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();
    final remaining = subscription.nextBillingDate.difference(now);
    final daysLeft = remaining.inDays;

    final converted = convertCurrencyAmount(
      amount: subscription.amount,
      from: subscription.currency,
      to: preferredCurrency,
      snapshot: fxSnapshot,
    );
    final showBase = converted != null && subscription.currency != preferredCurrency;
    final amountText = showBase
        ? '$preferredCurrency ${currencyFormat.format(converted).trim()}'
        : '${subscription.currency} ${currencyFormat.format(subscription.amount).trim()}';

    return ObsidianCard(
      level: ObsidianCardTonalLevel.low,
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Service Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF131317),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.outlineVariant.withOpacity(0.1)),
              ),
              child: Center(
                child: Icon(
                  _mapIcon(subscription.name),
                  color: subscription.isTrial ? scheme.tertiary : scheme.primary,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subscription.name.toUpperCase(),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Next billing in $daysLeft days',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Price & Badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$amountText / ${subscription.cycle.substring(0, 2).toUpperCase()}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                _StatusBadge(subscription: subscription),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _mapIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('netflix')) return Icons.movie_filter_rounded;
    if (n.contains('spotify')) return Icons.queue_music_rounded;
    if (n.contains('apple')) return Icons.apple_rounded;
    if (n.contains('google')) return Icons.ads_click_rounded;
    if (n.contains('adobe')) return Icons.edit_note_rounded;
    if (n.contains('amazon')) return Icons.shopping_cart_rounded;
    if (n.contains('disney')) return Icons.video_library_rounded;
    return Icons.subscriptions_rounded;
  }
}

class _StatusBadge extends StatelessWidget {
  final Subscription subscription;
  const _StatusBadge({required this.subscription});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isTrial = subscription.isTrial;
    final color = isTrial ? scheme.tertiary : scheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        (isTrial ? 'TRIAL' : subscription.cycle).toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 8,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
