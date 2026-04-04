import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:isar_community/isar.dart';

import '../../features/categories/category_icon_catalog.dart';
import '../../features/categories/category_icon_resolver.dart';
import '../models/category_icon_catalog_entry.dart';

class CategoryIconCatalogRepository {
  CategoryIconCatalogRepository(this._isar);

  final Isar _isar;

  Future<void> ensureSeeded() async {
    final count = await _isar.categoryIconCatalogEntrys.count();
    if (count > 0) {
      return;
    }

    final raw = await rootBundle.loadString(
      'assets/category_icon_catalog.json',
    );
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw StateError('category icon catalog seed must be a list');
    }

    final entries = decoded.map((item) {
      if (item is! Map<String, dynamic>) {
        throw StateError('category icon catalog seed item must be an object');
      }
      final iconKey = (item['icon_key'] as String?)?.trim() ?? '';
      final label = (item['label'] as String?)?.trim() ?? '';
      final sortOrder = item['sort_order'] as int? ?? 0;
      if (iconKey.isEmpty || label.isEmpty) {
        throw StateError(
          'category icon catalog seed item missing key or label',
        );
      }
      return CategoryIconCatalogEntry()
        ..iconKey = iconKey
        ..label = label
        ..sortOrder = sortOrder;
    }).toList();

    await _isar.writeTxn(() async {
      await _isar.categoryIconCatalogEntrys.putAll(entries);
    });
  }

  Future<List<CategoryIconOption>> getAllOptions() async {
    await ensureSeeded();
    final entries = await _isar.categoryIconCatalogEntrys
        .where()
        .sortBySortOrder()
        .findAll();
    return entries
        .map(
          (entry) => CategoryIconOption(
            key: entry.iconKey,
            label: entry.label,
            icon: resolveCategoryIcon(entry.iconKey),
          ),
        )
        .toList(growable: false);
  }
}
