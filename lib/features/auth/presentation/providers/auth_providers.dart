import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';

final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage());

/// Dio bersama untuk seluruh aplikasi (interceptor auth + auto-refresh).
final dioProvider = Provider<Dio>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return createDioClient(
    storage,
    onAuthFailure: () => ref.read(authSessionProvider.notifier).clear(),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remote: AuthRemoteDataSource(ref.watch(dioProvider)),
    storage: ref.watch(secureStorageProvider),
  );
});

/// Sesi auth aktif. `null` = belum login.
class AuthSessionNotifier extends Notifier<AuthSession?> {
  @override
  AuthSession? build() => null;

  Future<void> login(String identifier, String password) async {
    final session = await ref
        .read(authRepositoryProvider)
        .login(identifier: identifier, password: password);
    state = session;
  }

  Future<void> registerParent({
    required String fullName,
    required String email,
    String? phoneNumber,
    required String password,
    required String relationType,
    required bool consent,
  }) async {
    final session = await ref.read(authRepositoryProvider).registerParent(
          fullName: fullName,
          email: email,
          phoneNumber: phoneNumber,
          password: password,
          relationType: relationType,
          consent: consent,
        );
    state = session;
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = null;
  }

  void setSession(AuthSession session) => state = session;
  void clear() => state = null;
}

final authSessionProvider =
    NotifierProvider<AuthSessionNotifier, AuthSession?>(AuthSessionNotifier.new);

/// Dijalankan sekali saat aplikasi dibuka: pulihkan sesi dari secure storage.
final sessionRestoreProvider = FutureProvider<void>((ref) async {
  final restored = await ref.read(authRepositoryProvider).restoreSession();
  if (restored != null) {
    ref.read(authSessionProvider.notifier).setSession(restored);
  }
});
