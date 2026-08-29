import 'package:dio/dio.dart';

class CoachRemoteDataSource {
  CoachRemoteDataSource(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> todaySessions() async {
    final r = await _dio.get<Map<String, dynamic>>('/coach/today-sessions');
    _ensureOk(r);
    return r.data!;
  }

  Future<Map<String, dynamic>> roster(String extracurricularId) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/coach/extracurriculars/$extracurricularId/roster',
    );
    _ensureOk(r);
    return r.data!;
  }

  Future<Response<dynamic>> qrScan(String qrToken, String extracurricularId) {
    return _dio.post<dynamic>(
      '/coach/students/qr-scan',
      data: {'qr_token': qrToken, 'extracurricular_id': extracurricularId},
    );
  }

  /// Mengembalikan Response mentah agar repository memetakan 201/409/422.
  Future<Response<dynamic>> submit(Map<String, dynamic> payload) {
    return _dio.post<dynamic>(
      '/attendance/submit',
      data: payload,
      options: Options(
        headers: {'Idempotency-Key': payload['client_generated_id']},
      ),
    );
  }

  void _ensureOk(Response<dynamic> r) {
    final code = r.statusCode ?? 0;
    if (code < 200 || code >= 300) {
      throw DioException(
        requestOptions: r.requestOptions,
        response: r,
        message: 'HTTP $code',
      );
    }
  }
}
