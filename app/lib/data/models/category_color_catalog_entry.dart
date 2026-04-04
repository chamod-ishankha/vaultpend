import 'package:isar_community/isar.dart';

part 'category_color_catalog_entry.g.dart';

@collection
class CategoryColorCatalogEntry {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String colorKey;

  late String label;

  @Index()
  late int sortOrder;
}
