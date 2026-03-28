import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'fx_service.dart';
import 'fx_snapshot.dart';

final fxServiceProvider = Provider<FxService>((ref) => FxService());

final fxRatesProvider = FutureProvider<FxSnapshot?>((ref) async {
  return ref.watch(fxServiceProvider).fetchWithCache();
});
