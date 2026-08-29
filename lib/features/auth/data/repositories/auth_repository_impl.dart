import '../../../../core/constants/user_role.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remote,
    required SecureStorage storage,
  })  : _remote = remote,
        _storage = storage;

  final AuthRemoteDataSource _remote;
  final SecureStorage _storage;

  @override
  Future<AuthSession> login({required String identifier, required String password}) async {
    final data = await _remote.login(identifier, password);
    final session = _sessionFromLogin(data);
    await _persist(session);
    return session;
  }

  @override
  Future<AuthSession> refresh(String refreshToken) {
    // Rotasi refresh token ditangani di interceptor Dio (core/network/dio_client.dart).
    throw UnimplementedError('Refresh ditangani oleh interceptor Dio.');
  }

  @override
  Future<void> logout() async {
    try {
      await _remote.logout();
    } catch (_) {
      // tetap bersihkan sesi lokal
    }
    await _storage.clear();
  }

  @override
  Future<AuthSession?> restoreSession() async {
    final token = await _storage.accessToken;
    final meta = await _storage.readMeta();
    if (token == null || meta == null) return null;
    final refresh = await _storage.refreshToken ?? '';
    return AuthSession(
      userId: meta['id'] as String,
      fullName: meta['fullName'] as String,
      role: UserRole.fromCode(meta['role'] as String),
      accessToken: token,
      refreshToken: refresh,
    );
  }

  AuthSession _sessionFromLogin(Map<String, dynamic> data) {
    final user = data['user'] as Map<String, dynamic>;
    return AuthSession(
      userId: user['id'] as String,
      fullName: user['fullName'] as String,
      role: UserRole.fromCode(user['role'] as String),
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
  }

  Future<void> _persist(AuthSession s) async {
    await _storage.saveTokens(access: s.accessToken, refresh: s.refreshToken);
    await _storage.saveMeta({'id': s.userId, 'fullName': s.fullName, 'role': s.role.code});
  }
}
