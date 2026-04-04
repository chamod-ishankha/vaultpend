import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../core/notifications/subscription_reminder_service.dart';
import '../data/models/category.dart';
import '../data/models/category_icon_catalog_entry.dart';
import '../data/models/category_color_catalog_entry.dart';
import '../data/models/expense.dart';
import '../data/models/subscription.dart';
import '../data/repositories/category_repository.dart';
import '../data/repositories/category_color_catalog_repository.dart';
import '../data/repositories/category_icon_catalog_repository.dart';
import '../data/repositories/expense_repository.dart';
import '../data/repositories/subscription_repository.dart';
import '../features/auth/auth_providers.dart';
import '../features/categories/category_icon_catalog.dart';
import '../features/categories/category_color_catalog.dart';

/// Set in [main] via [ProviderScope] override after [Isar.open].
final isarProvider = Provider<Isar>((ref) {
  throw StateError('isarProvider must be overridden in main()');
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final reminderServiceProvider = Provider<SubscriptionReminderService>((ref) {
  return SubscriptionReminderService();
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  final signedIn = ref.watch(authControllerProvider).value != null;
  if (uid == null) {
    throw StateError('categoryRepositoryProvider requires active user scope');
  }
  return CategoryRepository(
    ref.watch(isarProvider),
    uid,
    firestore: ref.watch(firestoreProvider),
    cloudSyncEnabled: signedIn,
  );
});

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  final signedIn = ref.watch(authControllerProvider).value != null;
  if (uid == null) {
    throw StateError('expenseRepositoryProvider requires active user scope');
  }
  return ExpenseRepository(
    ref.watch(isarProvider),
    uid,
    firestore: ref.watch(firestoreProvider),
    cloudSyncEnabled: signedIn,
  );
});

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  final signedIn = ref.watch(authControllerProvider).value != null;
  if (uid == null) {
    throw StateError(
      'subscriptionRepositoryProvider requires active user scope',
    );
  }
  return SubscriptionRepository(
    ref.watch(isarProvider),
    uid,
    firestore: ref.watch(firestoreProvider),
    cloudSyncEnabled: signedIn,
  );
});

final categoryIconCatalogRepositoryProvider =
    Provider<CategoryIconCatalogRepository>((ref) {
      return CategoryIconCatalogRepository(ref.watch(isarProvider));
    });

final categoryIconCatalogProvider =
    FutureProvider.autoDispose<List<CategoryIconOption>>((ref) async {
      return ref.watch(categoryIconCatalogRepositoryProvider).getAllOptions();
    });

final categoryColorCatalogRepositoryProvider =
    Provider<CategoryColorCatalogRepository>((ref) {
      return CategoryColorCatalogRepository(ref.watch(isarProvider));
    });

final categoryColorCatalogProvider =
    FutureProvider.autoDispose<List<CategoryColorOption>>((ref) async {
      return ref.watch(categoryColorCatalogRepositoryProvider).getAllOptions();
    });

final categoryListProvider = FutureProvider.autoDispose<List<Category>>((
  ref,
) async {
  return ref.watch(categoryRepositoryProvider).getAll();
});

Future<Isar> openIsar() async {
  final directory = (await getApplicationDocumentsDirectory()).path;
  return Isar.open(
    [
      CategorySchema,
      CategoryIconCatalogEntrySchema,
      CategoryColorCatalogEntrySchema,
      ExpenseSchema,
      SubscriptionSchema,
    ],
    directory: directory,
    name: 'vaultspend',
  );
}
