import 'package:vaultspend/core/api/vaultspend_api.dart';

class AuthSession {
  AuthSession({
    required this.accessToken,
    required this.user,
  });

  final String accessToken;
  final UserProfile user;
}
