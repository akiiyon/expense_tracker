import 'dart:async';
import 'dart:convert';

import 'package:expense_tracker/data/api_client.dart';
import 'package:expense_tracker/data/models.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SessionStatus { unknown, signedOut, signedIn }

class SessionProvider with ChangeNotifier {
  SessionProvider(this.api);

  final ApiClient api;
  SessionStatus _status = SessionStatus.unknown;
  AppUser? _user;
  static const _cacheKey = 'cached_user';

  SessionStatus get status => _status;
  AppUser? get user => _user;

  /// Restores a saved session. Doesn't make the user wait on a slow or offline server:
  /// after a few seconds it carries on with the last known profile.
  Future<void> restore() async {
    if (!await api.loadToken()) {
      _set(SessionStatus.signedOut, null);
      return;
    }
    final cached = await _readCache();
    try {
      _set(SessionStatus.signedIn, await _cache(await api.me().timeout(const Duration(seconds: 5))));
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await signOut();
      } else {
        _set(SessionStatus.signedIn, cached ?? const AppUser(id: 0, name: '', email: ''));
      }
    } on TimeoutException {
      _set(SessionStatus.signedIn, cached ?? const AppUser(id: 0, name: '', email: ''));
      unawaited(refreshUser());
    }
  }

  Future<void> signIn(String email, String password) async {
    _set(SessionStatus.signedIn, await _cache(await api.signIn(email.trim(), password)));
  }

  Future<void> signUp(String name, String email, String password) async {
    _set(SessionStatus.signedIn, await _cache(await api.signUp(name.trim(), email.trim(), password)));
  }

  Future<void> refreshUser() async {
    try {
      _user = await _cache(await api.me());
      notifyListeners();
    } on ApiException catch (e) {
      if (e.isUnauthorized) await signOut();
    }
  }

  Future<void> updateProfile({String? name, double? monthlyBudget}) async {
    _user = await _cache(await api.updateProfile(name: name, monthlyBudget: monthlyBudget));
    notifyListeners();
  }

  Future<void> signOut() async {
    await api.clearToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    _set(SessionStatus.signedOut, null);
  }

  Future<void> deleteAccount() async {
    await api.deleteAccount();
    await signOut();
  }

  Future<AppUser> _cache(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(user.toJson()));
    return user;
  }

  Future<AppUser?> _readCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return null;
    try {
      return AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  void _set(SessionStatus status, AppUser? user) {
    _status = status;
    _user = user;
    notifyListeners();
  }
}
