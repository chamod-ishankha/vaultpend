import 'package:isar_community/isar.dart';

part 'expense.g.dart';

@collection
class Expense {
  Id id = Isar.autoIncrement;

  @Index()
  String userId = '';

  int? categoryId;

  late double amount;

  late String currency;

  late DateTime occurredAt;

  String? note;

  late bool isRecurring;
}
