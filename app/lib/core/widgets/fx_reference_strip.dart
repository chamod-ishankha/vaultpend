import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../fx/fx_providers.dart';

/// Display-only reference rates (Frankfurter v2; not financial advice).
class FxReferenceStrip extends ConsumerWidget {
  const FxReferenceStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(fxRatesProvider);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Row(
          children: [
            Row(
              children: [
                Text(
                  'FX RATES',
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: scheme.outline,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 1,
                  height: 12,
                  color: scheme.outlineVariant.withValues(alpha: 0.3),
                ),
                const SizedBox(width: 24),
              ],
            ),
            async.when(
              data: (snap) {
                if (snap == null || snap.rates.isEmpty) {
                  return _buildItem(
                    context,
                    scheme,
                    'OFFLINE',
                    'Pull to refresh',
                    isError: true,
                  );
                }

                // If base is USD, we convert it to pairs like EUR/USD
                final widgets = <Widget>[];
                snap.rates.forEach((currency, rate) {
                  widgets.add(
                    _buildItem(
                      context,
                      scheme,
                      '$currency/${snap.base}',
                      rate.toStringAsFixed(4),
                    ),
                  );
                  widgets.add(const SizedBox(width: 24));
                });

                if (snap.isStale) {
                  widgets.add(
                    _buildItem(
                      context,
                      scheme,
                      'CHCD',
                      'Cached Data',
                      isError: true,
                    ),
                  );
                }

                return Row(children: widgets);
              },
              loading: () => _buildItem(context, scheme, 'SYNC', 'Loading...'),
              error: (err, _) => _buildItem(
                context,
                scheme,
                'ERR',
                'Unavailable',
                isError: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    ColorScheme scheme,
    String label,
    String value, {
    bool isError = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isError ? scheme.error : scheme.onSurfaceVariant,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isError ? scheme.error : scheme.primary,
          ),
        ),
      ],
    );
  }
}
