import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/fx/fx_providers.dart';
import '../../core/providers.dart';
import '../../core/widgets/fx_reference_strip.dart';
import '../../data/models/category.dart';
import '../../data/models/expense.dart';
import 'add_expense_screen.dart';
import 'expense_providers.dart';

class ExpenseListScreen extends ConsumerWidget {
  const ExpenseListScreen({super.key, this.onOpenDrawer});

  final VoidCallback? onOpenDrawer;

  Future<void> _onRefresh(WidgetRef ref) async {
    ref.invalidate(expenseListProvider);
    ref.invalidate(fxRatesProvider);
    await Future.wait([
      ref.read(expenseListProvider.future),
      ref.read(fxRatesProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(expenseListProvider);
    final currencyFormat = NumberFormat.currency(symbol: '');

    return Scaffold(
      appBar: AppBar(
        leading: onOpenDrawer != null
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: onOpenDrawer,
              )
            : null,
        title: const Text('Expenses'),
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
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
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
