import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/coach_remote_datasource.dart';
import '../../data/repositories/coach_repository_impl.dart';
import '../../domain/entities/coach_entities.dart';
import '../../domain/repositories/coach_repository.dart';

final coachRepositoryProvider = Provider<CoachRepository>((ref) {
  return CoachRepositoryImpl(CoachRemoteDataSource(ref.watch(dioProvider)));
});

/// GET /coach/today-sessions — di-refresh dengan `ref.invalidate`.
final todaySessionsProvider = FutureProvider.autoDispose<TodaySessionsResult>((ref) {
  return ref.watch(coachRepositoryProvider).todaySessions();
});

/// GET /coach/extracurriculars/:id/roster
final rosterProvider =
    FutureProvider.autoDispose.family<Roster, String>((ref, extracurricularId) {
  return ref.watch(coachRepositoryProvider).roster(extracurricularId);
});

/// Draft presensi per ekstrakurikuler (untuk hari ini).
///
/// `clientGeneratedId` dibuat SATU KALI saat draft pertama dibuka dan dipakai
/// ulang selama draft belum dikirim — penting untuk idempotency (Fase 2 offline).
/// Setelah submit sukses, panggil [clear] agar sesi berikutnya memakai id baru.
class AttendanceDraft {
  const AttendanceDraft({
    required this.clientGeneratedId,
    this.statuses = const {},
    this.materialDescription = '',
    this.durationMinutes = 90,
    this.targetAchievement = '',
  });

  final String clientGeneratedId;
  final Map<String, AttendanceStatus> statuses;
  final String materialDescription;
  final int durationMinutes;
  final String targetAchievement;

  AttendanceDraft copyWith({
    Map<String, AttendanceStatus>? statuses,
    String? materialDescription,
    int? durationMinutes,
    String? targetAchievement,
  }) =>
      AttendanceDraft(
        clientGeneratedId: clientGeneratedId,
        statuses: statuses ?? this.statuses,
        materialDescription: materialDescription ?? this.materialDescription,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        targetAchievement: targetAchievement ?? this.targetAchievement,
      );
}

class AttendanceDraftsNotifier extends Notifier<Map<String, AttendanceDraft>> {
  static const _uuid = Uuid();

  @override
  Map<String, AttendanceDraft> build() => {};

  AttendanceDraft draftFor(String extracurricularId) {
    final existing = state[extracurricularId];
    if (existing != null) return existing;
    final fresh = AttendanceDraft(clientGeneratedId: _uuid.v4());
    state = {...state, extracurricularId: fresh};
    return fresh;
  }

  /// Isi default semua siswa "Hadir" saat roster pertama kali dimuat.
  void seedRoster(String extracurricularId, List<String> studentIds) {
    final d = draftFor(extracurricularId);
    if (d.statuses.isNotEmpty) return;
    state = {
      ...state,
      extracurricularId: d.copyWith(
        statuses: {for (final id in studentIds) id: AttendanceStatus.hadir},
      ),
    };
  }

  void cycle(String extracurricularId, String studentId) {
    final d = draftFor(extracurricularId);
    final current = d.statuses[studentId] ?? AttendanceStatus.hadir;
    state = {
      ...state,
      extracurricularId: d.copyWith(
        statuses: {...d.statuses, studentId: current.next},
      ),
    };
  }

  void setStatus(String extracurricularId, String studentId, AttendanceStatus status) {
    final d = draftFor(extracurricularId);
    state = {
      ...state,
      extracurricularId: d.copyWith(statuses: {...d.statuses, studentId: status}),
    };
  }

  void setMaterial(
    String extracurricularId, {
    String? description,
    int? durationMinutes,
    String? targetAchievement,
  }) {
    final d = draftFor(extracurricularId);
    state = {
      ...state,
      extracurricularId: d.copyWith(
        materialDescription: description,
        durationMinutes: durationMinutes,
        targetAchievement: targetAchievement,
      ),
    };
  }

  void clear(String extracurricularId) {
    state = {...state}..remove(extracurricularId);
  }
}

final attendanceDraftsProvider =
    NotifierProvider<AttendanceDraftsNotifier, Map<String, AttendanceDraft>>(
  AttendanceDraftsNotifier.new,
);
