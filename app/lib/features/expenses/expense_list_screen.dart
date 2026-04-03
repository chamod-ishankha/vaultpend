import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/export/expense_csv_export_service.dart';
import '../../core/providers.dart';
import '../../core/export/expense_pdf_export_service.dart';
import '../../core/fx/fx_providers.dart';
import '../../core/logging/app_logging.dart';
import '../../core/widgets/fx_reference_strip.dart';
import '../../data/models/category.dart';
import '../../data/models/expense.dart';
import 'add_expense_screen.dart';
import 'expense_providers.dart';

class ExpenseListScreen extends ConsumerWidget {
  const ExpenseListScreen({super.key, this.onOpenDrawer});

  final VoidCallback? onOpenDrawer;
  static const _csvExportService = ExpenseCsvExportService();
  static const _pdfExportService = ExpensePdfExportService();

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

    return Scaffold(
      appBar: AppBar(
        leading: onOpenDrawer != null
            ? IconButton(icon: const Icon(Icons.menu), onPressed: onOpenDrawer)
            : null,
        title: const Text('Expenses'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Export',
            icon: const Icon(Icons.download_outlined),
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
        ],
      ),
      body: Column(
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
                            'No expenses yet.\nTap + to add one.\nPull down to refresh.',
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
                      final e = items[i];
                      return ListTile(
                        title: Text(
                          '${e.currency} ${currencyFormat.format(e.amount).trim()}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        subtitle: _ExpenseSubtitle(expense: e),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (e.note != null && e.note!.isNotEmpty)
                              Icon(
                                Icons.notes,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            PopupMenuButton<String>(
                              onSelected: (v) async {
                                if (v == 'edit') {
                                  await Navigator.of(context).push<void>(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          AddExpenseScreen(expense: e),
                                    ),
                                  );
                                  ref.invalidate(expenseListProvider);
                                } else if (v == 'delete') {
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
                                    await ref
                                        .read(expenseRepositoryProvider)
                                        .delete(e.id);
                                    ref.invalidate(expenseListProvider);
                                  }
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        onTap: () async {
                          await Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => AddExpenseScreen(expense: e),
                            ),
                          );
                          ref.invalidate(expenseListProvider);
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
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push<void>(
            MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
          );
          ref.invalidate(expenseListProvider);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ExpenseSubtitle extends ConsumerWidget {
  const _ExpenseSubtitle({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateStr = DateFormat.yMMMd().add_jm().format(expense.occurredAt);
    final id = expense.categoryId;
    if (id == null) {
      return Text(_line('Uncategorized', dateStr));
    }
    return FutureBuilder<Category?>(
      future: ref.read(categoryRepositoryProvider).getById(id),
      builder: (context, snap) {
        final name = snap.data?.name ?? 'Category';
        return Text(_line(name, dateStr));
      },
    );
  }

  String _line(String categoryName, String dateStr) {
    final parts = <String>[categoryName, dateStr];
    if (expense.isRecurring) parts.add('Recurring');
    return parts.join(' · ');
  }
}
