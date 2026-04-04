import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:isar_community/isar.dart';

import '../../core/logging/app_logging.dart';
import '../../core/notifications/reminder_sync_helper.dart';
import '../../core/providers.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../data/models/subscription.dart';

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

  static const _currencies = ['LKR', 'USD', 'EUR'];
  static const _cycles = ['monthly', 'annual', 'custom'];
  static final _dateTimeFmt = DateFormat('MMM d, yyyy h:mm a');

  @override
  void initState() {
    super.initState();
    final s = widget.subscription;
    if (s != null) {
      _nameCtrl.text = s.name;
      _amountCtrl.text = _formatAmount(s.amount);
      _currency = s.currency;
      _cycle = s.cycle;
      _nextBilling = s.nextBillingDate;
      _trial = s.isTrial;
      _trialEnds = s.trialEndsAt;
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
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickNextBilling() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _nextBilling,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_nextBilling),
    );
    if (t == null || !mounted) return;
    setState(() {
      _nextBilling = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  Future<void> _pickTrialEnd() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _trialEnds ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return;
    final existing = _trialEnds ?? DateTime.now();
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(existing),
    );
    if (t == null || !mounted) return;
    setState(
      () => _trialEnds = DateTime(d.year, d.month, d.day, t.hour, t.minute),
    );
  }

  Future<void> _save() async {
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
              : 'trial ends ${DateFormat('MMM d, yyyy').format(_trialEnds!.toLocal())}')
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.subscription != null
              ? 'Edit subscription'
              : 'Add subscription',
        ),
      ),
      body: ResponsiveBody(
        maxWidth: 760,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              autofocus: widget.subscription == null,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Amount per cycle',
                border: OutlineInputBorder(),
              ),
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
            DropdownButtonFormField<String>(
              initialValue: _cycle,
              decoration: const InputDecoration(
                labelText: 'Billing cycle',
                border: OutlineInputBorder(),
              ),
              items: _cycles
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _cycle = v ?? 'monthly'),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Next billing date & time'),
              subtitle: Text(_dateTimeFmt.format(_nextBilling.toLocal())),
              onTap: _pickNextBilling,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Trial'),
              value: _trial,
              onChanged: (v) => setState(() {
                _trial = v;
                if (!v) _trialEnds = null;
              }),
            ),
            if (_trial) ...[
              ListTile(
                title: const Text('Trial ends at'),
                subtitle: Text(
                  _trialEnds == null
                      ? 'Not set'
                      : _dateTimeFmt.format(_trialEnds!.toLocal()),
                ),
                onTap: _pickTrialEnd,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _save,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
