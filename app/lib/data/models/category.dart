import 'package:isar_community/isar.dart';

part 'category.g.dart';

@collection
class Category {
  Id id = Isar.autoIncrement;

  @Index()
  String userId = '';

  late String name;

  String? iconKey;
  String? color;
}
