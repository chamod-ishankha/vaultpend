import 'package:flutter/material.dart';

const _iconByKey = <String, IconData>{
  'category': Icons.category_outlined,
  'shopping': Icons.shopping_cart_outlined,
  'shopping_bag': Icons.shopping_bag_outlined,
  'grocery': Icons.local_grocery_store_outlined,
  'food': Icons.restaurant_outlined,
  'drink': Icons.local_drink_outlined,
  'coffee': Icons.coffee_outlined,
  'transport': Icons.directions_car_outlined,
  'travel': Icons.flight_outlined,
  'fuel': Icons.local_gas_station_outlined,
  'home': Icons.home_outlined,
  'rent': Icons.home_work_outlined,
  'utilities': Icons.power_outlined,
  'electricity': Icons.bolt_outlined,
  'water': Icons.water_drop_outlined,
  'internet': Icons.wifi_outlined,
  'phone': Icons.smartphone_outlined,
  'medical': Icons.local_hospital_outlined,
  'health': Icons.health_and_safety_outlined,
  'insurance': Icons.verified_user_outlined,
  'education': Icons.school_outlined,
  'books': Icons.menu_book_outlined,
  'work': Icons.work_outline,
  'salary': Icons.payments_outlined,
  'income': Icons.account_balance_wallet_outlined,
  'savings': Icons.savings_outlined,
  'gift': Icons.card_giftcard_outlined,
  'entertainment': Icons.movie_outlined,
  'music': Icons.music_note_outlined,
  'game': Icons.sports_esports_outlined,
  'sports': Icons.sports_soccer_outlined,
  'clothing': Icons.checkroom_outlined,
  'beauty': Icons.spa_outlined,
  'pet': Icons.pets_outlined,
  'subscription': Icons.subscriptions_outlined,
  'receipt': Icons.receipt_long_outlined,
  'receipt_long_outlined': Icons.receipt_long_outlined,
  'development': Icons.code_outlined,
  'code': Icons.code_outlined,
};

String normalizeIconKey(String raw) {
  var key = raw.trim().toLowerCase();
  if (key.startsWith('icons.')) {
    key = key.substring('icons.'.length);
  }
  if (key.endsWith('_rounded')) {
    key = key.substring(0, key.length - '_rounded'.length);
  }
  if (key.endsWith('_sharp')) {
    key = key.substring(0, key.length - '_sharp'.length);
  }
  return key;
}

IconData resolveCategoryIcon(String? iconKey) {
  final normalized = normalizeIconKey(iconKey ?? '');
  return _iconByKey[normalized] ?? Icons.category_outlined;
}

bool isKnownCategoryIconKey(String? iconKey) {
  final normalized = normalizeIconKey(iconKey ?? '');
  if (normalized.isEmpty) {
    return true;
  }
  return _iconByKey.containsKey(normalized);
}
