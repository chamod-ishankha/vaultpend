import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:isar_community/isar.dart';

import '../../core/providers.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../data/models/category.dart';
import '../../data/models/expense.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key, this.expense});

  /// When set, form edits this existing record.
  final Expense? expense;

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _currency = 'USD';

  /// Isar [Category.id] — use id, not [Category] objects, so the dropdown value
  /// always matches an item after rebuild (object identity differs per query).
  int? _categoryId;

  DateTime _when = DateTime.now();
  bool _recurring = false;

  static const _currencies = ['LKR', 'USD', 'EUR'];
  static final _dateTimeFmt = DateFormat('MMM d, yyyy h:mm a');

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    if (e != null) {
      _amountCtrl.text = _formatAmount(e.amount);
      _currency = e.currency;
      _categoryId = e.categoryId;
      _when = e.occurredAt;
      _recurring = e.isRecurring;
      final note = e.note;
      if (note != null && note.isNotEmpty) {
        _noteCtrl.text = note;
      }
    }
  }

  static String _formatAmount(double v) {
    if (v == v.roundToDouble()) {
      return v.toStringAsFixed(0);
    }
    return v.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (!mounted) return;
    if (d == null) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
    );
    if (t == null || !mounted) return;
    setState(() {
      _when = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  Future<void> _save() async {
    final raw = _amountCtrl.text.trim().replaceAll(',', '.');
    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    final repo = ref.read(expenseRepositoryProvider);
    final existing = widget.expense;
    final e = Expense()
      ..id = existing?.id ?? Isar.autoIncrement
      ..remoteId = existing?.remoteId
      ..amount = amount
      ..currency = _currency
      ..occurredAt = _when
      ..note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim()
      ..isRecurring = _recurring
      ..categoryId = _categoryId;
    await repo.put(e);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final catsAsync = ref.watch(categoryListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.expense != null ? 'Edit expense' : 'Add expense'),
      ),
      body: catsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (cats) {
          final ids = cats.map((c) => c.id).toSet();
          final stale = _categoryId != null && !ids.contains(_categoryId);
          // Dropdown requires value to match exactly one item this frame.
          final int? selectedId;
          if (_categoryId != null && ids.contains(_categoryId)) {
            selectedId = _categoryId;
          } else if (stale) {
            selectedId = cats.isNotEmpty ? cats.first.id : null;
          } else {
            selectedId = _categoryId == null && cats.isNotEmpty
                ? cats.first.id
                : null;
          }

          if (stale) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _categoryId = cats.isNotEmpty ? cats.first.id : null;
              });
            });
          }

          return ResponsiveBody(
            maxWidth: 760,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: widget.expense == null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _currency,
                  decoration: const InputDecoration(
                    labelText: 'Currency',
                    border: OutlineInputBorder(),
                  ),
                  items: _currencies
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _currency = v ?? 'USD'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int?>(
                  initialValue: selectedId,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: cats
                      .map(
                        (c) => DropdownMenuItem<int?>(
                          value: c.id,
                          child: Text(c.name),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Date & time'),
                  subtitle: Text(_dateTimeFmt.format(_when.toLocal())),
                  onTap: _pickTime,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Recurring'),
                  value: _recurring,
                  onChanged: (v) => setState(() => _recurring = v),
                ),
                TextField(
                  controller: _noteCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _save,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Save'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
