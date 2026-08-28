import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Database lokal SQLite (sqflite) untuk kebutuhan offline-first.
///
/// FASE 0: hanya kerangka + skema tabel antrian sync. Sync engine, caching
/// roster, dan resolusi konflik diimplementasikan di Fase 2.1
/// (lihat dokumen desain bagian 6 — Strategi Offline-First).
///
/// Tabel yang direncanakan:
///  - `pending_sessions`  : draft/antrian sesi presensi yang belum tersinkron
///                          (menyimpan client_generated_id sebagai idempotency key)
///  - `cached_rosters`    : salinan roster siswa per ekskul, dengan expiry 14 hari
class LocalDatabase {
  LocalDatabase._();
  static final LocalDatabase instance = LocalDatabase._();

  static const _dbName = 'eskul_mobile.db';
  static const _dbVersion = 1;

  Database? _db;

  Future<Database> get database async {
    return _db ??= await _open();
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE pending_sessions (
        client_generated_id TEXT PRIMARY KEY,
        extracurricular_id  TEXT NOT NULL,
        payload_json        TEXT NOT NULL,
        sync_status         TEXT NOT NULL DEFAULT 'DRAFT', -- DRAFT/PENDING_SYNC/SYNCED
        attempt_count       INTEGER NOT NULL DEFAULT 0,
        created_at          TEXT NOT NULL,
        updated_at          TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE cached_rosters (
        extracurricular_id  TEXT PRIMARY KEY,
        roster_json         TEXT NOT NULL,
        cached_at           TEXT NOT NULL,
        expires_at          TEXT NOT NULL
      );
    ''');
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
