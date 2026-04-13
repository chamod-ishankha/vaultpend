import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:isar_community/isar.dart';

import '../../core/logging/app_logging.dart';
import '../../core/notifications/reminder_sync_helper.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/obsidian_app_bar.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../data/models/subscription.dart';
import '../auth/auth_providers.dart';

class AddSubscriptionScreen extends ConsumerStatefulWidget {
  const AddSubscriptionScreen({super.key, this.subscription});

  /// When set, form edits this existing record.
  final Subscription? subscription;

  @override
  ConsumerState<AddSubscriptionScreen> createState() =>
      _AddSubscriptionScreenState();
}

class _AddSubscriptionScreenState extends ConsumerState<AddSubscriptionScreen> {
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  String _currency = 'USD';
  String _cycle = 'monthly';
  DateTime _nextBilling = DateTime.now();
  bool _trial = false;
  DateTime? _trialEnds;
  bool _saving = false;

  static const _currencies = ['LKR', 'USD', 'EUR', 'GBP', 'JPY'];
  static const _cycles = ['monthly', 'annual', 'weekly', 'custom'];
  static const _currencySymbols = {
    'LKR': 'Rs',
    'USD': r'$',
    'EUR': '€',
    'GBP': '£',
    'JPY': '¥',
  };
  static const _currencyLabels = {
    'LKR': 'SRI LANKAN RUPEE',
    'USD': 'US DOLLAR',
    'EUR': 'EURO',
    'GBP': 'POUND STERLING',
    'JPY': 'JAPANESE YEN',
  };
  static final _dateFmt = DateFormat('EEE, MMM d, yyyy');
  static final _dateTimeFmt = DateFormat('EEE, MMM d, yyyy · h:mm a');

