import 'package:flutter_test/flutter_test.dart';

import 'package:eskul_mobile/features/parent/domain/entities/parent_entities.dart';

void main() {
  test('ChildProgress.fromJson memetakan snake_case + hitung hasAnySession', () {
    final json = {
      'student': {'id': 's1', 'full_name': 'Ahmad Fauzan', 'class_grade': '4A', 'photo_url': null},
      'extracurriculars': [
        {
          'id': 'e1',
          'name': 'Sepak Bola',
          'attendance_summary': {
            'total_sessions': 4,
            'hadir': 3,
            'izin': 1,
            'sakit': 0,
            'alpa': 0,
            'percentage': 75.0,
          },
          'activeness_trend': [
            {'date': '2026-08-04', 'score': 4},
            {'date': '2026-08-11', 'score': 5},
          ],
          'materials_timeline': [
            {
              'date': '2026-08-11',
              'description': 'Dribbling',
              'coach_name': 'Pak Budi',
              'coach_feedback': 'Bagus',
            },
          ],
        },
      ],
      'latest_notification': {'type': 'ATTENDANCE_DONE', 'sent_at': '2026-08-11T16:40:00+07:00'},
    };

    final p = ChildProgress.fromJson(json);
    expect(p.studentName, 'Ahmad Fauzan');
    expect(p.classGrade, '4A');
    expect(p.hasAnySession, isTrue);
    final ek = p.extracurriculars.single;
    expect(ek.summary.percentage, 75.0);
    expect(ek.summary.hadir, 3);
    expect(ek.activenessTrend.map((a) => a.score), [4, 5]);
    expect(ek.materials.single.coachName, 'Pak Budi');
    expect(p.latestNotificationAt, '2026-08-11T16:40:00+07:00');
  });

  test('hasAnySession false ketika semua ekskul 0 sesi (empty-state)', () {
    final p = ChildProgress.fromJson({
      'student': {'id': 's1', 'full_name': 'A', 'class_grade': '1A', 'photo_url': null},
      'extracurriculars': [
        {
          'id': 'e1',
          'name': 'Pramuka',
          'attendance_summary': {
            'total_sessions': 0,
            'hadir': 0,
            'izin': 0,
            'sakit': 0,
            'alpa': 0,
            'percentage': 0,
          },
          'activeness_trend': [],
          'materials_timeline': [],
        },
      ],
      'latest_notification': null,
    });
    expect(p.hasAnySession, isFalse);
    expect(p.latestNotificationAt, isNull);
  });
}
