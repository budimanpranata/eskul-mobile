import '../../../../core/storage/secure_storage.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

/// Implementasi [AuthRepository]: menjembatani datasource remote + secure storage.
///
/// FASE 0: kerangka — method melempar UnimplementedError sampai Fase 1.1.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remote,
    required SecureStorage storage,
  })  : _remote = remote,
        _storage = storage;

  // ignore: unused_field
  final AuthRemoteDataSource _remote;
  // ignore: unused_field
  final SecureStorage _storage;

  @override
  Future<AuthSession> login({required String identifier, required String password}) {
    throw UnimplementedError('Diimplementasikan di Fase 1.1');
  }

  @override
  Future<AuthSession> refresh(String refreshToken) {
    throw UnimplementedError('Diimplementasikan di Fase 1.1');
  }

  @override
  Future<void> logout() {
    throw UnimplementedError('Diimplementasikan di Fase 1.1');
  }

  @override
  Future<AuthSession?> restoreSession() async => null;
}
