import '../entities/coach_entities.dart';

/// Kontrak fitur Pembina (presensi online-only untuk Fase 1.3).
abstract interface class CoachRepository {
  /// GET /coach/today-sessions
  Future<TodaySessionsResult> todaySessions();

  /// GET /coach/extracurriculars/{id}/roster
  Future<Roster> roster(String extracurricularId);

  /// POST /attendance/submit (kontrak dokumen desain 4.1).
  /// Melempar [SubmitValidationException] pada 422, [SessionAlreadySyncedException] pada 409.
  Future<SubmitResult> submitAttendance(Map<String, dynamic> payload);
}
