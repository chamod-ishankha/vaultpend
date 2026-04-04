import 'package:flutter/material.dart';

String normalizeCategoryColorKey(String raw) {
  return raw.trim().toLowerCase();
}

bool isKnownCategoryColorKey(String? colorKey) {
  switch (normalizeCategoryColorKey(colorKey ?? '')) {
    case '':
    case 'primary_container':
    case 'secondary_container':
    case 'tertiary_container':
    case 'error_container':
    case 'surface_container_highest':
      return true;
    default:
      return _isHexColor(colorKey);
  }
}

Color resolveCategoryColor(BuildContext context, String? colorKey) {
  final scheme = Theme.of(context).colorScheme;
  final normalized = normalizeCategoryColorKey(colorKey ?? '');
  switch (normalized) {
    case 'primary_container':
      return scheme.primaryContainer;
    case 'secondary_container':
      return scheme.secondaryContainer;
    case 'tertiary_container':
      return scheme.tertiaryContainer;
    case 'error_container':
      return scheme.errorContainer;
    case 'surface_container_highest':
      return scheme.surfaceContainerHighest;
    default:
      return _parseHexColor(colorKey);
  }
}

Color _parseHexColor(String? raw) {
  var value = raw?.trim() ?? '';
  if (value.startsWith('#')) {
    value = value.substring(1);
  }
  if (value.length != 6) {
    return Colors.grey;
  }
  final parsed = int.tryParse(value, radix: 16);
  if (parsed == null) {
    return Colors.grey;
  }
  return Color(0xFF000000 | parsed);
}

bool _isHexColor(String? raw) {
  var value = raw?.trim() ?? '';
  if (value.startsWith('#')) {
    value = value.substring(1);
  }
  return RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(value);
}
