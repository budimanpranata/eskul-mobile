class Child {
  const Child({
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

  factory Child.fromJson(Map<String, dynamic> j) => Child(
        id: j['id'] as String,
        nis: j['nis'] as String,
        fullName: j['fullName'] as String,
        classGrade: j['classGrade'] as String,
        photoUrl: j['photoUrl'] as String?,
      );
}

class AttendanceSummary {
  const AttendanceSummary({
    required this.totalSessions,
    required this.hadir,
    required this.izin,
    required this.sakit,
    required this.alpa,
    required this.percentage,
  });

  final int totalSessions, hadir, izin, sakit, alpa;
  final double percentage;

  factory AttendanceSummary.fromJson(Map<String, dynamic> j) => AttendanceSummary(
        totalSessions: j['total_sessions'] as int,
        hadir: j['hadir'] as int,
        izin: j['izin'] as int,
        sakit: j['sakit'] as int,
        alpa: j['alpa'] as int,
        percentage: (j['percentage'] as num).toDouble(),
      );
}

/// Satu titik tren keaktifan, sudah diagregasi backend per minggu / bulan (Fase 3.2).
class ActivenessPoint {
  const ActivenessPoint({
    required this.label,
    required this.avgScore,
    required this.sessions,
  });

  final String label;
  final double avgScore;
  final int sessions;

  factory ActivenessPoint.fromJson(Map<String, dynamic> j) => ActivenessPoint(
        label: (j['label'] ?? j['bucket'] ?? '') as String,
        avgScore: (j['avg_score'] as num).toDouble(),
        sessions: (j['sessions'] as num?)?.toInt() ?? 0,
      );
}

class MaterialEntry {
  const MaterialEntry({
    required this.date,
    required this.description,
    required this.coachName,
    required this.coachFeedback,
  });

  final String date;
  final String description;
  final String coachName;
  final String? coachFeedback;

  factory MaterialEntry.fromJson(Map<String, dynamic> j) => MaterialEntry(
        date: j['date'] as String,
        description: j['description'] as String? ?? '',
        coachName: j['coach_name'] as String? ?? '-',
        coachFeedback: j['coach_feedback'] as String?,
      );
}

/// Satu penilaian pembina untuk anak pada satu sesi (skor keaktifan + catatan).
class EvalEntry {
  const EvalEntry({
    required this.date,
    required this.activenessScore,
    required this.skillNotes,
    required this.personalNotes,
    required this.coachName,
  });

  final String date;
  final int? activenessScore; // 1..5
  final String? skillNotes;
  final String? personalNotes;
  final String coachName;

  bool get hasNotes =>
      (skillNotes != null && skillNotes!.isNotEmpty) ||
      (personalNotes != null && personalNotes!.isNotEmpty);

  factory EvalEntry.fromJson(Map<String, dynamic> j) => EvalEntry(
        date: j['date'] as String? ?? '',
        activenessScore: (j['activeness_score'] as num?)?.toInt(),
        skillNotes: j['skill_notes'] as String?,
        personalNotes: j['personal_notes'] as String?,
        coachName: j['coach_name'] as String? ?? '-',
      );
}

class EkskulProgress {
  const EkskulProgress({
    required this.id,
    required this.name,
    required this.summary,
    required this.averageActiveness,
    required this.activenessTrend,
    required this.evaluations,
    required this.materials,
  });

  final String id;
  final String name;
  final AttendanceSummary summary;
  final double? averageActiveness;
  final List<ActivenessPoint> activenessTrend;
  final List<EvalEntry> evaluations;
  final List<MaterialEntry> materials;

  factory EkskulProgress.fromJson(Map<String, dynamic> j) => EkskulProgress(
        id: j['id'] as String,
        name: j['name'] as String,
        summary: AttendanceSummary.fromJson(j['attendance_summary'] as Map<String, dynamic>),
        averageActiveness: (j['average_activeness'] as num?)?.toDouble(),
        activenessTrend: (j['activeness_trend'] as List)
            .map((e) => ActivenessPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        evaluations: ((j['evaluations'] as List?) ?? const [])
            .map((e) => EvalEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        materials: (j['materials_timeline'] as List)
            .map((e) => MaterialEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class ChildProgress {
  const ChildProgress({
    required this.studentName,
    required this.classGrade,
    required this.photoUrl,
    required this.extracurriculars,
    required this.latestNotificationAt,
  });

  final String studentName;
  final String classGrade;
  final String? photoUrl;
  final List<EkskulProgress> extracurriculars;
  final String? latestNotificationAt;

  bool get hasAnySession => extracurriculars.any((e) => e.summary.totalSessions > 0);

  factory ChildProgress.fromJson(Map<String, dynamic> j) {
    final student = j['student'] as Map<String, dynamic>;
    final notif = j['latest_notification'] as Map<String, dynamic>?;
    return ChildProgress(
      studentName: student['full_name'] as String,
      classGrade: student['class_grade'] as String,
      photoUrl: student['photo_url'] as String?,
      extracurriculars: (j['extracurriculars'] as List)
          .map((e) => EkskulProgress.fromJson(e as Map<String, dynamic>))
          .toList(),
      latestNotificationAt: notif?['sent_at'] as String?,
    );
  }
}

/// Relasi belum di-approve admin (HTTP 403 { error: 'UNAUTHORIZED_RELATION' }).
class UnauthorizedRelationException implements Exception {
  const UnauthorizedRelationException();
}
