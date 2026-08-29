import '../../domain/entities/coach_entities.dart';
import '../../domain/repositories/coach_repository.dart';
import '../datasources/coach_remote_datasource.dart';

class CoachRepositoryImpl implements CoachRepository {
  CoachRepositoryImpl(this._remote);
  final CoachRemoteDataSource _remote;

  @override
  Future<TodaySessionsResult> todaySessions() async =>
      TodaySessionsResult.fromJson(await _remote.todaySessions());

  @override
  Future<Roster> roster(String extracurricularId) async =>
      Roster.fromJson(await _remote.roster(extracurricularId));

  @override
  Future<SubmitResult> submitAttendance(Map<String, dynamic> payload) async {
    final res = await _remote.submit(payload);
    final code = res.statusCode ?? 0;
    final body = res.data;

    if (code == 201) {
      return SubmitResult.fromJson(Map<String, dynamic>.from(body as Map));
    }
    if (code == 409) {
      final map = body is Map ? body : const {};
      throw SessionAlreadySyncedException(map['existing_session_id'] as String?);
    }
    if (code == 422 && body is Map && body['details'] is List) {
      final details = (body['details'] as List)
          .map((e) => (
                field: (e as Map)['field'] as String? ?? '',
                message: e['message'] as String? ?? 'Tidak valid',
              ))
          .toList();
      throw SubmitValidationException(details);
    }
    throw Exception('Gagal submit (HTTP $code).');
  }
}
