import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:isar_community/isar.dart';

import '../../core/logging/app_logging.dart';
import '../../core/notifications/reminder_sync_helper.dart';
import '../../core/providers.dart';
import '../../core/widgets/obsidian_app_bar.dart';
import '../../core/widgets/obsidian_button.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../core/widgets/obsidian_card.dart';
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
  static const _cycles = ['monthly', 'annual', 'weekly'];
  static final _dateFmt = DateFormat('EEEE, MMM d, yyyy');

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

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: ObsidianAppBar(
        title: Text(
          widget.subscription != null
              ? 'Edit Subscription'
              : 'New Subscription',
        ),
      ),
      body: ResponsiveBody(
        child: Column(
          children: [
            // Amount Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              child: Column(
                children: [
                  Text(
                    'SUBSCRIPTION AMOUNT',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.primary.withOpacity(0.7),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      GestureDetector(
                        onTap: _showCurrencyPicker,
                        child: Text(
                          _currency,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: scheme.outline,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IntrinsicWidth(
                        child: TextField(
                          controller: _amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.displayLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: scheme.onSurface,
                            fontSize: 56,
                            letterSpacing: -2,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[\d.,]'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Text(
                    'SERVICE DETAILS',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.outline,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ObsidianCard(
                    level: ObsidianCardTonalLevel.low,
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _buildFormRow(
                          icon: Icons.subscriptions_rounded,
                          iconColor: scheme.primary,
                          label: 'Service Name',
                          child: TextField(
                            controller: _nameCtrl,
                            style: theme.textTheme.bodyLarge,
                            decoration: InputDecoration(
                              hintText: 'e.g. Netflix, Spotify',
                              hintStyle: TextStyle(
                                color: scheme.outline.withOpacity(0.5),
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                        const Divider(height: 1, indent: 56),
                        _buildFormRow(
                          icon: Icons.repeat_rounded,
                          iconColor: Colors.blueAccent,
                          label: 'Billing Cycle',
                          value: _cycle.toUpperCase(),
                          onTap: _showCyclePicker,
                        ),
                        const Divider(height: 1, indent: 56),
                        _buildFormRow(
                          icon: Icons.calendar_today_rounded,
                          iconColor: Colors.orangeAccent,
                          label: 'First Billing',
                          value: _dateFmt.format(_nextBilling),
                          onTap: () => _pickDate(false),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'TRIAL MONITORING',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.outline,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ObsidianCard(
                    level: ObsidianCardTonalLevel.low,
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _buildFormRow(
                          icon: Icons.hourglass_top_rounded,
                          iconColor: Colors.amberAccent,
                          label: 'Trial Status',
                          trailing: Switch(
                            value: _trial,
                            onChanged: (v) => setState(() => _trial = v),
                            activeThumbColor: Colors.amberAccent,
                          ),
                        ),
                        if (_trial) ...[
                          const Divider(height: 1, indent: 56),
                          _buildFormRow(
                            icon: Icons.alarm_on_rounded,
                            iconColor: Colors.amberAccent,
                            label: 'Trial Ends On',
                            value: _trialEnds == null
                                ? 'Not set'
                                : _dateFmt.format(_trialEnds!),
                            onTap: () => _pickDate(true),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  ObsidianButton(
                    onPressed: _saving ? null : _save,
                    text: widget.subscription != null
                        ? 'UPDATE SUBSCRIPTION'
                        : 'SAVE SUBSCRIPTION',
                    isLoading: _saving,
                    style: ObsidianButtonStyle.primary,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
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
                  const SizedBox(height: 2),
                  if (child != null)
                    child
                  else
                    Text(
                      value ?? '',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null)
              trailing
            else if (onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.outline.withOpacity(0.5),
              ),
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
          ..._currencies.map(
            (c) => ListTile(
              title: Text(c, textAlign: TextAlign.center),
              onTap: () {
                setState(() => _currency = c);
                Navigator.pop(ctx);
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showCyclePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131317),
      showDragHandle: true,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ..._cycles.map(
            (c) => ListTile(
              title: Text(c.toUpperCase(), textAlign: TextAlign.center),
              onTap: () {
                setState(() => _cycle = c);
                Navigator.pop(ctx);
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
