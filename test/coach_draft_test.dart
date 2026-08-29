import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eskul_mobile/features/coach/domain/entities/coach_entities.dart';
import 'package:eskul_mobile/features/coach/presentation/providers/coach_providers.dart';

void main() {
  group('AttendanceStatus.next (siklus 1-tap)', () {
    test('Hadir -> Izin -> Sakit -> Alpa -> Hadir', () {
      expect(AttendanceStatus.hadir.next, AttendanceStatus.izin);
      expect(AttendanceStatus.izin.next, AttendanceStatus.sakit);
      expect(AttendanceStatus.sakit.next, AttendanceStatus.alpa);
      expect(AttendanceStatus.alpa.next, AttendanceStatus.hadir);
    });
  });

  group('AttendanceDraftsNotifier', () {
    late ProviderContainer c;
    AttendanceDraftsNotifier n() => c.read(attendanceDraftsProvider.notifier);

    setUp(() => c = ProviderContainer());
    tearDown(() => c.dispose());

    test('client_generated_id sama saat draft dibuka ulang (idempotency)', () {
      final id1 = n().draftFor('ek-1').clientGeneratedId;
      final id2 = n().draftFor('ek-1').clientGeneratedId;
      expect(id1, id2);
      expect(id1, isNotEmpty);
      // ekskul berbeda -> id berbeda
      expect(n().draftFor('ek-2').clientGeneratedId, isNot(id1));
    });

    test('seedRoster mengisi semua Hadir, tidak menimpa perubahan', () {
      n().seedRoster('ek-1', ['a', 'b', 'c']);
      var d = c.read(attendanceDraftsProvider)['ek-1']!;
      expect(d.statuses.values.every((s) => s == AttendanceStatus.hadir), isTrue);

      n().cycle('ek-1', 'b'); // b -> Izin
      n().seedRoster('ek-1', ['a', 'b', 'c']); // tidak boleh reset
      d = c.read(attendanceDraftsProvider)['ek-1']!;
      expect(d.statuses['b'], AttendanceStatus.izin);
      expect(d.statuses['a'], AttendanceStatus.hadir);
    });

    test('clear -> draft berikutnya memakai client_generated_id BARU', () {
      final first = n().draftFor('ek-1').clientGeneratedId;
      n().clear('ek-1');
      final second = n().draftFor('ek-1').clientGeneratedId;
      expect(second, isNot(first));
    });

    test('setMaterial menyimpan deskripsi & durasi', () {
      n().setMaterial('ek-1', description: 'Dribbling', durationMinutes: 75);
      final d = c.read(attendanceDraftsProvider)['ek-1']!;
      expect(d.materialDescription, 'Dribbling');
      expect(d.durationMinutes, 75);
    });
  });
}
