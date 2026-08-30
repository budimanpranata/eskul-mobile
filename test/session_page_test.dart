import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:eskul_mobile/core/storage/local_database.dart';
import 'package:eskul_mobile/core/network/connectivity.dart';
import 'package:eskul_mobile/features/coach/data/submit_outcome.dart';
import 'package:eskul_mobile/features/coach/domain/entities/coach_entities.dart';
import 'package:eskul_mobile/features/coach/domain/repositories/coach_repository.dart';
import 'package:eskul_mobile/features/coach/presentation/pages/session_page.dart';
import 'package:eskul_mobile/features/coach/presentation/providers/coach_providers.dart';

class _FakeRepo implements CoachRepository {
  int saveDraftCalls = 0;

  @override
  Future<Roster> roster(String extracurricularId) async => const Roster(
        extracurricularName: 'Karate',
        students: [
          RosterStudent(id: 's1', nis: 'N1', fullName: 'Andi Contoh', classGrade: '4A', photoUrl: null),
          RosterStudent(id: 's2', nis: 'N2', fullName: 'Bunga Contoh', classGrade: '4A', photoUrl: null),
        ],
      );

  @override
  Future<void> saveDraft({
    required String clientGeneratedId,
    required String extracurricularId,
    String? extracurricularName,
    required String sessionDate,
    required Map<String, dynamic> payload,
  }) async {
    saveDraftCalls++;
  }

  @override
  Future<TodaySessionsResult> todaySessions() async =>
      const TodaySessionsResult(date: '2026-08-30', dayLabel: 'Minggu', sessions: []);

  @override
  Future<RosterStudent> resolveQr({required String qrToken, required String extracurricularId}) =>
      throw UnimplementedError();

  @override
  Future<SubmitOutcome> submit(String clientGeneratedId) => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late final dynamic db;
  setUpAll(() async {
    db = await openAppDatabase(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
  });

  Widget harness() => ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          coachRepositoryProvider.overrideWithValue(_FakeRepo()),
          connectivityProvider.overrideWith((ref) => Stream.value(true)),
        ],
        child: const MaterialApp(
          home: SessionPage(extracurricularId: 'ek-1', session: null),
        ),
      );

  testWidgets('SessionPage tampil tanpa error provider (regresi layar merah)', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Andi Contoh'), findsOneWidget);
    expect(find.text('Bunga Contoh'), findsOneWidget);
    // Afordansi eksplisit "Nilai" per siswa (bukan hanya long-press).
    expect(find.text('Nilai'), findsNWidgets(2));
    expect(find.text('Presensi Cepat'), findsOneWidget);
  });

  testWidgets('ketuk baris mengganti status; tombol Nilai membuka lembar evaluasi', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    // status awal Hadir; ketuk baris → Izin
    await tester.tap(find.text('Andi Contoh'));
    await tester.pumpAndSettle();
    expect(find.text('Izin'), findsWidgets);

    await tester.tap(find.text('Nilai').first);
    await tester.pumpAndSettle();
    expect(find.text('Nilai keaktifan (1–5)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
