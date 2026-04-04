import 'package:connectivity_plus/connectivity_plus.dart';

DateTime? _cloudBypassUntil;

Future<bool> hasNetworkConnection() async {
  final results = await Connectivity().checkConnectivity().timeout(
    const Duration(milliseconds: 500),
    onTimeout: () => <ConnectivityResult>[ConnectivityResult.none],
  );
  return results.any((result) => result != ConnectivityResult.none);
}

bool shouldBypassCloudSync() {
  final until = _cloudBypassUntil;
  if (until == null) {
    return false;
  }
  return DateTime.now().isBefore(until);
}

void markCloudSyncFailure({Duration cooldown = const Duration(seconds: 20)}) {
  _cloudBypassUntil = DateTime.now().add(cooldown);
}

void markCloudSyncSuccess() {
  _cloudBypassUntil = null;
}
