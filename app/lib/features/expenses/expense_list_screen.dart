import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/export/expense_csv_export_service.dart';
import '../../core/export/expense_pdf_export_service.dart';
import '../../core/providers.dart';
import '../../core/fx/currency_conversion.dart';
import '../../core/fx/fx_providers.dart';
import '../../core/widgets/fx_reference_strip.dart';
import '../../core/widgets/obsidian_app_bar.dart';
import '../../core/widgets/obsidian_card.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../data/models/category.dart';
import '../../data/models/expense.dart';
import '../../core/theme/app_theme.dart';
import '../categories/category_color_resolver.dart';
import '../categories/category_icon_resolver.dart';
import '../auth/auth_providers.dart';
import 'add_expense_screen.dart';
import 'expense_providers.dart';

class ExpenseListScreen extends ConsumerWidget {
  const ExpenseListScreen({super.key, this.onOpenDrawer});

  final VoidCallback? onOpenDrawer;
  static const _csvExportService = ExpenseCsvExportService();
  static const _pdfExportService = ExpensePdfExportService();

  Future<void> _openEditor(BuildContext context, {Expense? expense}) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => AddExpenseScreen(expense: expense)),
    );
  }

  Future<void> _onRefresh(WidgetRef ref) async {
    ref.invalidate(expenseListProvider);
    ref.invalidate(fxRatesProvider);
    await Future.wait([
      ref.read(expenseListProvider.future),
      ref.read(fxRatesProvider.future),
    ]);
  }

  Future<void> _exportExpensesCsv(BuildContext context, WidgetRef ref) async {
    try {
      final expenses = await ref.read(expenseListProvider.future);
      if (expenses.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No expenses to export.')));
        return;
      }

      final categoryRepository = ref.read(categoryRepositoryProvider);
      final categoryNames = <int, String>{};
      final categoryIds = expenses
          .map((e) => e.categoryId)
          .whereType<int>()
          .toSet();
      for (final id in categoryIds) {
        final cat = await categoryRepository.getById(id);
        if (cat != null) categoryNames[id] = cat.name;
      }

      final csv = _csvExportService.buildCsv(
        expenses: expenses,
        categoryNames: categoryNames,
      );
      final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final bytes = Uint8List.fromList(utf8.encode(csv));

      await SharePlus.instance.share(
        ShareParams(
          subject: 'Expenses Export',
          text: 'VaultSpend CSV Export',
          files: [
            XFile.fromData(
              bytes,
              mimeType: 'text/csv',
              name: 'expenses_$stamp.csv',
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _exportExpensesPdf(BuildContext context, WidgetRef ref) async {
    try {
      final expenses = await ref.read(expenseListProvider.future);
      if (expenses.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No expenses to export.')));
        return;
      }

      final categoryRepository = ref.read(categoryRepositoryProvider);
      final categoryNames = <int, String>{};
      final categoryIds = expenses
          .map((e) => e.categoryId)
          .whereType<int>()
          .toSet();
      for (final id in categoryIds) {
        final cat = await categoryRepository.getById(id);
        if (cat != null) categoryNames[id] = cat.name;
      }

      final pdfDoc = await _pdfExportService.buildPdf(
        expenses: expenses,
        categoryNames: categoryNames,
      );
      final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final bytes = await pdfDoc.save();

      await SharePlus.instance.share(
        ShareParams(
          subject: 'Expenses Report',
          text: 'VaultSpend PDF Export',
          files: [
            XFile.fromData(
              bytes,
              mimeType: 'application/pdf',
              name: 'expenses_$stamp.pdf',
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(expenseListProvider);
    final currencyFormat = NumberFormat.currency(symbol: '');
    final preferredCurrency = ref.watch(preferredCurrencyProvider);
    final fxSnapshot = ref
        .watch(fxRatesProvider)
        .maybeWhen(data: (d) => d, orElse: () => null);

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ext = theme.vaultSpend;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final shellBottomNavReservedHeight = 80.0 + bottomInset;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: ObsidianAppBar(
        centerTitle: false,
        title: Text(
          'Expenses',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        leading: onOpenDrawer != null
            ? IconButton(icon: const Icon(Icons.menu), onPressed: onOpenDrawer)
            : null,
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Export',
            icon: const Icon(Icons.ios_share_rounded),
            onSelected: (v) {
              if (v == 'csv') {
                _exportExpensesCsv(context, ref);
              } else if (v == 'pdf') {
                _exportExpensesPdf(context, ref);
              }
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
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
              color: ext.surfaceContainerLow,
            ),
            child: Icon(Icons.person, size: 18, color: scheme.primary),
          ),
        ],
      ),
      body: ResponsiveBody(
        child: Column(
          children: [
            SizedBox(height: 64 + MediaQuery.paddingOf(context).top),
            const FxReferenceStrip(),
            Expanded(
              child: async.when(
                data: (items) {
                  if (items.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: () => _onRefresh(ref),
                      child: ListView(
                        children: [_buildEmptyState(theme, scheme, ext)],
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () => _onRefresh(ref),
                    child: ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        16,
                        16,
                        120 + bottomInset,
                      ),
                      itemCount: items.length + 1,
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 16),
                            child: Text(
                              'RECENT ACTIVITY',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.outline,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2,
                              ),
                            ),
                          );
                        }
                        final e = items[i - 1];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ExpenseCard(
                            expense: e,
                            currencyFormat: currencyFormat,
                            preferredCurrency: preferredCurrency,
                            fxSnapshot: fxSnapshot,
                            onEdit: () async {
                              await _openEditor(context, expense: e);
                              ref.invalidate(expenseListProvider);
                            },
                            onDelete: () => _confirmDelete(context, ref, e),
                          ),
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
          ref.invalidate(expenseListProvider);
        },
        backgroundColor: scheme.primary,
        foregroundColor: const Color(0xFF003732),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, size: 28),
      ),
      bottomNavigationBar: SizedBox(height: shellBottomNavReservedHeight),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Expense e,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: const Text('This will permanently remove this record.'),
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
      await ref.read(expenseRepositoryProvider).delete(e.id);
      ref.invalidate(expenseListProvider);
    }
  }

  Widget _buildEmptyState(
    ThemeData theme,
    ColorScheme scheme,
    VaultSpendThemeExtension ext,
  ) {
    return Column(
      children: [
        const SizedBox(height: 120),
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primary.withValues(alpha: 0.08),
              ),
            ),
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: ext.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Icon(Icons.receipt_long, size: 44, color: scheme.primary),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Text(
          'No expenses yet',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tap + to add one.\nPull down to refresh.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _ExpenseCard extends ConsumerWidget {
  const _ExpenseCard({
    required this.expense,
    required this.currencyFormat,
    required this.preferredCurrency,
    required this.fxSnapshot,
    required this.onEdit,
    required this.onDelete,
  });

  final Expense expense;
  final NumberFormat currencyFormat;
  final String preferredCurrency;
  final dynamic fxSnapshot;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final converted = convertCurrencyAmount(
      amount: expense.amount,
      from: expense.currency,
      to: preferredCurrency,
      snapshot: fxSnapshot,
    );
    final showBase = converted != null && expense.currency != preferredCurrency;
    final amountText = showBase
        ? '-$preferredCurrency ${currencyFormat.format(converted).trim()}'
        : '-${expense.currency} ${currencyFormat.format(expense.amount).trim()}';

    final dateStr = _formatDate(expense.occurredAt);

    return FutureBuilder<Category?>(
      future: expense.categoryId != null
          ? ref.read(categoryRepositoryProvider).getById(expense.categoryId!)
          : Future.value(null),
      builder: (context, snap) {
        final category = snap.data;
        final categoryName = category?.name ?? 'Uncategorized';
        final title = expense.note != null && expense.note!.isNotEmpty
            ? expense.note!
            : categoryName;
        final subtitleText = '$categoryName · $dateStr';

        return GestureDetector(
          onLongPress: () => _showOptions(context),
          child: ObsidianCard(
            level: ObsidianCardTonalLevel.low,
            borderRadius: 16,
            showTopBorder: false,
            padding: EdgeInsets.zero,
            onTap: onEdit,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _CategoryIcon(category: category),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitleText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        amountText,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
              title: const Text('Edit Transaction'),
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
                'Delete Transaction',
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (DateTime(date.year, date.month, date.day) == today) {
      return 'Today, ${DateFormat('h:mm a').format(date)}';
    }
    return DateFormat('MMM d, h:mm a').format(date);
  }
}

class _CategoryIcon extends StatelessWidget {
  const _CategoryIcon({this.category});
  final Category? category;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color color = scheme.primary;
    IconData iconData = Icons.receipt_long_rounded;

    if (category != null) {
      color = resolveCategoryColor(context, category!.color);
      iconData = resolveCategoryIcon(category!.iconKey);
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Center(child: Icon(iconData, color: color, size: 24)),
    );
  }
}
