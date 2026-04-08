import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:isar_community/isar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logging/logging.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/providers.dart';
import '../../core/logging/app_logging.dart';
import '../../core/notifications/reminder_sync_helper.dart';
import '../../core/ocr/receipt_ocr_service.dart';
import '../../core/widgets/obsidian_app_bar.dart';
import '../../core/widgets/obsidian_button.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../core/widgets/obsidian_card.dart';
import '../../data/models/category.dart';
import '../../data/models/expense.dart';
import '../auth/auth_providers.dart';
import '../categories/category_color_resolver.dart';
import '../categories/category_icon_resolver.dart';

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

  int? _categoryId;

  DateTime _when = DateTime.now();
  bool _recurring = false;
  bool _saving = false;

  static const _currencies = ['LKR', 'USD', 'EUR', 'GBP', 'JPY'];
  static final _dateTimeFmt = DateFormat('EEEE, MMM d, yyyy');

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
    } else {
      _currency = ref.read(preferredCurrencyProvider);
      _amountCtrl.text = '0.00';
    }
  }

  static String _formatAmount(double v) {
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
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            surface: const Color(0xFF1B1B1F),
          ),
        ),
        child: child!,
      ),
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
      backgroundColor: const Color(0xFF131317),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Use camera'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Scanning receipt...')));

    try {
      final result = await _receiptOcrService.scanReceiptFromSource(source, logger: _logger);
      if (!mounted) return;

      if (result == null || result.rawText.trim().isEmpty) {
        messenger.showSnackBar(const SnackBar(content: Text('No text found.')));
        return;
      }

      final selectedAmount = await _confirmDetectedAmount(result);
      if (!mounted) return;

      setState(() {
        if (selectedAmount != null) {
          _amountCtrl.text = selectedAmount.toStringAsFixed(2);
        }
        if (result.note != null && _noteCtrl.text.isEmpty) {
          _noteCtrl.text = result.note!;
        }
      });
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Scan failed: $e')));
    }
  }

  Future<double?> _confirmDetectedAmount(ReceiptScanResult result) async {
    if (result.amountCandidates.isEmpty) return result.amount;
    final candidates = result.amountCandidates.take(3).toList();
    var selectedIndex = 0;

    return showModalBottomSheet<double?>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFF131317),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Confirm Amount', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                for (var i = 0; i < candidates.length; i++)
                  ListTile(
                    onTap: () => setSheetState(() => selectedIndex = i),
                    leading: Icon(selectedIndex == i ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                    title: Text(candidates[i].amount.toStringAsFixed(2)),
                    subtitle: Text(candidates[i].line, maxLines: 1),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(candidates[selectedIndex].amount),
                    child: const Text('Confirm'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    final raw = _amountCtrl.text.trim().replaceAll(',', '.');
    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(expenseRepositoryProvider);
      final e = Expense()
        ..id = widget.expense?.id ?? Isar.autoIncrement
        ..remoteId = widget.expense?.remoteId
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
            action: widget.expense == null ? 'Expense added' : 'Expense updated',
            details:
                '$categoryName · ${e.currency} ${e.amount.toStringAsFixed(2)} · ${_recurring ? 'recurring' : 'one-time'}${e.note == null ? '' : ' · ${e.note}'}',
          );
      await syncRemindersNow(ref, reason: widget.expense == null ? 'expense_added' : 'expense_updated');
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final catsAsync = ref.watch(categoryListProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: ObsidianAppBar(
        title: Text(widget.expense != null ? 'Edit Transaction' : 'New Transaction'),
        actions: [
          IconButton(
            icon: const Icon(Icons.document_scanner_rounded),
            onPressed: _scanReceipt,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ResponsiveBody(
        child: catsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (cats) {
            final category = _categoryId != null 
                ? cats.firstWhere((c) => c.id == _categoryId, orElse: () => cats.first)
                : (cats.isNotEmpty ? cats.first : null);
            
            if (_categoryId == null && cats.isNotEmpty) {
              _categoryId = cats.first.id;
            }

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // Amount Hero (Digital Obsidian Style)
                _buildAmountHero(theme, scheme),
                
                const SizedBox(height: 32),
                
                // Form Sections
                _buildSectionHeader(theme, scheme, 'GENERAL'),
                const SizedBox(height: 12),
                ObsidianCard(
                  level: ObsidianCardTonalLevel.low,
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _buildFormRow(
                        icon: Icons.notes_rounded,
                        iconColor: scheme.secondary,
                        label: 'Note',
                        child: TextField(
                          controller: _noteCtrl,
                          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            hintText: 'Add a description...',
                            hintStyle: TextStyle(color: scheme.outline.withOpacity(0.3), fontWeight: FontWeight.w400),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const Divider(height: 1, indent: 56),
                      _buildFormRow(
                        icon: Icons.calendar_month_rounded,
                        iconColor: Colors.orangeAccent,
                        label: 'Date & Time',
                        value: _dateTimeFmt.format(_when),
                        onTap: _pickTime,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                _buildSectionHeader(theme, scheme, 'CATEGORY'),
                const SizedBox(height: 12),
                ObsidianCard(
                  level: ObsidianCardTonalLevel.low,
                  padding: EdgeInsets.zero,
                  child: _buildFormRow(
                    icon: resolveCategoryIcon(category?.iconKey),
                    iconColor: resolveCategoryColor(context, category?.color),
                    label: 'Classification',
                    value: category?.name ?? 'Select Category',
                    onTap: () => _showCategoryPicker(cats),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                _buildSectionHeader(theme, scheme, 'ADVANCED'),
                const SizedBox(height: 12),
                ObsidianCard(
                  level: ObsidianCardTonalLevel.low,
                  padding: EdgeInsets.zero,
                  child: _buildFormRow(
                    icon: Icons.repeat_rounded,
                    iconColor: Colors.blueAccent,
                    label: 'Recurring Transaction',
                    trailing: Switch(
                      value: _recurring,
                      onChanged: (v) => setState(() => _recurring = v),
                      activeColor: scheme.primary,
                    ),
                  ),
                ),
                
                const SizedBox(height: 48),
                
                ObsidianButton(
                  onPressed: _saving ? null : _save,
                  text: widget.expense != null ? 'UPDATE TRANSACTION' : 'CONFIRM TRANSACTION',
                  isLoading: _saving,
                  style: ObsidianButtonStyle.primary,
                ),
                const SizedBox(height: 100),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAmountHero(ThemeData theme, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Text(
            'TRANSACTION AMOUNT',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.primary.withOpacity(0.7),
              fontWeight: FontWeight.w800,
              fontSize: 10,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              GestureDetector(
                onTap: _showCurrencyPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: scheme.outline.withOpacity(0.1)),
                  ),
                  child: Text(
                    _currency,
                    style: GoogleFonts.manrope(
                      color: scheme.outline,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              IntrinsicWidth(
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                    fontSize: 56,
                    letterSpacing: -2,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, ColorScheme scheme, String title) {
    return Text(
      title,
      style: theme.textTheme.labelSmall?.copyWith(
        color: scheme.outline,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
        fontSize: 10,
      ),
    );
  }

  Widget _buildFormRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    String? value,
    Widget? child,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: iconColor.withOpacity(0.1)),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (child != null) child
                  else Text(
                    value ?? '',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing
            else if (onTap != null) Icon(Icons.chevron_right_rounded, color: theme.colorScheme.outline.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  void _showCurrencyPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131317),
      showDragHandle: true,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Select Currency', style: Theme.of(context).textTheme.titleMedium),
          ),
          ..._currencies.map((c) => ListTile(
            title: Text(c, textAlign: TextAlign.center, style: TextStyle(
              fontWeight: _currency == c ? FontWeight.bold : FontWeight.normal,
              color: _currency == c ? Theme.of(context).colorScheme.primary : null,
            )),
            onTap: () {
              setState(() => _currency = c);
              Navigator.pop(ctx);
            },
          )),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showCategoryPicker(List<Category> cats) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131317),
      showDragHandle: true,
      builder: (ctx) => ListView.builder(
        shrinkWrap: true,
        itemCount: cats.length,
        itemBuilder: (context, i) {
          final c = cats[i];
          final color = resolveCategoryColor(context, c.color);
          return ListTile(
            leading: Icon(resolveCategoryIcon(c.iconKey), color: color),
            title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            trailing: _categoryId == c.id ? Icon(Icons.check_circle_rounded, color: color) : null,
            onTap: () {
              setState(() => _categoryId = c.id);
              Navigator.pop(ctx);
            },
          );
        },
      ),
    );
  }
}
