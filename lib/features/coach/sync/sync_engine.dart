import 'dart:async';

import 'package:dio/dio.dart';

import '../data/datasources/coach_remote_datasource.dart';
import '../data/local/local_session_store.dart';
import '../data/local/roster_cache.dart';
import '../data/submit_outcome.dart';

class SyncReport {
  const SyncReport({required this.synced, required this.stillPending, required this.failedValidation});
  final int synced;
  final int stillPending;
  final int failedValidation;
}

/// Mesin sinkronisasi sesi presensi offline (dokumen desain bagian 6).
///
/// - dipicu saat konektivitas kembali online + timer periodik
/// - tiap sesi PENDING_SYNC: exponential backoff 1s/2s/4s, maks 3 percobaan
///   per siklus; jika tetap gagal → tetap PENDING_SYNC, dicoba lagi siklus berikutnya
/// - 201 & 409 sama-sama menandai SYNCED (idempoten via client_generated_id)
class SyncEngine {
  SyncEngine({
    required CoachRemoteDataSource remote,
    required LocalSessionStore store,
    required RosterCache rosterCache,
    Duration Function(int attempt)? backoff,
    this.periodic = const Duration(minutes: 5),
  })  : _remote = remote,
        _store = store,
        _cache = rosterCache,
        _backoff = backoff ?? _defaultBackoff;

  final CoachRemoteDataSource _remote;
  final LocalSessionStore _store;
  final RosterCache _cache;
  final Duration Function(int attempt) _backoff;
  final Duration periodic;

  static const int maxAttemptsPerCycle = 3;
  static Duration _defaultBackoff(int attempt) => Duration(seconds: 1 << attempt); // 1,2,4

  bool _running = false;
  Timer? _timer;

  void startPeriodic() {
    _timer ??= Timer.periodic(periodic, (_) => syncNow());
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  /// Sinkronkan semua sesi PENDING_SYNC. Aman dipanggil berkali-kali (re-entrancy guard).
  Future<SyncReport> syncNow() async {
    if (_running) return const SyncReport(synced: 0, stillPending: 0, failedValidation: 0);
    _running = true;
    var synced = 0;
    var failedValidation = 0;
    try {
      await _cache.purgeExpired();
      final pending = await _store.listPendingSync();
      for (final p in pending) {
        final outcome = await _syncOne(p.clientGeneratedId, p.payload);
        if (outcome == _One.synced) synced++;
        if (outcome == _One.validation) failedValidation++;
      }
      final stillPending = await _store.pendingCount();
      return SyncReport(synced: synced, stillPending: stillPending, failedValidation: failedValidation);
    } finally {
      _running = false;
    }
  }

  Future<_One> _syncOne(String cgid, Map<String, dynamic> payload) async {
    for (var attempt = 0; attempt < maxAttemptsPerCycle; attempt++) {
      if (attempt > 0) await Future<void>.delayed(_backoff(attempt - 1));
      try {
        final res = await _remote.submit(payload);
        final interp = interpretSubmitResponse(res);
        switch (interp) {
          case InterpretedSynced(:final result):
            await _store.setStatus(cgid, SyncStatus.synced, serverSessionId: result.sessionId);
            return _One.synced;
          case InterpretedAlreadySynced(:final serverSessionId):
            await _store.setStatus(cgid, SyncStatus.synced, serverSessionId: serverSessionId);
            return _One.synced;
          case InterpretedValidationError(:final exception):
            // Data ditolak server — tak bisa auto-perbaiki; kembalikan ke DRAFT untuk ditinjau pembina.
            await _store.setStatus(cgid, SyncStatus.draft, lastError: exception.toString());
            return _One.validation;
          case InterpretedRetryable(:final message):
            await _store.incrementAttempt(cgid, message);
        }
      } on DioException catch (e) {
        await _store.incrementAttempt(cgid, e.message ?? 'network error');
      }
    }
    return _One.stillPending; // tetap PENDING_SYNC, dicoba siklus berikutnya
  }
}

enum _One { synced, stillPending, validation }
