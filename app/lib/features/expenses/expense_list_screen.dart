import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/export/expense_csv_export_service.dart';
import '../../core/providers.dart';
import '../../core/export/expense_pdf_export_service.dart';
import '../../core/notifications/reminder_sync_helper.dart';
import '../../core/fx/currency_conversion.dart';
import '../../core/fx/fx_providers.dart';
import '../../core/logging/app_logging.dart';
import '../../core/widgets/fx_reference_strip.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../data/models/category.dart';
import '../../data/models/expense.dart';
import '../../core/theme/app_theme.dart';
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
    final logger = ref.read(appLoggerProvider);
    logger.info('expense_csv_export_started');
    try {
      final expenses = await ref.read(expenseListProvider.future);
      if (expenses.isEmpty) {
        logger.info('expense_csv_export_skipped_no_data');
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No expenses to export yet.')),
        );
        return;
      }

      final categoryRepository = ref.read(categoryRepositoryProvider);
      final categoryNames = <int, String>{};
      final categoryIds = expenses
          .map((expense) => expense.categoryId)
          .whereType<int>()
          .toSet();
      for (final categoryId in categoryIds) {
        final category = await categoryRepository.getById(categoryId);
        if (category != null) {
          categoryNames[categoryId] = category.name;
        }
      }

      final csv = _csvExportService.buildCsv(
        expenses: expenses,
        categoryNames: categoryNames,
      );

      final stamp = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
      final filename = 'vaultspend_expenses_$stamp.csv';
      final bytes = Uint8List.fromList(utf8.encode(csv));

      await SharePlus.instance.share(
        ShareParams(
          subject: 'VaultSpend expenses export',
          text: 'VaultSpend expenses CSV export',
          files: [XFile.fromData(bytes, mimeType: 'text/csv', name: filename)],
        ),
      );

      logger.info('expense_csv_export_succeeded');

      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('CSV export prepared: $filename')));
    } catch (error, stack) {
      logger.warning('expense_csv_export_failed', error, stack);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('CSV export failed: $error')));
    }
  }

  Future<void> _exportExpensesPdf(BuildContext context, WidgetRef ref) async {
    final logger = ref.read(appLoggerProvider);
    logger.info('expense_pdf_export_started');
    try {
      final expenses = await ref.read(expenseListProvider.future);
      if (expenses.isEmpty) {
        logger.info('expense_pdf_export_skipped_no_data');
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No expenses to export yet.')),
        );
        return;
      }

      final categoryRepository = ref.read(categoryRepositoryProvider);
      final categoryNames = <int, String>{};
      final categoryIds = expenses
          .map((expense) => expense.categoryId)
          .whereType<int>()
          .toSet();
      for (final categoryId in categoryIds) {
        final category = await categoryRepository.getById(categoryId);
        if (category != null) {
          categoryNames[categoryId] = category.name;
        }
      }

      final pdfDoc = await _pdfExportService.buildPdf(
        expenses: expenses,
        categoryNames: categoryNames,
      );

      final stamp = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
      final filename = 'vaultspend_expenses_$stamp.pdf';
      final bytes = await pdfDoc.save();

      await SharePlus.instance.share(
        ShareParams(
          subject: 'VaultSpend expenses report',
          text: 'VaultSpend expenses PDF report',
          files: [
            XFile.fromData(bytes, mimeType: 'application/pdf', name: filename),
          ],
        ),
      );

      logger.info('expense_pdf_export_succeeded');

      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF export prepared: $filename')));
    } catch (error, stack) {
      logger.warning('expense_pdf_export_failed', error, stack);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF export failed: $error')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(expenseListProvider);
    final currencyFormat = NumberFormat.currency(symbol: '');
    final preferredCurrency = ref.watch(preferredCurrencyProvider);
    final fxSnapshot = ref
        .watch(fxRatesProvider)
        .maybeWhen(data: (value) => value, orElse: () => null);
        
    final scheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<VaultSpendThemeExtension>()!;

    return Scaffold(
      backgroundColor: Colors.transparent, // Let Shell build background if stacked, or surface if not
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AppBar(
              backgroundColor: scheme.surface.withOpacity(0.8),
              elevation: 0,
              scrolledUnderElevation: 0,
              shape: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.05),
                  width: 1,
                ),
              ),
              leading: onOpenDrawer != null
                  ? IconButton(
                      icon: Icon(Icons.menu, color: scheme.primary),
                      onPressed: onOpenDrawer,
                    )
                  : null,
              title: Text(
                'Expenses',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: scheme.primary,
                  letterSpacing: -0.5,
                ),
              ),
              actions: [
                PopupMenuButton<String>(
                  tooltip: 'Export',
                  icon: Icon(Icons.ios_share, color: scheme.primary),
                  onSelected: (value) {
                    if (value == 'csv') {
                      _exportExpensesCsv(context, ref);
                    } else if (value == 'pdf') {
                      _exportExpensesPdf(context, ref);
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
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.primary.withOpacity(0.2)),
                      color: scheme.surfaceContainerHighest,
                    ),
                    child: const Icon(Icons.person, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: ResponsiveBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Offset for the translucent AppBar
            SizedBox(height: 64 + MediaQuery.paddingOf(context).top),
            const FxReferenceStrip(),
            Expanded(
              child: async.when(
                data: (items) {
                  if (items.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: () => _onRefresh(ref),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
                        children: [
                          Center(
                            child: _buildEmptyState(scheme, ext),
                          ),
                        ],
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () => _onRefresh(ref),
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      // Extra padding at bottom to prevent floating action button and bottom nav bar from covering content
                      padding: const EdgeInsets.only(top: 8, left: 16, right: 16, bottom: 160),
                      itemCount: items.length + 1, // +1 for the header
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 8, bottom: 16, top: 16),
                            child: Text(
                              'RECENT ACTIVITY',
                              style: GoogleFonts.manrope(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: scheme.outline,
                                letterSpacing: 2.0,
                              ),
                            ),
                          );
                        }
                        final e = items[i - 1];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: _ExpenseCard(
                            expense: e,
                            currencyFormat: currencyFormat,
                            preferredCurrency: preferredCurrency,
                            fxSnapshot: fxSnapshot,
                            onEdit: () async {
                              await _openEditor(context, expense: e);
                              ref.invalidate(expenseListProvider);
                            },
                            onDelete: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete expense?'),
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
                                final categoryName = e.categoryId == null
                                    ? 'Uncategorized'
                                    : (await ref
                                                  .read(
                                                    categoryRepositoryProvider,
                                                  )
                                                  .getById(e.categoryId!))
                                              ?.name ??
                                          'Category #${e.categoryId}';
                                await ref
                                    .read(expenseRepositoryProvider)
                                    .delete(e.id);
                                await ref
                                    .read(activityLogServiceProvider)
                                    .add(
                                      action: 'Expense deleted',
                                      details:
                                          '$categoryName · ${e.currency} ${e.amount.toStringAsFixed(2)} · ${e.isRecurring ? 'recurring' : 'one-time'}${e.note == null ? '' : ' · ${e.note}'}',
                                    );
                                await syncRemindersNow(
                                  ref,
                                  reason: 'expense_deleted',
                                );
                                ref.invalidate(expenseListProvider);
                              }
                            },
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
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [scheme.primary, scheme.primaryContainer],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withOpacity(0.3),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () async {
                await _openEditor(context);
                ref.invalidate(expenseListProvider);
              },
              child: Center(
                child: Icon(
                  Icons.add,
                  color: scheme.onPrimary,
                  size: 32,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme scheme, VaultSpendThemeExtension ext) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 140,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withOpacity(0.1),
                      blurRadius: 60,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ext.surfaceContainerHigh,
                  border: Border.all(
                    color: scheme.primary.withOpacity(0.2),
                  ),
                ),
                child: Icon(
                  Icons.receipt_long,
                  size: 48,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'No expenses yet',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: GoogleFonts.inter(
              fontSize: 14,
              color: scheme.onSurfaceVariant,
              height: 1.6,
            ),
            children: [
              const TextSpan(text: 'Tap '),
              TextSpan(
                text: '+',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                  fontSize: 16,
                ),
              ),
              const TextSpan(text: ' to add one.\nPull down to refresh.'),
            ],
          ),
        ),
        const SizedBox(height: 48),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
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
    final scheme = Theme.of(context).colorScheme;
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

    final categoryId = expense.categoryId;
    final dateStr = _formatDate(expense.occurredAt);

    return FutureBuilder<Category?>(
      future: categoryId != null 
        ? ref.read(categoryRepositoryProvider).getById(categoryId) 
        : Future.value(null),
      builder: (context, snap) {
        final category = snap.data;
        final categoryName = category?.name ?? 'Uncategorized';
        final title = expense.note != null && expense.note!.isNotEmpty 
            ? expense.note! 
            : categoryName;

        return InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1B1F),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
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
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: scheme.onSurface,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '$categoryName · $dateStr',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      amountText,
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: scheme.onSurface,
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_horiz, color: scheme.outline, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onSelected: (v) {
                        if (v == 'edit') onEdit();
                        if (v == 'delete') onDelete();
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);

    if (d == today) {
      return 'Today, ${DateFormat('h:mm a').format(date)}';
    } else if (d == yesterday) {
      return 'Yesterday, ${DateFormat('h:mm a').format(date)}';
    } else {
      return DateFormat('MMM d, h:mm a').format(date);
    }
  }
}

