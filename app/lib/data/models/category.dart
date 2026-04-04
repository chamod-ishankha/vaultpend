import 'package:isar_community/isar.dart';

part 'category.g.dart';

@collection
class Category {
  Id id = Isar.autoIncrement;

  @Index()
  String userId = '';

  @Index()
  String? remoteId;

  late String name;

  String? description;
  String? iconKey;
  String? color;
}
