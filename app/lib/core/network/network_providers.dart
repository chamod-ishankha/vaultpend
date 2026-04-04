import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

bool _hasConnection(List<ConnectivityResult> results) {
  return results.any((result) => result != ConnectivityResult.none);
}

final networkOnlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  final initial = await connectivity.checkConnectivity();
  yield _hasConnection(initial);

  yield* connectivity.onConnectivityChanged.map(_hasConnection).distinct();
});
