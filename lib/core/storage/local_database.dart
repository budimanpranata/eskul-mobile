import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

/// Skema database lokal (offline-first — dokumen desain bagian 6).
const int kLocalDbVersion = 2;
const String kLocalDbName = 'eskul_mobile.db';

/// Membuka database lokal. `factory`/`path` di-inject untuk pengujian
/// (sqflite_common_ffi + in-memory).
Future<Database> openAppDatabase({DatabaseFactory? factory, String? path}) async {
  final f = factory ?? databaseFactory;
  final dbPath = path ?? '${await f.getDatabasesPath()}/$kLocalDbName';
  return f.openDatabase(
    dbPath,
    options: OpenDatabaseOptions(
      version: kLocalDbVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) => _createSchema(db),
      onUpgrade: (db, from, _) async {
        if (from < 2) {
          await db.execute('DROP TABLE IF EXISTS pending_sessions');
          await db.execute('DROP TABLE IF EXISTS cached_rosters');
          await _createSchema(db);
        }
      },
    ),
  );
}

Future<void> _createSchema(Database db) async {
  // Antrian sesi presensi yang belum tersinkron (draft/pending/synced).
  await db.execute('''
    CREATE TABLE pending_sessions (
      client_generated_id TEXT PRIMARY KEY,
      extracurricular_id  TEXT NOT NULL,
      extracurricular_name TEXT,
      session_date        TEXT NOT NULL,
      payload_json        TEXT NOT NULL,
      sync_status         TEXT NOT NULL DEFAULT 'DRAFT',
      attempt_count       INTEGER NOT NULL DEFAULT 0,
      last_error          TEXT,
      server_session_id   TEXT,
      created_at          TEXT NOT NULL,
      updated_at          TEXT NOT NULL,
      synced_at           TEXT
    );
  ''');
  await db.execute(
    'CREATE UNIQUE INDEX ux_pending_ekskul_date ON pending_sessions(extracurricular_id, session_date);',
  );

  // Cache roster per ekskul dengan expiry (14 hari — dokumen desain bagian 6).
  await db.execute('''
    CREATE TABLE cached_rosters (
      extracurricular_id TEXT PRIMARY KEY,
      roster_json        TEXT NOT NULL,
      cached_at          TEXT NOT NULL,
      expires_at         TEXT NOT NULL
    );
  ''');
}

/// Instance Database aktif — WAJIB di-override di `main.dart` / test.
final appDatabaseProvider = Provider<Database>(
  (ref) => throw UnimplementedError('appDatabaseProvider harus di-override dengan Database.'),
);
