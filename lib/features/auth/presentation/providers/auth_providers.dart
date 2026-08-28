import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';

/// Wiring dependency (Riverpod) untuk fitur auth.

final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage());

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remote: AuthRemoteDataSource(createDioClient()),
    storage: ref.watch(secureStorageProvider),
  );
});

/// Sesi auth aktif. `null` = belum login.
///
/// FASE 0: hanya di-set manual (simulasi role di LoginPage).
/// Di Fase 1.1 diisi lewat pemanggilan [AuthRepository.login] / restoreSession().
class AuthSessionNotifier extends Notifier<AuthSession?> {
  @override
  AuthSession? build() => null;

  void setSession(AuthSession session) => state = session;
  void clear() => state = null;
}

final authSessionProvider =
    NotifierProvider<AuthSessionNotifier, AuthSession?>(AuthSessionNotifier.new);
