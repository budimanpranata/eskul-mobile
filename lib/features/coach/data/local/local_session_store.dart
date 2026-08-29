import 'dart:convert';

import 'package:sqflite/sqflite.dart';

enum SyncStatus { draft, pendingSync, synced }

SyncStatus _parseStatus(String s) => switch (s) {
      'PENDING_SYNC' => SyncStatus.pendingSync,
      'SYNCED' => SyncStatus.synced,
      _ => SyncStatus.draft,
    };

String _statusStr(SyncStatus s) => switch (s) {
      SyncStatus.pendingSync => 'PENDING_SYNC',
      SyncStatus.synced => 'SYNCED',
      SyncStatus.draft => 'DRAFT',
    };

class PendingSession {
  const PendingSession({
    required this.clientGeneratedId,
    required this.extracurricularId,
    required this.extracurricularName,
    required this.sessionDate,
    required this.payload,
    required this.status,
    required this.attemptCount,
    required this.lastError,
    required this.serverSessionId,
    required this.updatedAt,
  });

  final String clientGeneratedId;
  final String extracurricularId;
  final String? extracurricularName;
  final String sessionDate;
  final Map<String, dynamic> payload;
  final SyncStatus status;
  final int attemptCount;
  final String? lastError;
  final String? serverSessionId;
  final DateTime updatedAt;

  factory PendingSession._fromRow(Map<String, Object?> r) => PendingSession(
        clientGeneratedId: r['client_generated_id'] as String,
        extracurricularId: r['extracurricular_id'] as String,
        extracurricularName: r['extracurricular_name'] as String?,
        sessionDate: r['session_date'] as String,
        payload: jsonDecode(r['payload_json'] as String) as Map<String, dynamic>,
        status: _parseStatus(r['sync_status'] as String),
        attemptCount: (r['attempt_count'] as int?) ?? 0,
        lastError: r['last_error'] as String?,
        serverSessionId: r['server_session_id'] as String?,
        updatedAt: DateTime.parse(r['updated_at'] as String),
      );
}

/// DAO tabel `pending_sessions` — antrian sesi presensi offline-first.
class LocalSessionStore {
  LocalSessionStore(this._db);
  final Database _db;

  /// Ambil (kalau ada) draft/pending untuk kombinasi ekskul+tanggal.
  Future<PendingSession?> findByEkskulDate(String extracurricularId, String sessionDate) async {
    final rows = await _db.query(
      'pending_sessions',
      where: 'extracurricular_id = ? AND session_date = ?',
      whereArgs: [extracurricularId, sessionDate],
      limit: 1,
    );
    return rows.isEmpty ? null : PendingSession._fromRow(rows.first);
  }

  Future<PendingSession?> findById(String clientGeneratedId) async {
    final rows = await _db.query(
      'pending_sessions',
      where: 'client_generated_id = ?',
      whereArgs: [clientGeneratedId],
      limit: 1,
    );
    return rows.isEmpty ? null : PendingSession._fromRow(rows.first);
  }

  /// Simpan/segarkan draft. Tidak menurunkan status SYNCED.
  Future<void> upsertDraft({
    required String clientGeneratedId,
    required String extracurricularId,
    String? extracurricularName,
    required String sessionDate,
    required Map<String, dynamic> payload,
  }) async {
    final now = DateTime.now().toIso8601String();
    final existing = await findById(clientGeneratedId);
    if (existing != null && existing.status == SyncStatus.synced) return;

    await _db.insert(
      'pending_sessions',
      {
        'client_generated_id': clientGeneratedId,
        'extracurricular_id': extracurricularId,
        'extracurricular_name': extracurricularName,
        'session_date': sessionDate,
        'payload_json': jsonEncode(payload),
        'sync_status': existing?.status == SyncStatus.pendingSync ? 'PENDING_SYNC' : 'DRAFT',
        'attempt_count': existing?.attemptCount ?? 0,
        'created_at': existing == null ? now : existing.updatedAt.toIso8601String(),
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> setStatus(
    String clientGeneratedId,
    SyncStatus status, {
    String? serverSessionId,
    String? lastError,
    int? attemptCount,
  }) async {
    final now = DateTime.now();
    await _db.update(
      'pending_sessions',
      {
        'sync_status': _statusStr(status),
        if (serverSessionId != null) 'server_session_id': serverSessionId,
        'last_error': lastError,
        if (attemptCount != null) 'attempt_count': attemptCount,
        'updated_at': now.toIso8601String(),
        if (status == SyncStatus.synced) 'synced_at': now.toIso8601String(),
      },
      where: 'client_generated_id = ?',
      whereArgs: [clientGeneratedId],
    );
  }

  Future<void> incrementAttempt(String clientGeneratedId, String error) async {
    await _db.rawUpdate(
      'UPDATE pending_sessions SET attempt_count = attempt_count + 1, last_error = ?, updated_at = ? '
      'WHERE client_generated_id = ?',
      [error, DateTime.now().toIso8601String(), clientGeneratedId],
    );
  }

  Future<List<PendingSession>> listPendingSync() => _list("sync_status = 'PENDING_SYNC'");

  Future<List<PendingSession>> listAll() => _list(null);

  Future<int> pendingCount() async {
    final r = await _db.rawQuery(
      "SELECT COUNT(*) c FROM pending_sessions WHERE sync_status = 'PENDING_SYNC'",
    );
    return (r.first['c'] as int?) ?? 0;
  }

  Future<List<PendingSession>> _list(String? where) async {
    final rows = await _db.query(
      'pending_sessions',
      where: where,
      orderBy: 'updated_at DESC',
    );
    return rows.map(PendingSession._fromRow).toList();
  }
}
