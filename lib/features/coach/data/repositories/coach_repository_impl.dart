import 'package:dio/dio.dart';

import '../../domain/entities/coach_entities.dart';
import '../../domain/repositories/coach_repository.dart';
import '../datasources/coach_remote_datasource.dart';
import '../local/local_session_store.dart';
import '../local/roster_cache.dart';
import '../submit_outcome.dart';

class CoachRepositoryImpl implements CoachRepository {
  CoachRepositoryImpl({
    required CoachRemoteDataSource remote,
    required LocalSessionStore store,
    required RosterCache rosterCache,
    required Future<bool> Function() isOnline,
  })  : _remote = remote,
        _store = store,
        _cache = rosterCache,
        _isOnline = isOnline;

  final CoachRemoteDataSource _remote;
  final LocalSessionStore _store;
  final RosterCache _cache;
  final Future<bool> Function() _isOnline;

  @override
  Future<TodaySessionsResult> todaySessions() async =>
      TodaySessionsResult.fromJson(await _remote.todaySessions());

  @override
  Future<Roster> roster(String extracurricularId) async {
    final cached = await _cache.get(extracurricularId);
    if (cached != null) return Roster.fromJson(cached);
    try {
      final fresh = await _remote.roster(extracurricularId);
      await _cache.put(extracurricularId, fresh);
      return Roster.fromJson(fresh);
    } catch (e) {
      throw Exception('Roster belum tersedia offline untuk ekskul ini. ($e)');
    }
  }

  @override
  Future<void> saveDraft({
    required String clientGeneratedId,
    required String extracurricularId,
    String? extracurricularName,
    required String sessionDate,
    required Map<String, dynamic> payload,
  }) {
    return _store.upsertDraft(
      clientGeneratedId: clientGeneratedId,
      extracurricularId: extracurricularId,
      extracurricularName: extracurricularName,
      sessionDate: sessionDate,
      payload: payload,
    );
  }

  @override
  Future<SubmitOutcome> submit(String clientGeneratedId) async {
    final row = await _store.findById(clientGeneratedId);
    if (row == null) {
      throw StateError('Draft $clientGeneratedId tidak ditemukan di penyimpanan lokal.');
    }

    if (!await _isOnline()) {
      await _store.setStatus(clientGeneratedId, SyncStatus.pendingSync);
      return SubmitQueuedOffline();
    }

    final Response<dynamic> res;
    try {
      res = await _remote.submit(row.payload);
    } on DioException {
      // Koneksi putus di tengah request → antre untuk sinkron berikutnya.
      await _store.setStatus(clientGeneratedId, SyncStatus.pendingSync);
      return SubmitQueuedOffline();
    }

    final interp = interpretSubmitResponse(res);
    switch (interp) {
      case InterpretedSynced(:final result):
        await _store.setStatus(clientGeneratedId, SyncStatus.synced,
            serverSessionId: result.sessionId);
        return SubmitSynced(result);
      case InterpretedAlreadySynced(:final serverSessionId):
        await _store.setStatus(clientGeneratedId, SyncStatus.synced,
            serverSessionId: serverSessionId);
        return SubmitAlreadySynced(serverSessionId);
      case InterpretedValidationError(:final exception):
        await _store.setStatus(clientGeneratedId, SyncStatus.draft,
            lastError: exception.toString());
        throw exception;
      case InterpretedRetryable(:final message):
        await _store.setStatus(clientGeneratedId, SyncStatus.pendingSync, lastError: message);
        return SubmitQueuedOffline();
    }
  }
}
