/// Peran pengguna aplikasi mobile.
///
/// Satu codebase melayani dua mode: Pembina dan Orang Tua. Mode dipilih
/// berdasarkan [UserRole] yang dikembalikan backend setelah login
/// (lihat dokumen desain bagian 5 — Desain UX & Alur Aplikasi).
enum UserRole {
  pembina('PEMBINA'),
  orangtua('ORANGTUA');

  const UserRole(this.code);

  /// Kode role sesuai tabel `roles` di backend.
  final String code;

  static UserRole fromCode(String code) {
    return UserRole.values.firstWhere(
      (r) => r.code == code.toUpperCase(),
      orElse: () => throw ArgumentError('Role tidak dikenal untuk aplikasi mobile: $code'),
    );
  }
}
