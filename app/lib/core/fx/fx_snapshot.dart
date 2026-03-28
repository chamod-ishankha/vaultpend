/// Reference rates (Frankfurter v2, blended providers by default). Display only — not for accounting.
class FxSnapshot {
  FxSnapshot({
    required this.date,
    required this.base,
    required this.rates,
    this.isStale = false,
  });

  final DateTime date;
  final String base;
  /// Target currency code -> amount per 1 [base] (e.g. EUR, LKR per 1 USD).
  final Map<String, double> rates;
  final bool isStale;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'base': base,
        'rates': rates,
        'isStale': isStale,
      };

  factory FxSnapshot.fromJson(Map<String, dynamic> j) {
    final ratesRaw = j['rates'] as Map<String, dynamic>? ?? {};
    return FxSnapshot(
      date: DateTime.parse(j['date'] as String),
      base: j['base'] as String? ?? 'USD',
      rates: ratesRaw.map((k, v) => MapEntry(k, (v as num).toDouble())),
      isStale: j['isStale'] as bool? ?? false,
    );
  }
}
