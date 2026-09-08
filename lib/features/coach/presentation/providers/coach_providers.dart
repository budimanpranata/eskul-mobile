import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/network/connectivity.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../core/storage/local_database.dart';
import '../../data/datasources/coach_remote_datasource.dart';
import '../../data/local/local_session_store.dart';
import '../../data/local/roster_cache.dart';
import '../../data/repositories/coach_repository_impl.dart';
import '../../domain/entities/coach_entities.dart';
import '../../domain/repositories/coach_repository.dart';
import '../../sync/sync_engine.dart';

final localSessionStoreProvider =
    Provider<LocalSessionStore>((ref) => LocalSessionStore(ref.watch(appDatabaseProvider)));

final rosterCacheProvider =
    Provider<RosterCache>((ref) => RosterCache(ref.watch(appDatabaseProvider)));

final coachRemoteProvider =
    Provider<CoachRemoteDataSource>((ref) => CoachRemoteDataSource(ref.watch(dioProvider)));

final coachRepositoryProvider = Provider<CoachRepository>((ref) {
  return CoachRepositoryImpl(
    remote: ref.watch(coachRemoteProvider),
    store: ref.watch(localSessionStoreProvider),
    rosterCache: ref.watch(rosterCacheProvider),
    isOnline: isDeviceOnline,
  );
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final engine = SyncEngine(
    remote: ref.watch(coachRemoteProvider),
    store: ref.watch(localSessionStoreProvider),
    rosterCache: ref.watch(rosterCacheProvider),
  );
  ref.onDispose(engine.dispose);
  return engine;
});

/// Aktif selama ada sesi Pembina: jalankan sync saat online + periodik.
final syncSchedulerProvider = Provider<void>((ref) {
  final engine = ref.watch(syncEngineProvider);
  engine.startPeriodic();
  ref.listen(connectivityProvider, (_, next) {
    if (next.value == true) {
      engine.syncNow().then((_) => ref.invalidate(pendingSessionsProvider));
    }
  });
});

final coachSummaryProvider = FutureProvider.autoDispose<CoachSummary>((ref) {
  return ref.watch(coachRepositoryProvider).coachSummary();
});

final todaySessionsProvider = FutureProvider.autoDispose<TodaySessionsResult>((ref) {
  return ref.watch(coachRepositoryProvider).todaySessions();
});

final rosterProvider =
    FutureProvider.autoDispose.family<Roster, String>((ref, extracurricularId) {
  return ref.watch(coachRepositoryProvider).roster(extracurricularId);
});

/// Daftar siswa + rekap ringkas untuk sebuah ekskul (layar "Siswa" pembina).
final ekskulStudentsProvider =
    FutureProvider.autoDispose.family<EkskulRoster, String>((ref, extracurricularId) {
  return ref.watch(coachRepositoryProvider).ekskulStudents(extracurricularId);
});

typedef StudentProgressArgs = ({String extracurricularId, String studentId, String period});

/// Perkembangan 1 siswa di 1 ekskul (kehadiran + tren & catatan penilaian).
final studentProgressProvider =
    FutureProvider.autoDispose.family<StudentProgress, StudentProgressArgs>((ref, a) {
  return ref.watch(coachRepositoryProvider).studentProgress(
        a.extracurricularId,
        a.studentId,
        period: a.period,
      );
});

/// Daftar sesi lokal untuk layar Riwayat + badge pending.
final pendingSessionsProvider = FutureProvider.autoDispose<List<PendingSession>>((ref) {
  return ref.watch(localSessionStoreProvider).listAll();
});

final pendingSyncCountProvider = FutureProvider.autoDispose<int>((ref) {
  return ref.watch(localSessionStoreProvider).pendingCount();
});

/// Trigger sync manual (mis. tombol di layar Riwayat).
final manualSyncProvider = Provider((ref) {
  return () async {
    final report = await ref.read(syncEngineProvider).syncNow();
    ref.invalidate(pendingSessionsProvider);
    ref.invalidate(pendingSyncCountProvider);
    return report;
  };
});

// ---------------- Draft in-memory (dari Fase 1.3) ----------------

/// Evaluasi opsional per siswa (Fase 2.3). Semua field boleh kosong.
class StudentEval {
  const StudentEval({this.activenessScore, this.skillNotes = '', this.personalNotes = ''});
  final int? activenessScore; // 1..5
  final String skillNotes;
  final String personalNotes;

  bool get isEmpty => activenessScore == null && skillNotes.isEmpty && personalNotes.isEmpty;

  StudentEval copyWith({
    Object? activenessScore = _sentinel,
    String? skillNotes,
    String? personalNotes,
  }) =>
      StudentEval(
        activenessScore: identical(activenessScore, _sentinel)
            ? this.activenessScore
            : activenessScore as int?,
        skillNotes: skillNotes ?? this.skillNotes,
        personalNotes: personalNotes ?? this.personalNotes,
      );

  static const _sentinel = Object();
}

class AttendanceDraft {
  const AttendanceDraft({
    required this.clientGeneratedId,
    this.statuses = const {},
    this.evals = const {},
    this.materialDescription = '',
    this.durationMinutes = 90,
    this.targetAchievement = '',
  });

  final String clientGeneratedId;
  final Map<String, AttendanceStatus> statuses;
  final Map<String, StudentEval> evals;
  final String materialDescription;
  final int durationMinutes;
  final String targetAchievement;

  AttendanceDraft copyWith({
    Map<String, AttendanceStatus>? statuses,
    Map<String, StudentEval>? evals,
    String? materialDescription,
    int? durationMinutes,
    String? targetAchievement,
  }) =>
      AttendanceDraft(
        clientGeneratedId: clientGeneratedId,
        statuses: statuses ?? this.statuses,
        evals: evals ?? this.evals,
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

  /// Adopsi client_generated_id dari draft lokal yang sudah ada (agar idempoten
  /// saat pembina membuka ulang sesi setelah aplikasi ditutup).
  void adoptExistingId(String extracurricularId, String clientGeneratedId) {
    final cur = state[extracurricularId];
    if (cur != null && cur.clientGeneratedId == clientGeneratedId) return;
    state = {
      ...state,
      extracurricularId: AttendanceDraft(clientGeneratedId: clientGeneratedId),
    };
  }

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
      extracurricularId: d.copyWith(statuses: {...d.statuses, studentId: current.next}),
    };
  }

  void setStatus(String extracurricularId, String studentId, AttendanceStatus status) {
    final d = draftFor(extracurricularId);
    state = {
      ...state,
      extracurricularId: d.copyWith(statuses: {...d.statuses, studentId: status}),
    };
  }

  void setEval(
    String extracurricularId,
    String studentId, {
    Object? activenessScore = StudentEval._sentinel,
    String? skillNotes,
    String? personalNotes,
  }) {
    final d = draftFor(extracurricularId);
    final cur = d.evals[studentId] ?? const StudentEval();
    state = {
      ...state,
      extracurricularId: d.copyWith(evals: {
        ...d.evals,
        studentId: cur.copyWith(
          activenessScore: activenessScore,
          skillNotes: skillNotes,
          personalNotes: personalNotes,
        ),
      }),
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
