/// Status presensi (dokumen desain: CHECK IN ('HADIR','IZIN','SAKIT','ALPA')).
enum AttendanceStatus {
  hadir('HADIR', 'Hadir'),
  izin('IZIN', 'Izin'),
  sakit('SAKIT', 'Sakit'),
  alpa('ALPA', 'Alpa');

  const AttendanceStatus(this.code, this.label);
  final String code;
  final String label;

  /// Siklus 1-tap: Hadir → Izin → Sakit → Alpa → Hadir.
  AttendanceStatus get next =>
      AttendanceStatus.values[(index + 1) % AttendanceStatus.values.length];
}

class TodaySession {
  const TodaySession({
    required this.scheduleId,
    required this.extracurricularId,
    required this.extracurricularName,
    required this.category,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.memberCount,
    required this.submittedStatus,
  });

  final String scheduleId;
  final String extracurricularId;
  final String extracurricularName;
  final String? category;
  final String startTime;
  final String endTime;
  final String? location;
  final int memberCount;

  /// null = belum disubmit hari ini; selain itu 'SUBMITTED' / 'SYNCED'.
  final String? submittedStatus;

  bool get isSubmitted => submittedStatus != null;

  factory TodaySession.fromJson(Map<String, dynamic> j) => TodaySession(
        scheduleId: j['scheduleId'] as String,
        extracurricularId: j['extracurricularId'] as String,
        extracurricularName: j['extracurricularName'] as String,
        category: j['category'] as String?,
        startTime: j['startTime'] as String,
        endTime: j['endTime'] as String,
        location: j['location'] as String?,
        memberCount: j['memberCount'] as int,
        submittedStatus:
            (j['session'] as Map<String, dynamic>?)?['status'] as String?,
      );
}

/// Angka ringkas untuk dashboard Pembina (GET /coach/summary).
class CoachSummary {
  const CoachSummary({
    required this.dayLabel,
    required this.totalStudents,
    required this.totalExtracurriculars,
    required this.weeklySchedules,
    required this.todaySessionCount,
    required this.pendingSubmitToday,
  });

  final String dayLabel;
  final int totalStudents;
  final int totalExtracurriculars;
  final int weeklySchedules;
  final int todaySessionCount;
  final int pendingSubmitToday;

  factory CoachSummary.fromJson(Map<String, dynamic> j) => CoachSummary(
        dayLabel: (j['dayLabel'] as String?) ?? '',
        totalStudents: (j['totalStudents'] as num?)?.toInt() ?? 0,
        totalExtracurriculars: (j['totalExtracurriculars'] as num?)?.toInt() ?? 0,
        weeklySchedules: (j['weeklySchedules'] as num?)?.toInt() ?? 0,
        todaySessionCount: (j['todaySessionCount'] as num?)?.toInt() ?? 0,
        pendingSubmitToday: (j['pendingSubmitToday'] as num?)?.toInt() ?? 0,
      );
}

class TodaySessionsResult {
  const TodaySessionsResult({required this.date, required this.dayLabel, required this.sessions});
  final String date;
  final String dayLabel;
  final List<TodaySession> sessions;

