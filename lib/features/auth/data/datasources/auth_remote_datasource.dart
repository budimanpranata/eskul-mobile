import 'package:dio/dio.dart';

/// Sumber data remote untuk autentikasi (memanggil endpoint /auth/*).
///
/// FASE 0: kerangka. Body request/response dipetakan di Fase 1.1 sesuai
/// kontrak API dokumen desain bagian 4.3.
class AuthRemoteDataSource {
  AuthRemoteDataSource(this._dio);

  // ignore: unused_field
  final Dio _dio;

  Future<Map<String, dynamic>> login(String identifier, String password) {
    throw UnimplementedError('Diimplementasikan di Fase 1.1');
  }

  Future<Map<String, dynamic>> refresh(String refreshToken) {
    throw UnimplementedError('Diimplementasikan di Fase 1.1');
  }
}
