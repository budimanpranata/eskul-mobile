import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Penyimpanan aman untuk token + metadata sesi ringan (id, nama, role).
class SecureStorage {
  SecureStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _kAccessToken = 'access_token';
  static const _kRefreshToken = 'refresh_token';
  static const _kSessionMeta = 'session_meta';

  Future<void> saveTokens({required String access, required String refresh}) async {
    await _storage.write(key: _kAccessToken, value: access);
    await _storage.write(key: _kRefreshToken, value: refresh);
  }

  Future<String?> get accessToken => _storage.read(key: _kAccessToken);
  Future<String?> get refreshToken => _storage.read(key: _kRefreshToken);

  Future<void> saveMeta(Map<String, dynamic> meta) =>
      _storage.write(key: _kSessionMeta, value: jsonEncode(meta));

  Future<Map<String, dynamic>?> readMeta() async {
    final raw = await _storage.read(key: _kSessionMeta);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> clear() async {
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kRefreshToken);
    await _storage.delete(key: _kSessionMeta);
  }
}