class _CategoryIcon extends StatelessWidget {
  const _CategoryIcon({this.category});
  final Category? category;

  @override
  Widget build(BuildContext context) {
    // Basic mapping for visual flair
    IconData iconData = Icons.receipt_long;
    Color color = Colors.teal;

    if (category != null) {
      final name = category!.name.toLowerCase();
      if (name.contains('grocery') || name.contains('food')) {
        iconData = Icons.shopping_cart;
        color = const Color(0xFF0D9488);
      } else if (name.contains('electric') || name.contains('bill') || name.contains('utility')) {
        iconData = Icons.bolt;
        color = Colors.orange;
      } else if (name.contains('transport') || name.contains('uber') || name.contains('car')) {
        iconData = Icons.directions_car;
        color = Colors.blue;
      } else if (name.contains('dining') || name.contains('restaurant') || name.contains('coffee')) {
        iconData = Icons.restaurant;
        color = const Color(0xFF0D9488);
      } else if (name.contains('entertainment') || name.contains('movie')) {
        iconData = Icons.confirmation_number;
        color = Colors.purple;
      } else if (name.contains('health') || name.contains('med') || name.contains('pharmacy')) {
        iconData = Icons.medical_services;
        color = Colors.red;
      }
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Center(
        child: Icon(iconData, color: color, size: 24),
      ),
    );
  }
}
