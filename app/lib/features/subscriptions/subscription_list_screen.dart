import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/providers.dart';
import '../../core/export/subscription_csv_export_service.dart';
import '../../core/export/subscription_pdf_export_service.dart';
import '../../core/fx/currency_conversion.dart';
import '../../core/fx/fx_providers.dart';
import '../../core/fx/fx_snapshot.dart';
import '../../core/logging/app_logging.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/fx_reference_strip.dart';
import '../../core/widgets/obsidian_app_bar.dart';
import '../../core/widgets/obsidian_card.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../core/widgets/user_profile_avatar.dart';
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

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

  Future<void> _onRefresh() async {
    ref.invalidate(subscriptionListProvider);
    ref.invalidate(fxRatesProvider);
    await Future.wait([
      ref.read(subscriptionListProvider.future),
      ref.read(fxRatesProvider.future),
    ]);
  }

  Future<void> _exportCsv(BuildContext context) async {
    final logger = ref.read(appLoggerProvider);
    logger.info('subscription_csv_export_started');
    try {
      final subscriptions = await ref.read(subscriptionListProvider.future);
      if (subscriptions.isEmpty) return;
      final csv = _csvExportService.buildCsv(subscriptions: subscriptions);
      final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final bytes = Uint8List.fromList(utf8.encode(csv));
      await SharePlus.instance.share(
        ShareParams(
          subject: 'Subscriptions Export',
          text: 'VaultSpend CSV Export',
          files: [
            XFile.fromData(
              bytes,
              mimeType: 'text/csv',
              name: 'subs_$stamp.csv',
            ),
          ],
        ),
      );
      logger.info('subscription_csv_export_succeeded');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<void> _exportPdf(BuildContext context) async {
    final logger = ref.read(appLoggerProvider);
    logger.info('subscription_pdf_export_started');
    try {
      final subscriptions = await ref.read(subscriptionListProvider.future);
      if (subscriptions.isEmpty) return;
      final pdfDoc = await _pdfExportService.buildPdf(
        subscriptions: subscriptions,
      );
      final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final bytes = await pdfDoc.save();
      await SharePlus.instance.share(
        ShareParams(
          subject: 'Subscriptions Report',
          text: 'VaultSpend PDF Export',
          files: [
            XFile.fromData(
              bytes,
              mimeType: 'application/pdf',
              name: 'subs_$stamp.pdf',
            ),
          ],
        ),
      );
      logger.info('subscription_pdf_export_succeeded');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(subscriptionListProvider);
    final currencyFormat = NumberFormat.currency(symbol: '');
    final preferredCurrency = ref.watch(preferredCurrencyProvider);
    final fxSnapshot = ref
        .watch(fxRatesProvider)
        .maybeWhen(data: (v) => v, orElse: () => null);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ext = theme.vaultSpend;
    final topPadding = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final shellBottomNavReservedHeight = 80.0 + bottomInset;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: ObsidianAppBar(
        centerTitle: false,
        leading: widget.onOpenDrawer != null
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: widget.onOpenDrawer,
              )
            : null,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Search subscriptions...',
                  border: InputBorder.none,
                  hintStyle: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onSurfaceVariant.withOpacity(0.5),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              )
            : Text(
                'Subscriptions',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close_rounded : Icons.search_rounded,
            ),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _searchController.clear();
                }
                _isSearching = !_isSearching;
              });
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'Export',
            icon: const Icon(Icons.ios_share_rounded),
            onSelected: (v) {
              if (v == 'csv') _exportCsv(context);
              if (v == 'pdf') _exportPdf(context);
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'csv',
                child: Row(
                  children: [
                    Icon(Icons.table_chart_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Export as CSV'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Export as PDF'),
                  ],
                ),
              ),
            ],
          ),
          const UserProfileAvatar(margin: EdgeInsets.only(right: 16)),
        ],
      ),
      body: ResponsiveBody(
        child: Column(
          children: [
            SizedBox(height: 64 + topPadding),
            const FxReferenceStrip(),
            Expanded(
              child: async.when(
                data: (items) {
                  final categoriesAsync = ref.watch(categoryListProvider);
                  final Map<int, String> categoryMap = {};
                  if (categoriesAsync.value != null) {
                    for (final c in categoriesAsync.value!) {
                      categoryMap[c.id] = c.name.toLowerCase();
                    }
                  }

                  final query = _searchController.text.trim().toLowerCase();
                  final filteredItems = query.isEmpty
                      ? items
                      : items.where((s) {
                          final nameMatch = s.name.toLowerCase().contains(query);
                          return nameMatch;
                        }).toList();

                  if (filteredItems.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: _onRefresh,
                      child: ListView(
                        children: [_buildEmptyState(theme, scheme, ext)],
                      ),
                    );
                  }

                  final trialItems = filteredItems.where((s) => s.isTrial).toList();
                  final sortedItems = [...filteredItems]
                    ..sort(
                      (a, b) => a.isTrial == b.isTrial
                          ? a.nextBillingDate.compareTo(b.nextBillingDate)
                          : (a.isTrial ? -1 : 1),
                    );

                  return RefreshIndicator(
                    onRefresh: _onRefresh,
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        24,
                        16,
                        120 + bottomInset,
                      ),
                      children: [
                        if (!_isSearching && trialItems.isNotEmpty)
                          _TrialHeroCard(trialItems: trialItems),

                        if (!_isSearching && trialItems.isNotEmpty) const SizedBox(height: 24),

                        Row(
                          children: [
                            Text(
                              _isSearching && query.isNotEmpty ? 'SEARCH RESULTS' : 'ACTIVE PIPELINE',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.outline,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.8,
                              ),
                            ),
                            const Spacer(),
                            if (!_isSearching)
                              Text(
                                'Filter by: Date',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        ...sortedItems.map(
                          (s) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _SubscriptionCard(
                              subscription: s,
                              currencyFormat: currencyFormat,
                              preferredCurrency: preferredCurrency,
                              fxSnapshot: fxSnapshot,
                              onEdit: () =>
                                  _openEditor(context, subscription: s),
                              onDelete: () => _confirmDelete(context, s),
                              surfaceContainerLow: ext.surfaceContainerLow,
                              surfaceContainerHigh: ext.surfaceContainerHigh,
                            ),
                          ),
                        ),
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
      bottomNavigationBar: SizedBox(height: shellBottomNavReservedHeight),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme scheme, dynamic ext) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.subscriptions_outlined,
            size: 64,
            color: scheme.outline.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text('No subscriptions found', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Track your trials and monthly billing.',
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.outline),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    Subscription subscription,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Subscription?'),
        content: const Text('This will permanently remove this subscription.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await ref.read(subscriptionRepositoryProvider).delete(subscription.id);
      ref.invalidate(subscriptionListProvider);
    }
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

    final endingSoon = trialItems
      ..sort((a, b) => a.nextBillingDate.compareTo(b.nextBillingDate));
    final first = endingSoon.first;
    final second = endingSoon.length > 1 ? endingSoon[1] : null;
    final now = DateTime.now();

    String trialEndLabel(Subscription s) {
      final days = s.nextBillingDate.difference(now).inDays;
      if (days <= 0) return 'Review today';
      if (days == 1) return 'Ends in 1 day';
      return 'Ends in $days days';
    }

    return ObsidianCard(
      level: ObsidianCardTonalLevel.high,
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trial monitoring',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$activeTrials trial subscription(s) tracked',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.hourglass_top_rounded,
                    size: 20,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _TrialColumn(
                    heading: 'Ending Soon',
                    title: first.name,
                    subtitle: trialEndLabel(first),
                  ),
                ),
                if (second != null) ...[
                  Container(
                    width: 1,
                    height: 48,
                    color: scheme.outlineVariant.withValues(alpha: 0.15),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _TrialColumn(
                      heading: 'Action Required',
                      title: second.name,
                      subtitle: trialEndLabel(second),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TrialColumn extends StatelessWidget {
  const _TrialColumn({
    required this.heading,
    required this.title,
    required this.subtitle,
  });

  final String heading;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.outline,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.tertiary),
        ),
      ],
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  final Subscription subscription;
  final NumberFormat currencyFormat;
  final String preferredCurrency;
  final FxSnapshot? fxSnapshot;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Color surfaceContainerLow;
  final Color surfaceContainerHigh;

  const _SubscriptionCard({
    required this.subscription,
    required this.currencyFormat,
    required this.preferredCurrency,
    required this.fxSnapshot,
    required this.onEdit,
    required this.onDelete,
    required this.surfaceContainerLow,
    required this.surfaceContainerHigh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isTrial = subscription.isTrial;

    final converted = convertCurrencyAmount(
      amount: subscription.amount,
      from: subscription.currency,
      to: preferredCurrency,
      snapshot: fxSnapshot,
    );
    final showBase =
        converted != null && subscription.currency != preferredCurrency;
    final amountText = showBase
        ? '$preferredCurrency ${currencyFormat.format(converted).trim()}'
        : '${subscription.currency} ${currencyFormat.format(subscription.amount).trim()}';
    final cycleText = subscription.cycle.toUpperCase();

    final subtitle = isTrial
        ? 'Trial ends ${DateFormat.yMMMd().format(subscription.nextBillingDate)}'
        : 'Next billing ${DateFormat.yMMMd().format(subscription.nextBillingDate)}';

    return GestureDetector(
      onLongPress: () => _showOptions(context),
      child: Material(
        color: isTrial ? surfaceContainerLow : scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onEdit,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: isTrial
                  ? null
                  : Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.08),
                      width: 1,
                    ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isTrial
                        ? surfaceContainerHigh
                        : scheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Icon(
                    isTrial
                        ? Icons.hourglass_empty_rounded
                        : Icons.subscriptions_rounded,
                    color: isTrial ? scheme.primary : scheme.onSurfaceVariant,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              subscription.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (isTrial)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.tertiaryContainer.withValues(
                                  alpha: 0.20,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'TRIAL',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.tertiary,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      amountText.trim(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cycleText,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.outline,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Edit Subscription'),
              onTap: () {
                Navigator.pop(ctx);
                onEdit();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_rounded,
                color: Colors.redAccent,
              ),
              title: const Text(
                'Delete Subscription',
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: () {
                Navigator.pop(ctx);
                onDelete();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
