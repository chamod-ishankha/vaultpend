import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../data/models/category.dart';
import '../data/models/expense.dart';
import '../data/models/subscription.dart';
import '../data/repositories/category_repository.dart';
import '../data/repositories/expense_repository.dart';
import '../data/repositories/subscription_repository.dart';
import '../features/auth/auth_providers.dart';

/// Set in [main] via [ProviderScope] override after [Isar.open].
final isarProvider = Provider<Isar>((ref) {
  throw StateError('isarProvider must be overridden in main()');
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) {
    throw StateError('categoryRepositoryProvider requires signed-in user');
  }
  return CategoryRepository(ref.watch(isarProvider), uid);
});

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) {
    throw StateError('expenseRepositoryProvider requires signed-in user');
  }
  return ExpenseRepository(ref.watch(isarProvider), uid);
});

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) {
    throw StateError('subscriptionRepositoryProvider requires signed-in user');
  }
  return SubscriptionRepository(ref.watch(isarProvider), uid);
});

final categoryListProvider =
    FutureProvider.autoDispose<List<Category>>((ref) async {
  return ref.watch(categoryRepositoryProvider).getAll();
});

Future<Isar> openIsar() async {
  final dir = await getApplicationDocumentsDirectory();
  return Isar.open(
    [CategorySchema, ExpenseSchema, SubscriptionSchema],
    directory: dir.path,
    name: 'vaultspend',
  );
}
