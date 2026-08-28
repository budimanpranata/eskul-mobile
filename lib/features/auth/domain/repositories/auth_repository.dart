import '../entities/auth_session.dart';

/// Kontrak layer domain untuk autentikasi.
/// Implementasi konkret ada di layer data (`auth_repository_impl.dart`).
abstract interface class AuthRepository {
  /// POST /auth/login — lihat dokumen desain bagian 4.3.
  Future<AuthSession> login({required String identifier, required String password});

  /// POST /auth/refresh
  Future<AuthSession> refresh(String refreshToken);

  /// Hapus sesi lokal + revoke refresh token di server.
  Future<void> logout();

  /// Sesi tersimpan (jika ada) saat aplikasi dibuka kembali.
  Future<AuthSession?> restoreSession();
}
