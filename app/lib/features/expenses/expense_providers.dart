import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/expense.dart';

final expenseListProvider = FutureProvider.autoDispose<List<Expense>>((ref) {
  return ref.watch(expenseRepositoryProvider).getAll().then((items) {
    // Guard against legacy/local duplicates that share the same remote id.
    final seenRemoteIds = <String>{};
    final deduped = <Expense>[];

    for (final item in items) {
      final remoteId = item.remoteId;
      if (remoteId != null && remoteId.isNotEmpty) {
        if (!seenRemoteIds.add(remoteId)) {
          continue;
        }
      }
      deduped.add(item);
    }

    return deduped;
  });
});
