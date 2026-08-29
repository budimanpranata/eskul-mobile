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
