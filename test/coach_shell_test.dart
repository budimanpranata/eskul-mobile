import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:eskul_mobile/core/constants/user_role.dart';
import 'package:eskul_mobile/core/network/connectivity.dart';
import 'package:eskul_mobile/core/storage/local_database.dart';
import 'package:eskul_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:eskul_mobile/features/auth/presentation/providers/auth_providers.dart';
import 'package:eskul_mobile/features/coach/data/submit_outcome.dart';
import 'package:eskul_mobile/features/coach/domain/entities/coach_entities.dart';
import 'package:eskul_mobile/features/coach/domain/repositories/coach_repository.dart';
import 'package:eskul_mobile/features/coach/presentation/pages/coach_shell.dart';
import 'package:eskul_mobile/features/coach/presentation/providers/coach_providers.dart';

class _FakeRepo implements CoachRepository {
  @override
  Future<CoachSummary> coachSummary() async => const CoachSummary(
        dayLabel: 'Senin',
        totalStudents: 12,
        totalExtracurriculars: 3,
        weeklySchedules: 5,
        todaySessionCount: 1,
        pendingSubmitToday: 1,
      );

  @override
  Future<TodaySessionsResult> todaySessions() async => const TodaySessionsResult(
        date: '2026-08-31',
        dayLabel: 'Senin',
        sessions: [
          TodaySession(
            scheduleId: 'sc-1',
            extracurricularId: 'ek-1',
            extracurricularName: 'Pramuka',
            category: 'NON_OLAHRAGA',
            startTime: '15:00',
            endTime: '16:30',
            location: 'Lapangan',
            memberCount: 12,
            submittedStatus: null,
          ),
        ],
      );

  @override
  Future<Roster> roster(String extracurricularId) => throw UnimplementedError();
  @override
  Future<RosterStudent> resolveQr({required String qrToken, required String extracurricularId}) =>
      throw UnimplementedError();
  @override
  Future<void> saveDraft({
    required String clientGeneratedId,
    required String extracurricularId,
    String? extracurricularName,
    required String sessionDate,
    required Map<String, dynamic> payload,
  }) async {}
  @override
  Future<SubmitOutcome> submit(String clientGeneratedId) => throw UnimplementedError();
}

class _FakeAuth extends AuthSessionNotifier {
  @override
  AuthSession? build() => const AuthSession(
        userId: 'u1',
        fullName: 'Pak Guru Contoh',
        role: UserRole.pembina,
        accessToken: 't',
        refreshToken: 'r',
      );
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
          syncSchedulerProvider.overrideWith((ref) {}), // matikan timer periodik
          authSessionProvider.overrideWith(_FakeAuth.new),
          authMeProvider.overrideWith((ref) async => {
                'email': 'guru@eskul.test',
                'phoneNumber': '081200000000',
              }),
        ],
        child: const MaterialApp(home: CoachShell()),
      );

  testWidgets('3 tab: Beranda / Scan QR / Profil dan isinya berpindah', (tester) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    // Tab Beranda = dashboard
    expect(find.text('Beranda Pembina'), findsOneWidget);
    expect(find.text('Total Murid'), findsOneWidget);
    expect(find.text('Beranda'), findsOneWidget); // label NavigationBar
    expect(find.text('Scan QR'), findsWidgets);
    expect(find.text('Profil'), findsWidgets);

    // Pindah ke Scan QR
    await tester.tap(find.byIcon(Icons.qr_code_scanner_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Sesi Latihan Hari Ini'), findsOneWidget);
    expect(find.text('Pramuka'), findsOneWidget);

    // Pindah ke Profil
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    expect(find.text('Pak Guru Contoh'), findsOneWidget);
    expect(find.text('guru@eskul.test'), findsOneWidget);
    expect(find.text('Keluar'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });
}
