class AuthUser {
  AuthUser({
    required this.id,
    required this.email,
    required this.preferredCurrency,
    this.displayName = '',
    this.photoBase64,
  });

  final String id;
  final String email;
  final String preferredCurrency;
  final String displayName;
  final String? photoBase64;
}

class AuthSession {
  AuthSession({required this.user});

  final AuthUser user;
}
