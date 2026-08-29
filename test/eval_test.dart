import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eskul_mobile/features/coach/presentation/providers/coach_providers.dart';

void main() {
  late ProviderContainer c;
  AttendanceDraftsNotifier n() => c.read(attendanceDraftsProvider.notifier);
  StudentEval? evalOf(String ek, String sid) =>
      c.read(attendanceDraftsProvider)[ek]?.evals[sid];

  setUp(() => c = ProviderContainer());
  tearDown(() => c.dispose());

  test('setEval menyimpan skor + catatan; partial update tidak menimpa field lain', () {
    n().setEval('ek', 's1', activenessScore: 4, skillNotes: 'Passing rapi');
    var e = evalOf('ek', 's1')!;
    expect(e.activenessScore, 4);
    expect(e.skillNotes, 'Passing rapi');
    expect(e.personalNotes, '');

    // hanya ubah personalNotes → skor & skillNotes tetap
    n().setEval('ek', 's1', personalNotes: 'Perlu perhatian');
    e = evalOf('ek', 's1')!;
    expect(e.activenessScore, 4);
    expect(e.skillNotes, 'Passing rapi');
    expect(e.personalNotes, 'Perlu perhatian');
  });

  test('setEval(activenessScore: null) menghapus skor (sentinel copyWith)', () {
    n().setEval('ek', 's1', activenessScore: 5);
    expect(evalOf('ek', 's1')!.activenessScore, 5);
    n().setEval('ek', 's1', activenessScore: null);
    expect(evalOf('ek', 's1')!.activenessScore, isNull);
  });

  test('StudentEval.isEmpty', () {
    expect(const StudentEval().isEmpty, isTrue);
    expect(const StudentEval(activenessScore: 3).isEmpty, isFalse);
    expect(const StudentEval(skillNotes: 'x').isEmpty, isFalse);
  });
}
