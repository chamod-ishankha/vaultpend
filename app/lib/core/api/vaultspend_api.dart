import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class UserProfile {
  UserProfile({
    required this.id,
    required this.email,
    required this.preferredCurrency,
  });

  final String id;
  final String email;
  final String preferredCurrency;

  factory UserProfile.fromJson(Map<String, dynamic> j) {
    return UserProfile(
      id: j['id'] as String,
      email: j['email'] as String,
      preferredCurrency: j['preferred_currency'] as String? ?? 'USD',
    );
  }
}

class AuthResult {
  AuthResult({
    required this.accessToken,
    required this.user,
  });

  final String accessToken;
  final UserProfile user;

  factory AuthResult.fromJson(Map<String, dynamic> j) {
    return AuthResult(
      accessToken: j['access_token'] as String,
      user: UserProfile.fromJson(j['user'] as Map<String, dynamic>),
    );
  }
}

class VaultSpendApi {
  VaultSpendApi({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = baseUrl ?? vaultSpendApiBaseUrl,
        _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Uri _u(String path) => Uri.parse('$baseUrl$path');

  String _errorBody(http.Response res) {
    try {
      final j = jsonDecode(res.body);
      if (j is Map && j['error'] is String) return j['error'] as String;
    } catch (_) {}
    return 'Request failed (${res.statusCode})';
  }

  Future<AuthResult> register({
    required String email,
    required String password,
    String preferredCurrency = 'USD',
  }) async {
    final res = await _client.post(
      _u('/v1/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'preferred_currency': preferredCurrency,
      }),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw ApiException(_errorBody(res), statusCode: res.statusCode);
    }
    return AuthResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<AuthResult> login(String email, String password) async {
    final res = await _client.post(
      _u('/v1/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (res.statusCode != 200) {
      throw ApiException(_errorBody(res), statusCode: res.statusCode);
    }
    return AuthResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<UserProfile> me(String accessToken) async {
    final res = await _client.get(
      _u('/v1/me'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (res.statusCode != 200) {
      throw ApiException(_errorBody(res), statusCode: res.statusCode);
    }
    return UserProfile.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
