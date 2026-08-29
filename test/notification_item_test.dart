import 'package:flutter_test/flutter_test.dart';

import 'package:eskul_mobile/features/notifications/notifications.dart';

void main() {
  test('NotificationItem.fromJson (camelCase Prisma default)', () {
    final n = NotificationItem.fromJson({
      'id': 'n1',
      'type': 'ATTENDANCE_DONE',
      'title': 'Presensi Sepak Bola selesai',
      'body': 'Kehadiran sudah dicatat.',
      'isRead': false,
      'sentAt': '2026-08-29T09:40:00.000Z',
    });
    expect(n.type, 'ATTENDANCE_DONE');
    expect(n.isRead, isFalse);
    expect(n.title, contains('Sepak Bola'));
  });

  test('fromJson toleran snake_case (is_read / sent_at)', () {
    final n = NotificationItem.fromJson({
      'id': 'n2',
      'type': 'WEEKLY_REPORT',
      'title': 'Laporan mingguan',
      'body': null,
      'is_read': true,
      'sent_at': '2026-08-30T18:00:00.000Z',
    });
    expect(n.isRead, isTrue);
    expect(n.body, isNull);
    expect(n.sentAt, '2026-08-30T18:00:00.000Z');
  });
}
