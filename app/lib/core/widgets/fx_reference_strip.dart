import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../fx/fx_providers.dart';

/// Display-only reference rates (Frankfurter v2; not financial advice).
class FxReferenceStrip extends ConsumerWidget {
  const FxReferenceStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(fxRatesProvider);
    final scheme = Theme.of(context).colorScheme;
    final dateFmt = DateFormat('MMM d, yyyy h:mm a');

    return async.when(
      data: (snap) {
        if (snap == null || snap.rates.isEmpty) {
          return _bar(
            context,
            scheme,
            'FX: offline — pull to refresh when online',
            isError: true,
          );
        }
        final eur = snap.rates['EUR'];
        final lkr = snap.rates['LKR'];
        final parts = <String>[
          if (eur != null) '1 ${snap.base} ≈ ${eur.toStringAsFixed(4)} EUR',
          if (lkr != null) '1 ${snap.base} ≈ ${lkr.toStringAsFixed(2)} LKR',
        ];
        final stale = snap.isStale ? ' · cached' : '';
        final line =
            '${parts.join(' · ')} · ${dateFmt.format(snap.date)}$stale';
        return _bar(context, scheme, line, isError: snap.isStale);
      },
      loading: () => _bar(context, scheme, 'FX: loading reference rates…'),
      error: (err, _) => _bar(
        context,
        scheme,
        'FX: unavailable — pull to refresh',
        isError: true,
      ),
    );
  }

  Widget _bar(
    BuildContext context,
    ColorScheme scheme,
    String text, {
    bool isError = false,
  }) {
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.currency_exchange,
              size: 18,
              color: isError ? scheme.error : scheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isError ? scheme.error : scheme.onSurfaceVariant,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
