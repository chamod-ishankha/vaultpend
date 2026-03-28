import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaultspend/core/api/vaultspend_api.dart';

import 'auth_session.dart';
import 'token_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final vaultSpendApiProvider = Provider<VaultSpendApi>((ref) => VaultSpendApi());

final authControllerProvider =
    AsyncNotifierProvider<AuthNotifier, AuthSession?>(AuthNotifier.new);

/// Server-side user id (JWT `sub` / profile `id`). Local Isar data is scoped by this.
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authControllerProvider).value?.user.id;
});

class AuthNotifier extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() async {
    final storage = ref.read(tokenStorageProvider);
    final api = ref.read(vaultSpendApiProvider);
    final token = await storage.readAccessToken();
    if (token == null || token.isEmpty) return null;
    try {
      final user = await api.me(token);
      return AuthSession(accessToken: token, user: user);
    } on ApiException {
      await storage.deleteAccessToken();
      return null;
    } catch (_) {
      await storage.deleteAccessToken();
      return null;
    }
  }

  Future<void> signIn(String email, String password) async {
    state = await AsyncValue.guard(() async {
      final api = ref.read(vaultSpendApiProvider);
      final storage = ref.read(tokenStorageProvider);
      final result = await api.login(email, password);
      await storage.writeAccessToken(result.accessToken);
      return AuthSession(
        accessToken: result.accessToken,
        user: result.user,
      );
    });
  }

  Future<void> signUp({
    required String email,
    required String password,
    String preferredCurrency = 'USD',
  }) async {
    state = await AsyncValue.guard(() async {
      final api = ref.read(vaultSpendApiProvider);
      final storage = ref.read(tokenStorageProvider);
      final result = await api.register(
        email: email,
        password: password,
        preferredCurrency: preferredCurrency,
      );
      await storage.writeAccessToken(result.accessToken);
      return AuthSession(
        accessToken: result.accessToken,
        user: result.user,
      );
    });
  }

  Future<void> signOut() async {
    await ref.read(tokenStorageProvider).deleteAccessToken();
    state = const AsyncValue.data(null);
  }
}
