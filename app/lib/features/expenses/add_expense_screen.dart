import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:isar_community/isar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logging/logging.dart';

import '../../core/providers.dart';
import '../../core/logging/app_logging.dart';
import '../../core/notifications/reminder_sync_helper.dart';
import '../../core/ocr/receipt_ocr_service.dart';
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
  final _logger = Logger('VaultSpend.ReceiptOCR');
  final _receiptOcrService = ReceiptOcrService();
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

  Future<void> _scanReceipt() async {
    final appLogger = ref.read(appLoggerProvider);
    appLogger.info('receipt_scan_sheet_opened');

    final source = await showModalBottomSheet<ImageSource?>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Use camera'),
              onTap: () {
                appLogger.info('receipt_scan_source_selected source=camera');
                Navigator.of(ctx).pop(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                appLogger.info('receipt_scan_source_selected source=gallery');
                Navigator.of(ctx).pop(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) {
      appLogger.info('receipt_scan_source_cancelled');
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Scanning receipt...')),
    );

    try {
      final result = await _receiptOcrService.scanReceiptFromSource(
        source,
        logger: _logger,
      );
      if (!mounted) return;

      if (result == null || result.rawText.trim().isEmpty) {
        appLogger.warning('receipt_scan_no_text_detected');
        messenger.showSnackBar(
          const SnackBar(content: Text('No text found in receipt image.')),
        );
        return;
      }

      final selectedAmount = await _confirmDetectedAmount(result);
      if (!mounted) return;

      setState(() {
        if (selectedAmount != null) {
          _amountCtrl.text = selectedAmount.toStringAsFixed(2);
        }
        final note = result.note;
        if (note != null &&
            note.trim().isNotEmpty &&
            _noteCtrl.text.trim().isEmpty) {
          _noteCtrl.text = note.trim();
        }
      });

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            selectedAmount != null
                ? 'Receipt scanned. Amount set to ${selectedAmount.toStringAsFixed(2)}.'
                : 'Receipt scanned. No amount selected.',
          ),
        ),
      );
      appLogger.info(
        'receipt_scan_completed amount=${selectedAmount ?? 'none'} note=${result.note?.isNotEmpty == true ? 'yes' : 'no'} candidate_count=${result.amountCandidates.length}',
      );
    } on PlatformException catch (error, stack) {
      appLogger.severe('receipt_scan_platform_exception', error, stack);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Receipt scan platform error: ${error.message ?? error.code}',
          ),
        ),
      );
    } catch (error, stack) {
      appLogger.severe('receipt_scan_failed', error, stack);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Receipt scan failed: $error')),
      );
    }
  }

  Future<double?> _confirmDetectedAmount(ReceiptScanResult result) async {
    if (result.amountCandidates.isEmpty) {
      return result.amount;
    }

    final candidates = result.amountCandidates.take(3).toList(growable: false);
    var selectedIndex = 0;

    if (result.amount != null) {
      final idx = candidates.indexWhere(
        (candidate) => candidate.amount == result.amount,
      );
      if (idx >= 0) {
        selectedIndex = idx;
      }
    }

    return showModalBottomSheet<double?>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Confirm detected amount',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose the best match from receipt scan results.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < candidates.length; i++)
                  ListTile(
                    onTap: () => setSheetState(() => selectedIndex = i),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(
                      selectedIndex == i
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                    ),
                    title: Text(candidates[i].amount.toStringAsFixed(2)),
                    subtitle: Text(
                      candidates[i].line,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Skip'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => Navigator.of(
                        ctx,
                      ).pop(candidates[selectedIndex].amount),
                      child: const Text('Use amount'),
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

  Future<void> _save() async {
    final raw = _amountCtrl.text.trim().replaceAll(',', '.');
    final amount = double.tryParse(raw);
    final existing = widget.expense;
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    final repo = ref.read(expenseRepositoryProvider);
    final e = Expense()
      ..id = existing?.id ?? Isar.autoIncrement
      ..remoteId = existing?.remoteId
      ..amount = amount
      ..currency = _currency
      ..occurredAt = _when
      ..note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim()
      ..isRecurring = _recurring
      ..categoryId = _categoryId;
    final categoryName = _categoryId == null
        ? 'Uncategorized'
        : (await ref.read(categoryRepositoryProvider).getById(_categoryId!))
                  ?.name ??
              'Category #$_categoryId';
    await repo.put(e);
    await ref
        .read(activityLogServiceProvider)
        .add(
          action: existing == null ? 'Expense added' : 'Expense updated',
          details:
              '$categoryName · ${e.currency} ${e.amount.toStringAsFixed(2)} · ${_recurring ? 'recurring' : 'one-time'}${e.note == null ? '' : ' · ${e.note}'}',
        );
    await syncRemindersNow(
      ref,
      reason: existing == null ? 'expense_added' : 'expense_updated',
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final catsAsync = ref.watch(categoryListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.expense != null ? 'Edit expense' : 'Add expense'),
        actions: [
          IconButton(
            tooltip: 'Scan receipt',
            icon: const Icon(Icons.document_scanner_outlined),
            onPressed: _scanReceipt,
          ),
        ],
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
