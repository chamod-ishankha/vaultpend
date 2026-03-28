import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/subscription.dart';

final subscriptionListProvider =
    FutureProvider.autoDispose<List<Subscription>>((ref) {
  return ref.watch(subscriptionRepositoryProvider).getAll();
});
