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
import '../../core/theme/app_theme.dart';
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
  static const _currencyNames = {
    'LKR': 'SRI LANKAN RUPEE',
    'USD': 'US DOLLAR',
    'EUR': 'EURO',
    'GBP': 'POUND STERLING',
    'JPY': 'JAPANESE YEN',
  };
  static const _currencySymbols = {
    'LKR': 'Rs',
    'USD': r'$',
    'EUR': 'EUR',
    'GBP': 'GBP',
    'JPY': 'JPY',
  };
  static final _dateTimeCardFmt = DateFormat('MM/dd/yyyy, hh:mm a');

  String _currencySymbol() => _currencySymbols[_currency] ?? _currency;

  String _currencyLabel() {
    final name = _currencyNames[_currency] ?? _currency;
    return '$_currency - $name';
  }

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
    final scheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).vaultSpend;
    final d = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            surface: ext.surfaceContainerLow,
            primary: scheme.primary,
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
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            surface: ext.surfaceContainerLow,
            primary: scheme.primary,
            onPrimary: scheme.onPrimary,
          ),
          timePickerTheme: TimePickerThemeData(
            backgroundColor: ext.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                ext.addExpenseModalCornerRadius,
              ),
            ),
          ),
        ),
        child: child!,
      ),
    );
    if (t == null || !mounted) return;
    setState(() {
      _when = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  Future<void> _scanReceipt() async {
    final appLogger = ref.read(appLoggerProvider);
    appLogger.info('receipt_scan_sheet_opened');
    final scheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).vaultSpend;

    final source = await showModalBottomSheet<ImageSource?>(
      context: context,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ext.addExpenseModalCornerRadius),
        ),
      ),
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
    final scheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).vaultSpend;

    return showModalBottomSheet<double?>(
      context: context,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ext.addExpenseModalCornerRadius),
        ),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Confirm Amount',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < candidates.length; i++)
                  ListTile(
                    onTap: () => setSheetState(() => selectedIndex = i),
                    leading: Icon(
                      selectedIndex == i
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: selectedIndex == i
                          ? scheme.primary
                          : scheme.outline,
                    ),
                    title: Text(candidates[i].amount.toStringAsFixed(2)),
                    subtitle: Text(candidates[i].line, maxLines: 1),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.of(ctx).pop(candidates[selectedIndex].amount),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
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
            action: widget.expense == null
                ? 'Expense added'
                : 'Expense updated',
            details:
                '$categoryName · ${e.currency} ${e.amount.toStringAsFixed(2)} · ${_recurring ? 'recurring' : 'one-time'}${e.note == null ? '' : ' · ${e.note}'}',
          );
      await syncRemindersNow(
        ref,
        reason: widget.expense == null ? 'expense_added' : 'expense_updated',
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ext = theme.vaultSpend;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final isEditing = widget.expense != null;
    final catsAsync = ref.watch(categoryListProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: ObsidianAppBar(
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          isEditing ? 'Edit Expense' : 'Add Expense',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: scheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.document_scanner_rounded),
            color: scheme.primary,
            onPressed: _scanReceipt,
            tooltip: 'Scan receipt',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ResponsiveBody(
        child: Column(
          children: [
            Expanded(
              child: catsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (cats) {
                  Category? category;
                  if (cats.isNotEmpty) {
                    if (_categoryId != null) {
                      for (final c in cats) {
                        if (c.id == _categoryId) {
                          category = c;
                          break;
                        }
                      }
                    }
                    category ??= cats.first;
                  }

                  if (_categoryId == null && cats.isNotEmpty) {
                    _categoryId = cats.first.id;
                  }

                  return ListView(
                    padding: EdgeInsets.fromLTRB(
                      ext.addExpenseContentHorizontalPadding,
                      8,
                      ext.addExpenseContentHorizontalPadding,
                      ext.addExpenseBottomActionSpacing + bottomInset,
                    ),
                    children: [
                      _buildAmountHero(theme, scheme, ext),

                      SizedBox(height: ext.addExpenseSectionSpacing),

                      _buildCategoryCurrencyBlock(
                        theme,
                        scheme,
                        ext,
                        category,
                        cats,
                      ),

                      SizedBox(height: ext.addExpenseCardGap),

                      _buildDateTimeCard(theme, scheme, ext),

                      SizedBox(height: ext.addExpenseCardGap),

                      _buildRecurringCard(theme, scheme, ext),

                      SizedBox(height: ext.addExpenseCardGap),

                      _buildNoteCard(theme, scheme, ext),

                      SizedBox(height: ext.addExpenseCardGap),

                      _buildReceiptTiles(theme, scheme, ext),

                      SizedBox(height: ext.addExpenseSectionSpacing),

                      ObsidianButton(
                        onPressed: _saving ? null : _save,
                        text: isEditing ? 'Update Expense' : 'Save Expense',
                        isLoading: _saving,
                        enableShimmer: true,
                        style: ObsidianButtonStyle.primary,
                      ),

                      const SizedBox(height: 12),

                      Text(
                        'ENCRYPTED AND SECURED IN THE OBSIDIAN VAULT',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                          letterSpacing: 2.2,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountHero(
    ThemeData theme,
    ColorScheme scheme,
    VaultSpendThemeExtension ext,
  ) {
    final currentAmount = _amountCtrl.text.trim();
    final amountTextColor = (currentAmount.isEmpty || currentAmount == '0.00')
        ? scheme.onSurface.withValues(alpha: 0.25)
        : scheme.onSurface;

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: ext.addExpenseAmountHeroVerticalPadding,
      ),
      child: Column(
        children: [
          Text(
            'TRANSACTION AMOUNT',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              fontSize: 10,
              letterSpacing: 2.6,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _currencySymbol(),
                style: GoogleFonts.manrope(
                  color: scheme.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 34,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: ext.addExpenseAmountFieldWidth,
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.left,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    color: amountTextColor,
                    fontSize: ext.addExpenseAmountFontSize,
                    letterSpacing: -1.8,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: '0.00',
                  ),
                  onChanged: (_) => setState(() {}),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _showCurrencyPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: ext.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(
                  ext.addExpenseCurrencyChipRadius,
                ),
                border: Border.all(
                  color: scheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                _currencyLabel(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 8.5,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCurrencyBlock(
    ThemeData theme,
    ColorScheme scheme,
    VaultSpendThemeExtension ext,
    Category? category,
    List<Category> cats,
  ) {
    Widget card({
      required String label,
      required Widget content,
      VoidCallback? onTap,
    }) {
      return ObsidianCard(
        level: ObsidianCardTonalLevel.low,
        borderRadius: ext.addExpenseCardRadius,
        padding: const EdgeInsets.all(16),
        showTopBorder: false,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                fontSize: 9,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            content,
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 680;

        final categoryCard = card(
          label: 'CATEGORY',
          onTap: () => _showCategoryPicker(cats),
          content: Row(
            children: [
              Icon(
                resolveCategoryIcon(category?.iconKey),
                color: resolveCategoryColor(context, category?.color),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  category?.name ?? 'Select Category',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.expand_more_rounded,
                color: scheme.onSurfaceVariant,
                size: 18,
              ),
            ],
          ),
        );

        final currencyCard = card(
          label: 'CURRENCY',
          onTap: _showCurrencyPicker,
          content: Row(
            children: [
              Expanded(
                child: Text(
                  '$_currency (${_currencySymbol()})',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Icon(
                Icons.payments_outlined,
                color: scheme.onSurfaceVariant,
                size: 18,
              ),
            ],
          ),
        );

        if (isWide) {
          return Row(
            children: [
              Expanded(child: categoryCard),
              SizedBox(width: ext.addExpenseSplitCardGap),
              Expanded(child: currencyCard),
            ],
          );
        }

        return Column(
          children: [
            categoryCard,
            SizedBox(height: ext.addExpenseSplitCardGap),
            currencyCard,
          ],
        );
      },
    );
  }

  Widget _buildDateTimeCard(
    ThemeData theme,
    ColorScheme scheme,
    VaultSpendThemeExtension ext,
  ) {
    return ObsidianCard(
      level: ObsidianCardTonalLevel.low,
      borderRadius: ext.addExpenseCardRadius,
      padding: const EdgeInsets.all(16),
      showTopBorder: false,
      onTap: _pickTime,
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_rounded,
            color: scheme.primary.withValues(alpha: 0.7),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DATE & TIME',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _dateTimeCardFmt.format(_when),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.event_outlined, color: scheme.onSurfaceVariant, size: 18),
        ],
      ),
    );
  }

  Widget _buildRecurringCard(
    ThemeData theme,
    ColorScheme scheme,
    VaultSpendThemeExtension ext,
  ) {
    return ObsidianCard(
      level: ObsidianCardTonalLevel.high,
      borderRadius: ext.addExpenseCardRadius,
      padding: const EdgeInsets.all(16),
      showTopBorder: false,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primary.withValues(alpha: 0.12),
            ),
            child: Icon(Icons.event_repeat, color: scheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recurring Expense',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Automatically repeat this charge',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _recurring,
            onChanged: (v) => setState(() => _recurring = v),
            activeThumbColor: scheme.onPrimary,
            activeTrackColor: scheme.primaryContainer,
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(
    ThemeData theme,
    ColorScheme scheme,
    VaultSpendThemeExtension ext,
  ) {
    return ObsidianCard(
      level: ObsidianCardTonalLevel.low,
      borderRadius: ext.addExpenseCardRadius,
      padding: const EdgeInsets.all(16),
      showTopBorder: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NOTE',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              fontSize: 9,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _noteCtrl,
            maxLines: 3,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'Add a description or tag people...',
              hintStyle: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptTiles(
    ThemeData theme,
    ColorScheme scheme,
    VaultSpendThemeExtension ext,
  ) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _scanReceipt,
            child: Container(
              height: ext.addExpenseReceiptTileHeight,
              decoration: BoxDecoration(
                color: ext.surfaceContainerLow,
                borderRadius: BorderRadius.circular(ext.addExpenseCardRadius),
                border: Border.all(
                  color: scheme.outline.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_a_photo_outlined,
                    color: scheme.onSurfaceVariant,
                    size: 18,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'ADD RECEIPT',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontSize: 8,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: ext.addExpenseReceiptTileHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ext.addExpenseCardRadius),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scheme.surfaceContainerHigh,
                  scheme.surfaceContainerLow,
                ],
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    Icons.receipt_long,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                    size: 30,
                  ),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 8,
                  child: Text(
                    'CURRENT RECEIPT',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurface,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<T?> _showSelectionSheet<T>({
    required String title,
    required List<T> options,
    required String Function(T option) labelBuilder,
    Widget Function(T option)? leadingBuilder,
    bool Function(T option)? selectedPredicate,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).vaultSpend;

    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: scheme.surface,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ext.addExpenseModalCornerRadius),
        ),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final option = options[i];
                      final selected = selectedPredicate?.call(option) ?? false;

                      return Material(
                        color: selected
                            ? ext.surfaceContainerHigh
                            : ext.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(
                          ext.addExpenseModalOptionRadius,
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(
                            ext.addExpenseModalOptionRadius,
                          ),
                          onTap: () => Navigator.of(ctx).pop(option),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                ext.addExpenseModalOptionRadius,
                              ),
                              border: Border.all(
                                color: selected
                                    ? scheme.primary.withValues(alpha: 0.45)
                                    : scheme.outline.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                if (leadingBuilder != null) ...[
                                  leadingBuilder(option),
                                  const SizedBox(width: 10),
                                ],
                                Expanded(
                                  child: Text(
                                    labelBuilder(option),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontWeight: selected
                                              ? FontWeight.w700
                                              : FontWeight.w600,
                                          color: selected
                                              ? scheme.primary
                                              : scheme.onSurface,
                                        ),
                                  ),
                                ),
                                if (selected)
                                  Icon(
                                    Icons.check_circle_rounded,
                                    size: 18,
                                    color: scheme.primary,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCurrencyPicker() async {
    final selected = await _showSelectionSheet<String>(
      title: 'Select Currency',
      options: _currencies,
      labelBuilder: (c) => '$c (${_currencySymbols[c] ?? c})',
      selectedPredicate: (c) => c == _currency,
    );
    if (selected == null || !mounted) return;
    setState(() => _currency = selected);
  }

  Future<void> _showCategoryPicker(List<Category> cats) async {
    final selected = await _showSelectionSheet<Category>(
      title: 'Select Category',
      options: cats,
      labelBuilder: (c) => c.name,
      selectedPredicate: (c) => c.id == _categoryId,
      leadingBuilder: (c) => Icon(
        resolveCategoryIcon(c.iconKey),
        color: resolveCategoryColor(context, c.color),
        size: 18,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _categoryId = selected.id);
  }
}
