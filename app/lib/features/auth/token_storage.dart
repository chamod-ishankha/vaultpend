import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kAccessToken = 'vaultspend_access_token';

class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _s = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _s;

  Future<String?> readAccessToken() => _s.read(key: _kAccessToken);

  Future<void> writeAccessToken(String token) =>
      _s.write(key: _kAccessToken, value: token);

  Future<void> deleteAccessToken() => _s.delete(key: _kAccessToken);
}
