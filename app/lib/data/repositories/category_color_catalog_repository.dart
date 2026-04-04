import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:isar_community/isar.dart';

import '../../features/categories/category_color_catalog.dart';
import '../models/category_color_catalog_entry.dart';

class CategoryColorCatalogRepository {
  CategoryColorCatalogRepository(this._isar);

  final Isar _isar;

  Future<void> ensureSeeded() async {
    final count = await _isar.collection<CategoryColorCatalogEntry>().count();
    if (count > 0) {
      return;
    }

    final raw = await rootBundle.loadString(
      'assets/category_color_catalog.json',
    );
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw StateError('category color catalog seed must be a list');
    }

    final entries = decoded.map((item) {
      if (item is! Map<String, dynamic>) {
        throw StateError('category color catalog seed item must be an object');
      }
      final colorKey = (item['color_key'] as String?)?.trim() ?? '';
      final label = (item['label'] as String?)?.trim() ?? '';
      final sortOrder = item['sort_order'] as int? ?? 0;
      if (colorKey.isEmpty || label.isEmpty) {
        throw StateError(
          'category color catalog seed item missing key or label',
        );
      }
      return CategoryColorCatalogEntry()
        ..colorKey = colorKey
        ..label = label
        ..sortOrder = sortOrder;
    }).toList();

    await _isar.writeTxn(() async {
      await _isar.categoryColorCatalogEntrys.putAll(entries);
    });
  }

  Future<List<CategoryColorOption>> getAllOptions() async {
    await ensureSeeded();
    final entries = await _isar
        .collection<CategoryColorCatalogEntry>()
        .where()
        .findAll();
    entries.sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
    return entries
        .map(
          (entry) =>
              CategoryColorOption(key: entry.colorKey, label: entry.label),
        )
        .toList(growable: false);
  }
}
