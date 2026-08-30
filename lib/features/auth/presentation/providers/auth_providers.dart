import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/push/device_registration.dart';
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

  Future<void> _afterAuth() async {
    await registerDeviceToken(
      ref.read(dioProvider),
      ref.read(secureStorageProvider),
    );
  }

  Future<void> login(String identifier, String password) async {
    final session = await ref
        .read(authRepositoryProvider)
        .login(identifier: identifier, password: password);
    state = session;
    await _afterAuth();
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
    await _afterAuth();
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

/// Profil pengguna login (`GET /auth/me`) — email, no. HP, dsb. untuk layar Profil.
final authMeProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  // Ikut daur ulang saat sesi berganti.
  ref.watch(authSessionProvider);
  final res = await ref.watch(dioProvider).get<Map<String, dynamic>>('/auth/me');
  return res.data ?? const {};
});

/// Dijalankan sekali saat aplikasi dibuka: pulihkan sesi dari secure storage.
final sessionRestoreProvider = FutureProvider<void>((ref) async {
  final restored = await ref.read(authRepositoryProvider).restoreSession();
  if (restored != null) {
    ref.read(authSessionProvider.notifier).setSession(restored);
    await registerDeviceToken(ref.read(dioProvider), ref.read(secureStorageProvider));
  }
});
