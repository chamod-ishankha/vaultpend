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

class SyncStatusSection {
  SyncStatusSection({
    required this.count,
    required this.lastUpdatedAt,
  });

  final int count;
  final DateTime? lastUpdatedAt;

  factory SyncStatusSection.fromJson(Map<String, dynamic> j) {
    final lastRaw = j['last_updated_at'];
    return SyncStatusSection(
      count: (j['count'] as num?)?.toInt() ?? 0,
      lastUpdatedAt: switch (lastRaw) {
        String v when v.isNotEmpty => DateTime.tryParse(v),
        _ => null,
      },
    );
  }
}

class SyncStatus {
  SyncStatus({
    required this.categories,
    required this.expenses,
    required this.subscriptions,
  });

  final SyncStatusSection categories;
  final SyncStatusSection expenses;
  final SyncStatusSection subscriptions;

  factory SyncStatus.fromJson(Map<String, dynamic> j) {
    return SyncStatus(
      categories: SyncStatusSection.fromJson(
        (j['categories'] as Map).cast<String, dynamic>(),
      ),
      expenses: SyncStatusSection.fromJson(
        (j['expenses'] as Map).cast<String, dynamic>(),
      ),
      subscriptions: SyncStatusSection.fromJson(
        (j['subscriptions'] as Map).cast<String, dynamic>(),
      ),
    );
  }
}

