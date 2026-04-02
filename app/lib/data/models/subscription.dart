import 'package:isar_community/isar.dart';

part 'subscription.g.dart';

@collection
class Subscription {
  Id id = Isar.autoIncrement;

  @Index()
  String userId = '';

  @Index()
  String? remoteId;

  late String name;

  late double amount;

  late String currency;

  late String cycle;

  late DateTime nextBillingDate;

  late bool isTrial;

  DateTime? trialEndsAt;
}
