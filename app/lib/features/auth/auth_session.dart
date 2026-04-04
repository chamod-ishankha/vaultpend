class AuthUser {
  AuthUser({
    required this.id,
    required this.email,
    required this.preferredCurrency,
    this.displayName = '',
  });

  final String id;
  final String email;
  final String preferredCurrency;
  final String displayName;
}

class AuthSession {
  AuthSession({required this.user});

  final AuthUser user;
}
