import '../../data/submit_outcome.dart';
import '../entities/coach_entities.dart';

/// Kontrak fitur Pembina — offline-first sejak Fase 2.1.
abstract interface class CoachRepository {
  /// GET /coach/today-sessions (online).
  Future<TodaySessionsResult> todaySessions();

  /// Roster: dari cache lokal bila belum kedaluwarsa (14 hari), selain itu fetch
  /// & cache. Bila offline tanpa cache valid → melempar error.
  Future<Roster> roster(String extracurricularId);

  /// Resolusi hasil scan QR → siswa (butuh online).
  /// Melempar [QrScanException] untuk QR_INVALID / NOT_A_MEMBER.
  Future<RosterStudent> resolveQr({
    required String qrToken,
    required String extracurricularId,
  });

  /// Simpan/segarkan draft sesi ke local DB (dipanggil terus selama pembina mengisi).
  Future<void> saveDraft({
    required String clientGeneratedId,
    required String extracurricularId,
    String? extracurricularName,
    required String sessionDate,
    required Map<String, dynamic> payload,
  });

  /// Submit sesi (berdasarkan draft lokal `clientGeneratedId`).
  /// Online → kirim; offline/koneksi putus → tandai PENDING_SYNC.
  /// 422 → melempar [SubmitValidationException].
  Future<SubmitOutcome> submit(String clientGeneratedId);
}
