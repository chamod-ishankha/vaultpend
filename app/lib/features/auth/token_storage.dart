import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kGuestMode = 'vaultspend_guest_mode';

class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
    : _s =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  final FlutterSecureStorage _s;

  Future<bool> readGuestMode() async {
    final value = await _s.read(key: _kGuestMode);
    return value == 'true';
  }

  Future<void> writeGuestMode(bool enabled) =>
      _s.write(key: _kGuestMode, value: enabled ? 'true' : 'false');

  Future<void> clearGuestMode() => _s.delete(key: _kGuestMode);
}
