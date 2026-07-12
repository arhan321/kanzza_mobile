import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorage {
  AuthStorage._();

  static final AuthStorage instance = AuthStorage._();

  static const String _tokenKey = 'kanzza_auth_token';
  static const String _userKey = 'kanzza_auth_user';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> saveSession({
    required String token,
    required Map<String, dynamic> user,
  }) async {
    await Future.wait([
      _storage.write(key: _tokenKey, value: token),
      _storage.write(key: _userKey, value: jsonEncode(user)),
    ]);
  }

  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return _storage.read(key: _tokenKey);
  }

  Future<void> saveUser(Map<String, dynamic> user) async {
    await _storage.write(key: _userKey, value: jsonEncode(user));
  }

  Future<Map<String, dynamic>?> getUser() async {
    final rawUser = await _storage.read(key: _userKey);

    if (rawUser == null || rawUser.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawUser);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      await _storage.delete(key: _userKey);
    }

    return null;
  }

  Future<String?> getRole() async {
    final user = await getUser();
    return user?['role']?.toString().trim().toLowerCase();
  }

  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.trim().isNotEmpty;
  }

  Future<void> clearSession() async {
    await Future.wait([
      _storage.delete(key: _tokenKey),
      _storage.delete(key: _userKey),
    ]);
  }
}