class RemoteCategory {
  RemoteCategory({
    required this.id,
    required this.name,
    this.iconKey,
    this.color,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? iconKey;
  final String? color;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory RemoteCategory.fromJson(Map<String, dynamic> j) {
    DateTime? parseDate(Object? v) => v is String ? DateTime.tryParse(v) : null;

    return RemoteCategory(
      id: j['id'] as String,
      name: j['name'] as String? ?? '',
      iconKey: j['icon_key'] as String?,
      color: j['color'] as String?,
      createdAt: parseDate(j['created_at']),
      updatedAt: parseDate(j['updated_at']),
    );
  }
}

class RemoteExpense {
  RemoteExpense({
    required this.id,
    required this.amount,
    required this.currency,
    required this.occurredAt,
    required this.isRecurring,
    this.categoryId,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? categoryId;
  final double amount;
  final String currency;
  final DateTime occurredAt;
  final String? note;
  final bool isRecurring;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory RemoteExpense.fromJson(Map<String, dynamic> j) {
    DateTime parseRequiredDate(Object? v) {
      if (v is String) {
        final parsed = DateTime.tryParse(v);
        if (parsed != null) return parsed;
      }
      throw ApiException('invalid occurred_at from server');
    }

    DateTime? parseDate(Object? v) => v is String ? DateTime.tryParse(v) : null;

    return RemoteExpense(
      id: j['id'] as String,
      categoryId: j['category_id'] as String?,
      amount: (j['amount'] as num?)?.toDouble() ?? 0,
      currency: j['currency'] as String? ?? 'USD',
      occurredAt: parseRequiredDate(j['occurred_at']),
      note: j['note'] as String?,
      isRecurring: j['is_recurring'] as bool? ?? false,
      createdAt: parseDate(j['created_at']),
      updatedAt: parseDate(j['updated_at']),
    );
  }
}

class RemoteSubscription {
  RemoteSubscription({
    required this.id,
    required this.name,
    required this.amount,
    required this.currency,
    required this.cycle,
    required this.nextBillingDate,
    required this.isTrial,
    this.trialEndsAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final double amount;
  final String currency;
  final String cycle;
  final DateTime nextBillingDate;
  final bool isTrial;
  final DateTime? trialEndsAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory RemoteSubscription.fromJson(Map<String, dynamic> j) {
    DateTime parseRequiredDate(Object? v) {
      if (v is String) {
        final parsed = DateTime.tryParse(v);
        if (parsed != null) return parsed;
      }
      throw ApiException('invalid next_billing_date from server');
    }

    DateTime? parseDate(Object? v) => v is String ? DateTime.tryParse(v) : null;

    return RemoteSubscription(
      id: j['id'] as String,
      name: j['name'] as String? ?? '',
      amount: (j['amount'] as num?)?.toDouble() ?? 0,
      currency: j['currency'] as String? ?? 'USD',
      cycle: j['cycle'] as String? ?? 'monthly',
      nextBillingDate: parseRequiredDate(j['next_billing_date']),
      isTrial: j['is_trial'] as bool? ?? false,
      trialEndsAt: parseDate(j['trial_ends_at']),
      createdAt: parseDate(j['created_at']),
      updatedAt: parseDate(j['updated_at']),
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

  Map<String, String> _authHeaders(String accessToken) => {
        'Authorization': 'Bearer $accessToken',
      };

  Map<String, String> _jsonAuthHeaders(String accessToken) => {
        ..._authHeaders(accessToken),
        'Content-Type': 'application/json',
      };

  List<Map<String, dynamic>> _readItems(http.Response res) {
    final decoded = jsonDecode(res.body);
    if (decoded is Map && decoded['items'] is List) {
      return (decoded['items'] as List)
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList(growable: false);
    }
    throw ApiException('Invalid items payload', statusCode: res.statusCode);
  }

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
      headers: _authHeaders(accessToken),
    );
    if (res.statusCode != 200) {
      throw ApiException(_errorBody(res), statusCode: res.statusCode);
    }
    return UserProfile.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<SyncStatus> syncStatus(String accessToken) async {
    final res = await _client.get(
      _u('/v1/sync/status'),
      headers: _authHeaders(accessToken),
    );
    if (res.statusCode != 200) {
      throw ApiException(_errorBody(res), statusCode: res.statusCode);
    }
    return SyncStatus.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<RemoteCategory>> listCategories(String accessToken) async {
    final res = await _client.get(
      _u('/v1/categories'),
      headers: _authHeaders(accessToken),
    );
    if (res.statusCode != 200) {
      throw ApiException(_errorBody(res), statusCode: res.statusCode);
    }
    return _readItems(res).map(RemoteCategory.fromJson).toList(growable: false);
  }

  Future<RemoteCategory> createCategory(
    String accessToken, {
    required String name,
    String? iconKey,
    String? color,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'icon_key': iconKey,
      'color': color,
    }..removeWhere((_, value) => value == null);

    final res = await _client.post(
      _u('/v1/categories'),
      headers: _jsonAuthHeaders(accessToken),
      body: jsonEncode(payload),
    );
    if (res.statusCode != 201) {
      throw ApiException(_errorBody(res), statusCode: res.statusCode);
    }
    return RemoteCategory.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<RemoteCategory> updateCategory(
    String accessToken,
    String categoryId, {
    String? name,
    String? iconKey,
    String? color,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'icon_key': iconKey,
      'color': color,
    }..removeWhere((_, value) => value == null);
    final res = await _client.patch(
      _u('/v1/categories/$categoryId'),
      headers: _jsonAuthHeaders(accessToken),
      body: jsonEncode(payload),
    );
    if (res.statusCode != 200) {
      throw ApiException(_errorBody(res), statusCode: res.statusCode);
    }
    return RemoteCategory.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> deleteCategory(String accessToken, String categoryId) async {
    final res = await _client.delete(
      _u('/v1/categories/$categoryId'),
      headers: _authHeaders(accessToken),
    );
    if (res.statusCode != 204) {
      throw ApiException(_errorBody(res), statusCode: res.statusCode);
    }
  }

  Future<List<RemoteExpense>> listExpenses(String accessToken) async {
    final res = await _client.get(
      _u('/v1/expenses'),
      headers: _authHeaders(accessToken),
    );
    if (res.statusCode != 200) {
      throw ApiException(_errorBody(res), statusCode: res.statusCode);
    }
    return _readItems(res).map(RemoteExpense.fromJson).toList(growable: false);
  }

  Future<RemoteExpense> createExpense(
    String accessToken, {
    String? categoryId,
    required double amount,
    required String currency,
    required DateTime occurredAt,
    String? note,
    bool isRecurring = false,
  }) async {
    final payload = <String, dynamic>{
      'category_id': categoryId,
      'amount': amount,
      'currency': currency,
      'occurred_at': occurredAt.toUtc().toIso8601String(),
      'note': note,
      'is_recurring': isRecurring,
    }..removeWhere((_, value) => value == null);

    final res = await _client.post(
      _u('/v1/expenses'),
      headers: _jsonAuthHeaders(accessToken),
      body: jsonEncode(payload),
    );
    if (res.statusCode != 201) {
      throw ApiException(_errorBody(res), statusCode: res.statusCode);
    }
    return RemoteExpense.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<RemoteExpense> updateExpense(
    String accessToken,
    String expenseId, {
    String? categoryId,
    double? amount,
    String? currency,
    DateTime? occurredAt,
    String? note,
    bool? isRecurring,
  }) async {
    final payload = <String, dynamic>{
      'category_id': categoryId,
      'amount': amount,
      'currency': currency,
      'occurred_at': occurredAt?.toUtc().toIso8601String(),
      'note': note,
      'is_recurring': isRecurring,
    }..removeWhere((_, value) => value == null);
    final res = await _client.patch(
      _u('/v1/expenses/$expenseId'),
      headers: _jsonAuthHeaders(accessToken),
      body: jsonEncode(payload),
    );
    if (res.statusCode != 200) {
      throw ApiException(_errorBody(res), statusCode: res.statusCode);
    }
    return RemoteExpense.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> deleteExpense(String accessToken, String expenseId) async {
    final res = await _client.delete(
      _u('/v1/expenses/$expenseId'),
      headers: _authHeaders(accessToken),
    );
    if (res.statusCode != 204) {
      throw ApiException(_errorBody(res), statusCode: res.statusCode);
    }
  }

  Future<List<RemoteSubscription>> listSubscriptions(String accessToken) async {
    final res = await _client.get(
      _u('/v1/subscriptions'),
      headers: _authHeaders(accessToken),
    );
    if (res.statusCode != 200) {
      throw ApiException(_errorBody(res), statusCode: res.statusCode);
    }
    return _readItems(res)
        .map(RemoteSubscription.fromJson)
        .toList(growable: false);
  }

  Future<RemoteSubscription> createSubscription(
    String accessToken, {
    required String name,
    required double amount,
    required String currency,
    required String cycle,
    required DateTime nextBillingDate,
    bool isTrial = false,
    DateTime? trialEndsAt,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'amount': amount,
      'currency': currency,
      'cycle': cycle,
      'next_billing_date': nextBillingDate.toUtc().toIso8601String(),
      'is_trial': isTrial,
      'trial_ends_at': trialEndsAt?.toUtc().toIso8601String(),
    }..removeWhere((_, value) => value == null);

    final res = await _client.post(
      _u('/v1/subscriptions'),
      headers: _jsonAuthHeaders(accessToken),
      body: jsonEncode(payload),
    );
    if (res.statusCode != 201) {
      throw ApiException(_errorBody(res), statusCode: res.statusCode);
    }
    return RemoteSubscription.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  Future<RemoteSubscription> updateSubscription(
    String accessToken,
    String subscriptionId, {
    String? name,
    double? amount,
    String? currency,
    String? cycle,
    DateTime? nextBillingDate,
    bool? isTrial,
    DateTime? trialEndsAt,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'amount': amount,
      'currency': currency,
      'cycle': cycle,
      'next_billing_date': nextBillingDate?.toUtc().toIso8601String(),
      'is_trial': isTrial,
      'trial_ends_at': trialEndsAt?.toUtc().toIso8601String(),
    }..removeWhere((_, value) => value == null);
    final res = await _client.patch(
      _u('/v1/subscriptions/$subscriptionId'),
      headers: _jsonAuthHeaders(accessToken),
      body: jsonEncode(payload),
    );
    if (res.statusCode != 200) {
      throw ApiException(_errorBody(res), statusCode: res.statusCode);
    }
    return RemoteSubscription.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  Future<void> deleteSubscription(String accessToken, String subscriptionId) async {
    final res = await _client.delete(
      _u('/v1/subscriptions/$subscriptionId'),
      headers: _authHeaders(accessToken),
    );
    if (res.statusCode != 204) {
      throw ApiException(_errorBody(res), statusCode: res.statusCode);
    }
  }
}
