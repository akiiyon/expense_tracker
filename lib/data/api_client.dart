import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:expense_tracker/core/config.dart';
import 'package:expense_tracker/data/models.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  final int? status;
  const ApiException(this.message, [this.status]);

  bool get isUnauthorized => status == 401;

  @override
  String toString() => message;
}

/// Talks to the Node backend. Holds the session token and keeps it in secure storage.
class ApiClient {
  ApiClient({http.Client? httpClient, FlutterSecureStorage? storage})
      : _http = httpClient ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  final http.Client _http;
  final FlutterSecureStorage _storage;
  static const _tokenKey = 'auth_token';
  String? _token;

  bool get hasToken => _token != null;

  Future<bool> loadToken() async {
    try {
      _token = await _storage.read(key: _tokenKey);
    } catch (_) {
      _token = null;
    }
    return _token != null;
  }

  Future<void> _saveToken(String token) async {
    _token = token;
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<void> clearToken() async {
    _token = null;
    await _storage.delete(key: _tokenKey);
  }

  Future<dynamic> _send(String method, String path, {Object? body, Duration timeout = const Duration(seconds: 20)}) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    final request = http.Request(method, uri)
      ..headers['Content-Type'] = 'application/json'
      ..headers['Accept'] = 'application/json';
    if (_token != null) request.headers['Authorization'] = 'Bearer $_token';
    if (body != null) request.body = jsonEncode(body);

    http.Response response;
    try {
      response = await http.Response.fromStream(await _http.send(request).timeout(timeout));
    } on TimeoutException {
      throw const ApiException("The server is taking too long. Check your connection and try again.");
    } on SocketException {
      throw const ApiException("Can't reach the server. Are you online?");
    } on http.ClientException {
      throw const ApiException("Can't reach the server. Are you online?");
    }

    final data = response.body.isEmpty ? null : _tryDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) return data;

    final message = data is Map && data['error'] is String ? data['error'] as String : 'Something went wrong (${response.statusCode})';
    throw ApiException(message, response.statusCode);
  }

  dynamic _tryDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  // ---------- auth ----------

  Future<AppUser> signUp(String name, String email, String password) async {
    final data = await _send('POST', '/auth/signup', body: {'username': name, 'email': email, 'password': password});
    await _saveToken(data['token'] as String);
    return AppUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<AppUser> signIn(String email, String password) async {
    final data = await _send('POST', '/auth/signin', body: {'email': email, 'password': password});
    await _saveToken(data['token'] as String);
    return AppUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<AppUser> me() async {
    final data = await _send('GET', '/auth/me');
    return AppUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<AppUser> updateProfile({String? name, double? monthlyBudget}) async {
    final data = await _send('PATCH', '/auth/me', body: {
      if (name != null) 'username': name,
      if (monthlyBudget != null) 'monthly_budget': monthlyBudget,
    });
    return AppUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<void> deleteAccount() => _send('DELETE', '/auth/me');

  // ---------- transactions ----------

  Future<({List<Txn> transactions, double balance})> transactions() async {
    final data = await _send('GET', '/transactions');
    final list = (data['transactions'] as List).map((e) => Txn.fromJson(e as Map<String, dynamic>)).toList();
    return (transactions: list, balance: (data['balance'] as num).toDouble());
  }

  Future<({Txn txn, double balance})> addTransaction(TxnDraft draft) async {
    final data = await _send('POST', '/transactions', body: draft.toJson());
    return (txn: Txn.fromJson(data['transaction'] as Map<String, dynamic>), balance: (data['balance'] as num).toDouble());
  }

  Future<({List<Txn> added, double balance})> addTransactions(List<TxnDraft> drafts) async {
    final data = await _send('POST', '/transactions/batch', body: {'transactions': drafts.map((d) => d.toJson()).toList()});
    final added = (data['added'] as List).map((e) => Txn.fromJson(e as Map<String, dynamic>)).toList();
    return (added: added, balance: (data['balance'] as num).toDouble());
  }

  Future<({Txn txn, double balance})> updateTransaction(int id, TxnDraft draft) async {
    final data = await _send('PUT', '/transactions/$id', body: draft.toJson());
    return (txn: Txn.fromJson(data['transaction'] as Map<String, dynamic>), balance: (data['balance'] as num).toDouble());
  }

  Future<double> deleteTransaction(int id) async {
    final data = await _send('DELETE', '/transactions/$id');
    return (data['balance'] as num).toDouble();
  }

  // ---------- budgets ----------

  Future<Map<String, double>> budgets() async {
    final data = await _send('GET', '/budgets');
    return (data['budgets'] as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toDouble()));
  }

  Future<void> setBudget(String category, double amount) =>
      _send('PUT', '/budgets/${Uri.encodeComponent(category)}', body: {'amount': amount});

  // ---------- xp cloud brain ----------

  Future<({String reply, bool mutated})> xpChat(String message, List<Map<String, String>> history) async {
    final now = DateTime.now();
    final data = await _send(
      'POST',
      '/xp/chat',
      body: {
        'message': message,
        'history': history,
        'now': now.toIso8601String(),
        'tz_offset': now.timeZoneOffset.inMinutes,
      },
      timeout: const Duration(seconds: 45),
    );
    return (reply: data['reply'] as String, mutated: data['mutated'] == true);
  }
}
