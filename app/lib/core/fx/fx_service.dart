import 'dart:convert';

import 'package:http/http.dart' as http;

import 'fx_snapshot.dart';

/// Fetches reference FX from [Frankfurter v2](https://www.frankfurter.dev/docs/) (`api.frankfurter.dev`).
///
/// Uses an in-memory last-good snapshot only (no platform plugins) so refresh stays reliable.
class FxService {
  FxService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Latest rates: v2 returns a JSON **array** of `{date, base, quote, rate}` rows.
  /// See: `GET /v2/rates?base=USD&quotes=EUR,LKR`
  static final _uri = Uri.parse(
    'https://api.frankfurter.dev/v2/rates?base=USD&quotes=EUR,LKR',
  );

  /// Last successful fetch this session; used when network fails.
  static FxSnapshot? _memoryCache;

  Future<FxSnapshot?> fetchWithCache() async {
    try {
      final res = await _client.get(_uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) {
        return _staleFromMemory();
      }
      final decoded = jsonDecode(res.body);
      final snap = _snapshotFromV2Rates(decoded);
      if (snap == null) {
        return _staleFromMemory();
      }
      _memoryCache = snap;
      return snap;
    } catch (_) {
      return _staleFromMemory();
    }
  }

  /// Parses v2 `/v2/rates` JSON array into [FxSnapshot].
  static FxSnapshot? _snapshotFromV2Rates(dynamic decoded) {
    if (decoded is! List || decoded.isEmpty) return null;

    final rates = <String, double>{};
    DateTime? date;
    var base = 'USD';

    for (final item in decoded) {
      if (item is! Map<String, dynamic>) continue;
      final quote = item['quote'] as String?;
      final rate = item['rate'];
      if (quote == null || rate is! num) continue;
      rates[quote] = rate.toDouble();
      date ??= DateTime.tryParse(item['date'] as String? ?? '');
      base = item['base'] as String? ?? base;
    }

    if (rates.isEmpty || date == null) return null;

    return FxSnapshot(date: date, base: base, rates: rates);
  }

  FxSnapshot? _staleFromMemory() {
    final last = _memoryCache;
    if (last == null) return null;
    return FxSnapshot(
      date: last.date,
      base: last.base,
      rates: last.rates,
      isStale: true,
    );
  }
}
