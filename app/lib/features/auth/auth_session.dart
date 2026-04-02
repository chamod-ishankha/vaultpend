class AuthUser {
  AuthUser({
    required this.id,
    required this.email,
    required this.preferredCurrency,
  });

  final String id;
  final String email;
  final String preferredCurrency;
}

class AuthSession {
  AuthSession({required this.user});

  final AuthUser user;
}