  @override
  void initState() {
    super.initState();
    final s = widget.subscription;
    if (s != null) {
      _nameCtrl.text = s.name;
      _amountCtrl.text = s.amount.toStringAsFixed(2);
      _currency = s.currency;
      _cycle = s.cycle;
      _nextBilling = s.nextBillingDate;
      _trial = s.isTrial;
      _trialEnds = s.trialEndsAt;
    } else {
      _currency = ref.read(preferredCurrencyProvider);
      _amountCtrl.text = '0.00';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isTrial) async {
    final initial = isTrial ? (_trialEnds ?? DateTime.now()) : _nextBilling;
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(
            context,
          ).colorScheme.copyWith(surface: const Color(0xFF1B1B1F)),
        ),
        child: child!,
      ),
    );
    if (d == null || !mounted) return;
    setState(() {
      if (isTrial) {
        _trialEnds = d;
      } else {
        _nextBilling = d;
      }
    });
  }

  Future<void> _pickNextBillingDateTime() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _nextBilling,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(
            context,
          ).colorScheme.copyWith(surface: const Color(0xFF1B1B1F)),
        ),
        child: child!,
      ),
    );
    if (d == null || !mounted) return;

    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_nextBilling),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(
            context,
          ).colorScheme.copyWith(surface: const Color(0xFF1B1B1F)),
          timePickerTheme: const TimePickerThemeData(
            backgroundColor: Color(0xFF131317),
            hourMinuteColor: Color(0xFF2A292E),
          ),
        ),
        child: child!,
      ),
    );
    if (!mounted) return;

    setState(() {
      _nextBilling = DateTime(
        d.year,
        d.month,
        d.day,
        t?.hour ?? _nextBilling.hour,
        t?.minute ?? _nextBilling.minute,
      );
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a name')));
      return;
    }
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
      final repo = ref.read(subscriptionRepositoryProvider);
      final existing = widget.subscription;
      final s = Subscription()
        ..id = existing?.id ?? Isar.autoIncrement
        ..remoteId = existing?.remoteId
        ..name = name
        ..amount = amount
        ..currency = _currency
        ..cycle = _cycle
        ..nextBillingDate = _nextBilling
        ..isTrial = _trial
        ..trialEndsAt = _trial ? _trialEnds : null;

      await repo.put(s);

      final trialDetails = _trial
          ? (_trialEnds == null
                ? 'trial active'
                : 'trial ends ${DateFormat('MMM d, yyyy').format(_trialEnds!)}')
          : 'paid';

      await ref
          .read(activityLogServiceProvider)
          .add(
            action: existing == null
                ? 'Subscription added'
                : 'Subscription updated',
            details:
                '$name · ${s.currency} ${s.amount.toStringAsFixed(2)} · ${s.cycle} · $trialDetails',
          );

      await syncRemindersNow(
        ref,
        reason: existing == null
            ? 'subscription_added'
            : 'subscription_updated',
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save failed: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ext = theme.vaultSpend;
    final horizontalPadding = ext.addExpenseContentHorizontalPadding;
    final cardRadius = ext.addExpenseCardRadius;
    final iconTileSize = ext.addExpenseFormRowIconTileSize;
    final iconSize = ext.addExpenseFormRowIconSize;
    final amountSymbol = _currencySymbols[_currency] ?? _currency;
    final amountChipLabel =
        '$_currency - ${_currencyLabels[_currency] ?? _currency}';
    final currentAmount = _amountCtrl.text.trim();
    final amountTextColor = _isAmountEmptyOrZero(currentAmount)
        ? scheme.onSurface.withValues(alpha: 0.25)
        : scheme.onSurface;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: ObsidianAppBar(
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: scheme.primary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Subscription Details',
          style: theme.textTheme.titleLarge?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert_rounded, color: scheme.primary),
            onPressed: () {},
          ),
        ],
      ),
      body: ResponsiveBody(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                24,
                horizontalPadding,
                110,
              ),
              children: [
                Center(
                  child: Column(
                    children: [
                      Text(
                        'SUBSCRIPTION AMOUNT',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: _showCurrencyPicker,
                            child: Text(
                              amountSymbol,
                              style: theme.textTheme.displaySmall?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 36,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: ext.addExpenseAmountFieldWidth,
                            child: TextField(
                              controller: _amountCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              textAlign: TextAlign.left,
                              style: theme.textTheme.displayLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: amountTextColor,
                                fontSize: 56,
                                letterSpacing: -2,
                              ),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: '0.00',
                                hintStyle: TextStyle(
                                  color: scheme.surfaceContainerHighest,
                                ),
                              ),
                              onChanged: (_) => setState(() {}),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[\d.,]'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: _showCurrencyPicker,
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: ext.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: scheme.outlineVariant.withValues(
                                alpha: 0.2,
                              ),
                            ),
                          ),
                          child: Text(
                            amountChipLabel,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildFormTile(
                  icon: Icons.label_rounded,
                  iconColor: scheme.primary.withValues(alpha: 0.7),
                  label: 'Subscription Name',
                  cardRadius: cardRadius,
                  iconTileSize: iconTileSize,
                  iconSize: iconSize,
                  child: TextField(
                    controller: _nameCtrl,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. Adobe Creative Cloud',
                      hintStyle: TextStyle(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildFormTile(
                  icon: Icons.payments_rounded,
                  iconColor: scheme.primary.withValues(alpha: 0.7),
                  label: 'Currency',
                  value:
                      '$_currency (${_currencySymbols[_currency] ?? _currency})',
                  onTap: _showCurrencyPicker,
                  cardRadius: cardRadius,
                  iconTileSize: iconTileSize,
                  iconSize: iconSize,
                ),
                const SizedBox(height: 12),
                _buildFormTile(
                  icon: Icons.calendar_month_rounded,
                  iconColor: scheme.primary.withValues(alpha: 0.7),
                  label: 'Billing Cycle',
                  value: _formatCycle(_cycle),
                  onTap: _showCyclePicker,
                  cardRadius: cardRadius,
                  iconTileSize: iconTileSize,
                  iconSize: iconSize,
                ),
                const SizedBox(height: 12),
                _buildFormTile(
                  icon: Icons.event_rounded,
                  iconColor: scheme.primary.withValues(alpha: 0.7),
                  label: 'Next billing date & time',
                  value: _dateTimeFmt.format(_nextBilling),
                  onTap: _pickNextBillingDateTime,
                  cardRadius: cardRadius,
                  iconTileSize: iconTileSize,
                  iconSize: iconSize,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: ext.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(cardRadius),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: iconTileSize,
                        height: iconTileSize,
                        decoration: BoxDecoration(
                          color: scheme.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Icon(
                          Icons.timer_rounded,
                          color: scheme.error,
                          size: iconSize,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Trial Period',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Enable for free trial tracking',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _trial,
                        onChanged: (v) => setState(() => _trial = v),
                      ),
                    ],
                  ),
                ),
                if (_trial) ...[
                  const SizedBox(height: 12),
                  _buildFormTile(
                    icon: Icons.event_busy_rounded,
                    iconColor: scheme.primary.withValues(alpha: 0.7),
                    label: 'Trial ends at',
                    value: _trialEnds == null
                        ? 'Select date'
                        : _dateFmt.format(_trialEnds!),
                    onTap: () => _pickDate(true),
                    cardRadius: cardRadius,
                    iconTileSize: iconTileSize,
                    iconSize: iconSize,
                  ),
                ],
                const SizedBox(height: 28),
                _buildSaveButton(theme, scheme),
                const SizedBox(height: 10),
                Text(
                  'ENCRYPTED AND SECURED IN THE OBSIDIAN VAULT',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 2.2,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    String? value,
    Widget? child,
    VoidCallback? onTap,
    required double cardRadius,
    required double iconTileSize,
    required double iconSize,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ext = theme.vaultSpend;

    return Container(
      decoration: BoxDecoration(
        color: ext.surfaceContainerLow,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(cardRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: iconTileSize,
                  height: iconTileSize,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: iconSize),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (child != null)
                        child
                      else
                        Text(
                          value ?? '',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.expand_more_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton(ThemeData theme, ColorScheme scheme) {
    final ext = theme.vaultSpend;
    return Container(
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ext.addExpenseCardRadius),
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _saving ? null : _save,
          borderRadius: BorderRadius.circular(ext.addExpenseCardRadius),
          child: Center(
            child: _saving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: scheme.onPrimary,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Save Subscription',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: scheme.onPrimary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.check_circle_rounded,
                        size: 20,
                        color: scheme.onPrimary,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  String _formatCycle(String cycle) {
    if (cycle.isEmpty) return cycle;
    return '${cycle[0].toUpperCase()}${cycle.substring(1)}';
  }

  bool _isAmountEmptyOrZero(String raw) {
    if (raw.isEmpty) return true;
    final parsed = double.tryParse(raw.replaceAll(',', '.'));
    if (parsed == null) return false;
    return parsed == 0;
  }

  Future<T?> _showSelectionSheet<T>({
    required String title,
    required List<T> options,
    required T currentValue,
    required String Function(T) labelBuilder,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ext = theme.vaultSpend;

    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: const Color(0xFF131317),
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ext.addExpenseModalCornerRadius),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              ...options.asMap().entries.map((entry) {
                final idx = entry.key;
                final option = entry.value;
                final selected = option == currentValue;
                return Container(
                  margin: EdgeInsets.only(
                    bottom: idx == options.length - 1 ? 0 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? ext.surfaceContainerHigh
                        : ext.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(
                      ext.addExpenseModalOptionRadius,
                    ),
                    border: Border.all(
                      color: selected
                          ? scheme.primary.withValues(alpha: 0.35)
                          : scheme.outlineVariant.withValues(alpha: 0.2),
                    ),
                  ),
                  child: ListTile(
                    title: Text(
                      labelBuilder(option),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: selected ? scheme.primary : scheme.onSurface,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    onTap: () => Navigator.pop(ctx, option),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _showCurrencyPicker() {
    _showSelectionSheet<String>(
      title: 'Choose currency',
      options: _currencies,
      currentValue: _currency,
      labelBuilder: (c) => '$c (${_currencySymbols[c] ?? c})',
    ).then((selected) {
      if (selected == null) return;
      setState(() => _currency = selected);
    });
  }

  void _showCyclePicker() {
    _showSelectionSheet<String>(
      title: 'Choose billing cycle',
      options: _cycles,
      currentValue: _cycle,
      labelBuilder: _formatCycle,
    ).then((selected) {
      if (selected == null) return;
      setState(() => _cycle = selected);
    });
  }
}
