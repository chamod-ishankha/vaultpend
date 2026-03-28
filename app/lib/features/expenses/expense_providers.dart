import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/expense.dart';

final expenseListProvider = FutureProvider.autoDispose<List<Expense>>((ref) {
  return ref.watch(expenseRepositoryProvider).getAll();
});
