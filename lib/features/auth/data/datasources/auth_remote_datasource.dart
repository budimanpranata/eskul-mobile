import 'package:dio/dio.dart';

/// Panggilan HTTP mentah ke endpoint /auth/* (kontrak dokumen desain 4.3).
class AuthRemoteDataSource {
  AuthRemoteDataSource(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> login(String identifier, String password) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'identifier': identifier, 'password': password},
    );
    if (res.statusCode != 200) {
      throw AuthException(_message(res.data) ?? 'Gagal masuk.');
    }
    return res.data!;
  }

  Future<Map<String, dynamic>> registerParent(Map<String, dynamic> body) async {
    final res = await _dio.post<Map<String, dynamic>>('/auth/register', data: body);
    if (res.statusCode != 201) {
      throw AuthException(_message(res.data) ?? 'Pendaftaran gagal.');
    }
    return res.data!;
  }

  Future<void> logout() async {
    await _dio.post('/auth/logout');
  }

  Future<Map<String, dynamic>> me() async {
    final res = await _dio.get<Map<String, dynamic>>('/auth/me');
    if (res.statusCode != 200) throw AuthException('Sesi tidak valid.');
    return res.data!;
  }

  String? _message(dynamic body) {
    if (body is Map && body['message'] is String) return body['message'] as String;
    if (body is Map && body['message'] is List) return (body['message'] as List).join(', ');
    return null;
  }
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}
