import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:eskul_mobile/core/storage/local_database.dart';
import 'package:eskul_mobile/features/coach/data/datasources/coach_remote_datasource.dart';
import 'package:eskul_mobile/features/coach/data/local/local_session_store.dart';
import 'package:eskul_mobile/features/coach/data/local/roster_cache.dart';
import 'package:eskul_mobile/features/coach/data/repositories/coach_repository_impl.dart';
import 'package:eskul_mobile/features/coach/data/submit_outcome.dart';
import 'package:eskul_mobile/features/coach/domain/entities/coach_entities.dart';
import 'package:eskul_mobile/features/coach/sync/sync_engine.dart';

/// Remote palsu: skenario response di-set per test.
class FakeRemote implements CoachRemoteDataSource {
  List<Object> scenario = []; // tiap elemen: int status | 'throw'
  int calls = 0;

  Response<dynamic> _res(int status) {
    final data = switch (status) {
      201 => {
          'session_id': 'srv-$calls',
          'status': 'SUBMITTED',
          'synced_at': '2026-08-29T10:00:00Z',
          'summary': {'total_students': 1, 'hadir': 1, 'izin': 0, 'sakit': 0, 'alpa': 0},
        },
      409 => {'error': 'SESSION_ALREADY_SYNCED', 'existing_session_id': 'srv-existing'},
      422 => {
          'error': 'VALIDATION_ERROR',
          'details': [
            {'field': 'attendances[0].status', 'message': 'Status tidak valid'},
          ],
        },
      _ => {'message': 'err'},
    };
    return Response<dynamic>(
      requestOptions: RequestOptions(path: '/attendance/submit'),
      statusCode: status,
      data: data,
    );
  }

  @override
  Future<Response<dynamic>> submit(Map<String, dynamic> payload) async {
    final step = calls < scenario.length ? scenario[calls] : scenario.last;
    calls++;
    if (step == 'throw') {
      throw DioException(requestOptions: RequestOptions(path: '/attendance/submit'), message: 'net');
    }
    return _res(step as int);
  }

  @override
  Future<Response<dynamic>> qrScan(String qrToken, String extracurricularId) async {
    return Response<dynamic>(
      requestOptions: RequestOptions(path: '/coach/students/qr-scan'),
      statusCode: 200,
      data: {
        'student': {'id': 's1', 'nis': 'N1', 'fullName': 'Ahmad', 'classGrade': '4A', 'photoUrl': null},
      },
    );
  }

  @override
  Future<Map<String, dynamic>> roster(String id) async => {
        'extracurricular': {'name': 'Sepak Bola'},
        'students': [
          {'id': 's1', 'nis': 'N1', 'fullName': 'Ahmad', 'classGrade': '4A', 'photoUrl': null},
        ],
      };

  @override
  Future<Map<String, dynamic>> todaySessions() async => {'date': '', 'dayLabel': '', 'sessions': []};
}