  factory TodaySessionsResult.fromJson(Map<String, dynamic> j) => TodaySessionsResult(
        date: j['date'] as String,
        dayLabel: j['dayLabel'] as String,
        sessions: (j['sessions'] as List)
            .map((e) => TodaySession.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class RosterStudent {
  const RosterStudent({
    required this.id,
    required this.nis,
    required this.fullName,
    required this.classGrade,
    required this.photoUrl,
  });

  final String id;
  final String nis;
  final String fullName;
  final String classGrade;
  final String? photoUrl;

  factory RosterStudent.fromJson(Map<String, dynamic> j) => RosterStudent(
        id: j['id'] as String,
        nis: j['nis'] as String,
        fullName: j['fullName'] as String,
        classGrade: j['classGrade'] as String,
        photoUrl: j['photoUrl'] as String?,
      );
}

class Roster {
  const Roster({required this.extracurricularName, required this.students});
  final String extracurricularName;
  final List<RosterStudent> students;

  factory Roster.fromJson(Map<String, dynamic> j) => Roster(
        extracurricularName:
            (j['extracurricular'] as Map<String, dynamic>)['name'] as String,
        students: (j['students'] as List)
            .map((e) => RosterStudent.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class AttendanceSummary {
  const AttendanceSummary({
    required this.total,
    required this.hadir,
    required this.izin,
    required this.sakit,
    required this.alpa,
  });
  final int total, hadir, izin, sakit, alpa;

  factory AttendanceSummary.fromJson(Map<String, dynamic> j) => AttendanceSummary(
        total: j['total_students'] as int,
        hadir: j['hadir'] as int,
        izin: j['izin'] as int,
        sakit: j['sakit'] as int,
        alpa: j['alpa'] as int,
      );
}

class SubmitResult {
  const SubmitResult({required this.sessionId, required this.summary});
  final String sessionId;
  final AttendanceSummary summary;

  factory SubmitResult.fromJson(Map<String, dynamic> j) => SubmitResult(
        sessionId: j['session_id'] as String,
        summary: AttendanceSummary.fromJson(j['summary'] as Map<String, dynamic>),
      );
}

/// Error validasi 422 dari backend: daftar { field, message }.
class SubmitValidationException implements Exception {
  SubmitValidationException(this.details);
  final List<({String field, String message})> details;
  @override
  String toString() => details.map((d) => '${d.field}: ${d.message}').join('\n');
}

/// Sesi sudah pernah tersinkron (HTTP 409).
class SessionAlreadySyncedException implements Exception {
  SessionAlreadySyncedException(this.existingSessionId);
  final String? existingSessionId;
}

/// Scan QR gagal: token tak dikenal (QR_INVALID) atau bukan anggota (NOT_A_MEMBER).
class QrScanException implements Exception {
  QrScanException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => message;
}

// ---------------- Daftar siswa + perkembangan per siswa (Fase pilot) ----------------

/// Satu siswa di roster ekskul + rekap ringkas untuk daftar.
class RosterStudentStat {
  const RosterStudentStat({
    required this.id,
    required this.nis,
    required this.fullName,
    required this.classGrade,
    required this.photoUrl,
    required this.sessions,
    required this.present,
    required this.attendancePct,
    required this.avgActiveness,
  });

  final String id;
  final String nis;
  final String fullName;
  final String classGrade;
  final String? photoUrl;
  final int sessions;
  final int present;
  final double attendancePct;
  final double? avgActiveness;

  factory RosterStudentStat.fromJson(Map<String, dynamic> j) => RosterStudentStat(
        id: j['id'] as String,
        nis: j['nis'] as String,
        fullName: j['fullName'] as String,
        classGrade: j['classGrade'] as String,
        photoUrl: j['photoUrl'] as String?,
        sessions: (j['sessions'] as num?)?.toInt() ?? 0,
        present: (j['present'] as num?)?.toInt() ?? 0,
        attendancePct: (j['attendance_pct'] as num?)?.toDouble() ?? 0,
        avgActiveness: (j['avg_activeness'] as num?)?.toDouble(),
      );
}

class EkskulRoster {
  const EkskulRoster({required this.name, required this.students});
  final String name;
  final List<RosterStudentStat> students;

  factory EkskulRoster.fromJson(Map<String, dynamic> j) => EkskulRoster(
        name: (j['extracurricular'] as Map<String, dynamic>)['name'] as String,
        students: (j['students'] as List)
            .map((e) => RosterStudentStat.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Satu titik tren keaktifan (agregat mingguan/bulanan dari backend).
class TrendPoint {
  const TrendPoint({required this.label, required this.avgScore, required this.sessions});
  final String label;
  final double avgScore;
  final int sessions;

  factory TrendPoint.fromJson(Map<String, dynamic> j) => TrendPoint(
        label: (j['label'] ?? j['bucket'] ?? '') as String,
        avgScore: (j['avg_score'] as num).toDouble(),
        sessions: (j['sessions'] as num?)?.toInt() ?? 0,
      );
}

/// Penilaian pembina untuk siswa pada satu sesi.
class StudentEvalEntry {
  const StudentEvalEntry({
    required this.date,
    required this.activenessScore,
    required this.skillNotes,
    required this.personalNotes,
    required this.coachName,
  });

  final String date;
  final int? activenessScore;
  final String? skillNotes;
  final String? personalNotes;
  final String coachName;

  bool get hasNotes =>
      (skillNotes != null && skillNotes!.isNotEmpty) ||
      (personalNotes != null && personalNotes!.isNotEmpty);

  factory StudentEvalEntry.fromJson(Map<String, dynamic> j) => StudentEvalEntry(
        date: j['date'] as String? ?? '',
        activenessScore: (j['activeness_score'] as num?)?.toInt(),
        skillNotes: j['skill_notes'] as String?,
        personalNotes: j['personal_notes'] as String?,
        coachName: j['coach_name'] as String? ?? '-',
      );
}

/// Perkembangan satu siswa di satu ekskul (untuk mode Pembina).
class StudentProgress {
  const StudentProgress({
    required this.studentName,
    required this.classGrade,
    required this.nis,
    required this.photoUrl,
    required this.ekskulName,
    required this.totalSessions,
    required this.hadir,
    required this.izin,
    required this.sakit,
    required this.alpa,
    required this.attendancePct,
    required this.averageActiveness,
    required this.trend,
    required this.evaluations,
  });

  final String studentName;
  final String classGrade;
  final String nis;
  final String? photoUrl;
  final String ekskulName;
  final int totalSessions, hadir, izin, sakit, alpa;
  final double attendancePct;
  final double? averageActiveness;
  final List<TrendPoint> trend;
  final List<StudentEvalEntry> evaluations;

  factory StudentProgress.fromJson(Map<String, dynamic> j) {
    final s = j['student'] as Map<String, dynamic>;
    final a = j['attendance_summary'] as Map<String, dynamic>;
    return StudentProgress(
      studentName: s['full_name'] as String,
      classGrade: s['class_grade'] as String,
      nis: s['nis'] as String? ?? '-',
      photoUrl: s['photo_url'] as String?,
      ekskulName: (j['extracurricular'] as Map<String, dynamic>?)?['name'] as String? ?? '',
      totalSessions: (a['total_sessions'] as num?)?.toInt() ?? 0,
      hadir: (a['hadir'] as num?)?.toInt() ?? 0,
      izin: (a['izin'] as num?)?.toInt() ?? 0,
      sakit: (a['sakit'] as num?)?.toInt() ?? 0,
      alpa: (a['alpa'] as num?)?.toInt() ?? 0,
      attendancePct: (a['percentage'] as num?)?.toDouble() ?? 0,
      averageActiveness: (j['average_activeness'] as num?)?.toDouble(),
      trend: ((j['activeness_trend'] as List?) ?? const [])
          .map((e) => TrendPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      evaluations: ((j['evaluations'] as List?) ?? const [])
          .map((e) => StudentEvalEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
