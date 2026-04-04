import 'package:isar_community/isar.dart';

part 'category_icon_catalog_entry.g.dart';

@collection
class CategoryIconCatalogEntry {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String iconKey;

  late String label;

  @Index()
  late int sortOrder;
}
