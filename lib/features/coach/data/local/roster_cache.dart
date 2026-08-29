import 'dart:convert';

import 'package:sqflite/sqflite.dart';

/// Cache roster per ekskul dengan expiry 14 hari (dokumen desain bagian 6).
class RosterCache {
  RosterCache(this._db, {this.ttl = const Duration(days: 14)});
  final Database _db;
  final Duration ttl;

  /// Roster tersimpan bila BELUM kedaluwarsa; jika kedaluwarsa → dihapus & null.
  Future<Map<String, dynamic>?> get(String extracurricularId) async {
    final rows = await _db.query(
      'cached_rosters',
      where: 'extracurricular_id = ?',
      whereArgs: [extracurricularId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final expiresAt = DateTime.parse(rows.first['expires_at'] as String);
    if (DateTime.now().isAfter(expiresAt)) {
      await _db.delete('cached_rosters', where: 'extracurricular_id = ?', whereArgs: [extracurricularId]);
      return null;
    }
    return jsonDecode(rows.first['roster_json'] as String) as Map<String, dynamic>;
  }

  Future<void> put(String extracurricularId, Map<String, dynamic> roster) async {
    final now = DateTime.now();
    await _db.insert(
      'cached_rosters',
      {
        'extracurricular_id': extracurricularId,
        'roster_json': jsonEncode(roster),
        'cached_at': now.toIso8601String(),
        'expires_at': now.add(ttl).toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Hapus semua entri kedaluwarsa. Return jumlah baris terhapus.
  Future<int> purgeExpired() {
    return _db.delete(
      'cached_rosters',
      where: 'expires_at < ?',
      whereArgs: [DateTime.now().toIso8601String()],
    );
  }
}
