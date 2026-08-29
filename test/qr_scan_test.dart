import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:eskul_mobile/core/storage/local_database.dart';
import 'package:eskul_mobile/features/coach/data/datasources/coach_remote_datasource.dart';
import 'package:eskul_mobile/features/coach/data/local/local_session_store.dart';
import 'package:eskul_mobile/features/coach/data/local/roster_cache.dart';
import 'package:eskul_mobile/features/coach/data/repositories/coach_repository_impl.dart';
import 'package:eskul_mobile/features/coach/domain/entities/coach_entities.dart';

class QrFakeRemote implements CoachRemoteDataSource {
  int nextStatus = 200;
  Map<String, dynamic> nextBody = const {
    'student': {'id': 's9', 'nis': 'N9', 'fullName': 'Sari', 'classGrade': '3B', 'photoUrl': null},
  };
  bool throwNetwork = false;

  @override
  Future<Response<dynamic>> qrScan(String qrToken, String extracurricularId) async {
    if (throwNetwork) {
      throw DioException(requestOptions: RequestOptions(path: '/x'), message: 'no net');
    }
    return Response<dynamic>(
      requestOptions: RequestOptions(path: '/coach/students/qr-scan'),
      statusCode: nextStatus,
      data: nextBody,
    );
  }

  @override
  Future<Response<dynamic>> submit(Map<String, dynamic> p) => throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> roster(String id) => throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> todaySessions() => throw UnimplementedError();
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late QrFakeRemote remote;
  late CoachRepositoryImpl repo;

  setUp(() async {
    db = await openAppDatabase(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    remote = QrFakeRemote();
    repo = CoachRepositoryImpl(
      remote: remote,
      store: LocalSessionStore(db),
      rosterCache: RosterCache(db),
      isOnline: () async => true,
    );
  });
  tearDown(() => db.close());

  test('200 → RosterStudent', () async {
    final s = await repo.resolveQr(qrToken: 'tok', extracurricularId: 'ek');
    expect(s.id, 's9');
    expect(s.fullName, 'Sari');
  });

  test('404 QR_INVALID → QrScanException(code QR_INVALID)', () async {
    remote.nextStatus = 404;
    remote.nextBody = {'error': 'QR_INVALID', 'message': 'Kartu QR tidak dikenal.'};
    await expectLater(
      repo.resolveQr(qrToken: 'x', extracurricularId: 'ek'),
      throwsA(isA<QrScanException>().having((e) => e.code, 'code', 'QR_INVALID')),
    );
  });

  test('422 NOT_A_MEMBER → QrScanException(code NOT_A_MEMBER)', () async {
    remote.nextStatus = 422;
    remote.nextBody = {'error': 'NOT_A_MEMBER', 'message': 'Bukan anggota.'};
    await expectLater(
      repo.resolveQr(qrToken: 'x', extracurricularId: 'ek'),
      throwsA(isA<QrScanException>().having((e) => e.code, 'code', 'NOT_A_MEMBER')),
    );
  });

  test('koneksi putus → QrScanException(OFFLINE)', () async {
    remote.throwNetwork = true;
    await expectLater(
      repo.resolveQr(qrToken: 'x', extracurricularId: 'ek'),
      throwsA(isA<QrScanException>().having((e) => e.code, 'code', 'OFFLINE')),
    );
  });
}