Map<String, dynamic> _payload(String cgid) => {
      'client_generated_id': cgid,
      'extracurricular_id': 'ek-1',
      'session_date': '2026-08-29',
      'attendances': [
        {'student_id': 's1', 'status': 'HADIR'},
      ],
    };

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late LocalSessionStore store;
  late RosterCache cache;
  late FakeRemote remote;

  setUp(() async {
    db = await openAppDatabase(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    store = LocalSessionStore(db);
    cache = RosterCache(db);
    remote = FakeRemote();
  });

  tearDown(() => db.close());

  CoachRepositoryImpl repo({required bool online}) => CoachRepositoryImpl(
        remote: remote,
        store: store,
        rosterCache: cache,
        isOnline: () async => online,
      );

  Future<void> seedDraft(String cgid) => store.upsertDraft(
        clientGeneratedId: cgid,
        extracurricularId: 'ek-1',
        sessionDate: '2026-08-29',
        payload: _payload(cgid),
      );

  test('submit offline lalu online kembali', () async {
    await seedDraft('cg-1');
    final out = await repo(online: false).submit('cg-1');
    expect(out, isA<SubmitQueuedOffline>());
    expect(remote.calls, 0, reason: 'offline → tidak boleh memanggil server');
    expect((await store.findById('cg-1'))!.status, SyncStatus.pendingSync);

    remote.scenario = [201];
    final engine = SyncEngine(
      remote: remote,
      store: store,
      rosterCache: cache,
      backoff: (_) => Duration.zero,
    );
    final report = await engine.syncNow();
    expect(report.synced, 1);
    final row = await store.findById('cg-1');
    expect(row!.status, SyncStatus.synced);
    expect(row.serverSessionId, isNotNull);
  });

  test('submit gagal di tengah jalan (koneksi putus saat request) → PENDING_SYNC', () async {
    await seedDraft('cg-2');
    remote.scenario = ['throw'];
    final out = await repo(online: true).submit('cg-2');
    expect(out, isA<SubmitQueuedOffline>());
    expect((await store.findById('cg-2'))!.status, SyncStatus.pendingSync);
  });

  test('retry sesi yang sebelumnya gagal sync (gagal 1 siklus, sukses siklus berikutnya)', () async {
    await seedDraft('cg-3');
    await store.setStatus('cg-3', SyncStatus.pendingSync);

    // Siklus 1: 3x gagal (throw) → tetap PENDING_SYNC, attempt_count naik.
    remote.scenario = ['throw', 'throw', 'throw'];
    final engine = SyncEngine(
      remote: remote,
      store: store,
      rosterCache: cache,
      backoff: (_) => Duration.zero,
    );
    var report = await engine.syncNow();
    expect(report.synced, 0);
    expect(report.stillPending, 1);
    final mid = await store.findById('cg-3');
    expect(mid!.status, SyncStatus.pendingSync);
    expect(mid.attemptCount, greaterThanOrEqualTo(3));

    // Siklus 2: sukses.
    remote.calls = 0;
    remote.scenario = [201];
    report = await engine.syncNow();
    expect(report.synced, 1);
    expect((await store.findById('cg-3'))!.status, SyncStatus.synced);
  });

  test('response 409 → ditandai SYNCED tanpa error ke user', () async {
    await seedDraft('cg-4');
    remote.scenario = [409];
    final out = await repo(online: true).submit('cg-4');
    expect(out, isA<SubmitAlreadySynced>());
    final row = await store.findById('cg-4');
    expect(row!.status, SyncStatus.synced);
    expect(row.serverSessionId, 'srv-existing');
  });

  test('response 422 → tetap DRAFT + melempar SubmitValidationException', () async {
    await seedDraft('cg-5');
    remote.scenario = [422];
    await expectLater(
      repo(online: true).submit('cg-5'),
      throwsA(isA<SubmitValidationException>()),
    );
    expect((await store.findById('cg-5'))!.status, SyncStatus.draft);
  });

  test('idempotency: draft dibuka ulang memakai client_generated_id yang sama', () async {
    await seedDraft('cg-6');
    final again = await store.findByEkskulDate('ek-1', '2026-08-29');
    expect(again!.clientGeneratedId, 'cg-6');
  });

  test('roster cache: valid dalam TTL, terhapus otomatis setelah kedaluwarsa (14 hari)', () async {
    final shortCache = RosterCache(db, ttl: const Duration(milliseconds: 20));
    await shortCache.put('ek-1', {'extracurricular': {'name': 'X'}, 'students': []});
    expect(await shortCache.get('ek-1'), isNotNull); // masih valid

    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(await shortCache.get('ek-1'), isNull); // kedaluwarsa → null + dihapus

    final rows = await db.query('cached_rosters', where: 'extracurricular_id = ?', whereArgs: ['ek-1']);
    expect(rows, isEmpty);
  });

  test('roster: dari cache tanpa fetch ulang; purgeExpired membersihkan entri lama', () async {
    await cache.put('ek-1', await remote.roster('ek-1'));
    final r = await repo(online: false).roster('ek-1'); // offline tapi ada cache
    expect(r.students.single.fullName, 'Ahmad');

    await db.insert('cached_rosters', {
      'extracurricular_id': 'ek-old',
      'roster_json': '{}',
      'cached_at': '2020-01-01T00:00:00.000',
      'expires_at': '2020-01-15T00:00:00.000',
    });
    final purged = await cache.purgeExpired();
    expect(purged, 1);
  });
}
