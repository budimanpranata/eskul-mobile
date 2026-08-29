import 'package:dio/dio.dart';

import '../domain/entities/parent_entities.dart';

abstract interface class ParentRepository {
  Future<List<Child>> children();
  Future<void> linkRequest({required String nis, required String studentName});
  Future<ChildProgress> childProgress(String studentId, {String period = 'weekly'});
}

class ParentRepositoryImpl implements ParentRepository {
  ParentRepositoryImpl(this._dio);
  final Dio _dio;

  @override
  Future<List<Child>> children() async {
    final r = await _dio.get<List<dynamic>>('/parent/children');
    return (r.data ?? [])
        .map((e) => Child.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  @override
  Future<void> linkRequest({required String nis, required String studentName}) async {
    final r = await _dio.post<dynamic>(
      '/parent/link-request',
      data: {'nis': nis, 'studentName': studentName},
    );
    final code = r.statusCode ?? 0;
    if (code == 201) return;
    throw _messageException(r);
  }

  @override
  Future<ChildProgress> childProgress(String studentId, {String period = 'weekly'}) async {
    final r = await _dio.get<dynamic>(
      '/parent/child-progress/$studentId',
      queryParameters: {'period': period},
    );
    final code = r.statusCode ?? 0;
    if (code == 200) {
      return ChildProgress.fromJson(Map<String, dynamic>.from(r.data as Map));
    }
    if (code == 403 && r.data is Map && (r.data as Map)['error'] == 'UNAUTHORIZED_RELATION') {
      throw const UnauthorizedRelationException();
    }
    throw _messageException(r);
  }

  Exception _messageException(Response<dynamic> r) {
    final data = r.data;
    if (data is Map) {
      if (data['error'] == 'VALIDATION_ERROR' && data['details'] is List) {
        return Exception((data['details'] as List)
            .map((d) => (d as Map)['message'])
            .join(', '));
      }
      if (data['message'] is String) return Exception(data['message'] as String);
    }
    return Exception('Permintaan gagal (HTTP ${r.statusCode}).');
  }
}
