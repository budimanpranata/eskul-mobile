import 'package:flutter_test/flutter_test.dart';

import 'package:eskul_mobile/features/coach/domain/entities/coach_entities.dart';

void main() {
  test('EkskulRoster.fromJson: roster + rekap per siswa', () {
    final r = EkskulRoster.fromJson({
      'extracurricular': {'id': 'e1', 'name': 'Futsal'},
      'students': [
        {
          'id': 's1',
          'nis': 'N1',
          'fullName': 'Andi',
          'classGrade': '4A',
          'photoUrl': null,
          'sessions': 3,
          'present': 2,
          'attendance_pct': 66.7,
          'avg_activeness': 3.5,
        },
        {
          'id': 's2',
          'nis': 'N2',
          'fullName': 'Bunga',
          'classGrade': '4A',
          'photoUrl': null,
          'sessions': 0,
          'present': 0,
          'attendance_pct': 0,
          'avg_activeness': null,
        },
      ],
    });

    expect(r.name, 'Futsal');
    expect(r.students, hasLength(2));
    expect(r.students.first.fullName, 'Andi');
    expect(r.students.first.sessions, 3);
    expect(r.students.first.attendancePct, 66.7);
    expect(r.students.first.avgActiveness, 3.5);
    expect(r.students[1].avgActiveness, isNull);
  });

  test('StudentProgress.fromJson: summary + tren + evaluasi (snake_case)', () {
    final p = StudentProgress.fromJson({
      'student': {
        'id': 's1',
        'nis': 'N1',
        'full_name': 'Andi Saputra',
        'class_grade': '4A',
        'photo_url': null,
      },
      'extracurricular': {'id': 'e1', 'name': 'Futsal'},
      'period': 'weekly',
      'attendance_summary': {
        'total_sessions': 4,
        'hadir': 3,
        'izin': 1,
        'sakit': 0,
        'alpa': 0,
        'percentage': 75.0,
      },
      'average_activeness': 4.0,
      'activeness_trend': [
        {'bucket': '2026-08-03', 'label': '3 Agu', 'avg_score': 3.0, 'sessions': 1},
        {'bucket': '2026-08-10', 'label': '10 Agu', 'avg_score': 5.0, 'sessions': 1},
      ],
      'evaluations': [
        {
          'date': '2026-08-10',
          'activeness_score': 5,
          'skill_notes': 'Passing tajam',
          'personal_notes': null,
          'coach_name': 'Bu Sri',
        },
        {
          'date': '2026-08-03',
          'activeness_score': 3,
          'skill_notes': null,
          'personal_notes': null,
          'coach_name': 'Bu Sri',
        },
      ],
    });

    expect(p.studentName, 'Andi Saputra');
    expect(p.classGrade, '4A');
    expect(p.nis, 'N1');
    expect(p.ekskulName, 'Futsal');
    expect(p.totalSessions, 4);
    expect(p.hadir, 3);
    expect(p.attendancePct, 75.0);
    expect(p.averageActiveness, 4.0);
    expect(p.trend.map((t) => t.avgScore), [3.0, 5.0]);
    expect(p.trend.map((t) => t.label), ['3 Agu', '10 Agu']);
    expect(p.evaluations, hasLength(2));
    expect(p.evaluations.first.activenessScore, 5);
    expect(p.evaluations.first.skillNotes, 'Passing tajam');
    expect(p.evaluations.first.hasNotes, isTrue);
    expect(p.evaluations[1].hasNotes, isFalse);
  });

  test('StudentProgress.fromJson: tahan field opsional hilang', () {
    final p = StudentProgress.fromJson({
      'student': {'full_name': 'X', 'class_grade': '1A'},
      'attendance_summary': {'total_sessions': 0},
    });
    expect(p.averageActiveness, isNull);
    expect(p.trend, isEmpty);
    expect(p.evaluations, isEmpty);
    expect(p.nis, '-');
  });
}
