import 'fx_snapshot.dart';

const supportedCurrencies = <String>{'USD', 'EUR', 'LKR'};

String normalizeCurrencyCode(String value) {
  final code = value.trim().toUpperCase();
  return supportedCurrencies.contains(code) ? code : 'USD';
}

double? convertCurrencyAmount({
  required double amount,
  required String from,
  required String to,
  required FxSnapshot? snapshot,
}) {
  final source = normalizeCurrencyCode(from);
  final target = normalizeCurrencyCode(to);
  if (source == target) {
    return amount;
  }
  if (snapshot == null) {
    return null;
  }

  final base = normalizeCurrencyCode(snapshot.base);
  final rates = snapshot.rates.map(
    (key, value) => MapEntry(normalizeCurrencyCode(key), value),
  );

  double? amountInBase;
  if (source == base) {
    amountInBase = amount;
  } else {
    final rateToSource = rates[source];
    if (rateToSource == null || rateToSource == 0) {
      return null;
    }
    amountInBase = amount / rateToSource;
  }

  if (target == base) {
    return amountInBase;
  }

  final rateToTarget = rates[target];
  if (rateToTarget == null) {
    return null;
  }
  return amountInBase * rateToTarget;
}
