import '../../../../core/constants/user_role.dart';

/// Hasil autentikasi yang dipakai lintas aplikasi.
class AuthSession {
  const AuthSession({
    required this.userId,
    required this.fullName,
    required this.role,
    required this.accessToken,
    required this.refreshToken,
  });

  final String userId;
  final String fullName;
  final UserRole role;
  final String accessToken;
  final String refreshToken;
}
