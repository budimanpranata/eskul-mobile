import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/secure_storage.dart';

/// Factory Dio untuk memanggil backend eskul.
///
/// - Menyisipkan `Authorization: Bearer <accessToken>` dari secure storage.
/// - Pada 401 (bukan endpoint /auth/*): coba `POST /auth/refresh` sekali, lalu
///   ulangi request. Bila gagal → hapus sesi lokal & panggil [onAuthFailure].
Dio createDioClient(SecureStorage storage, {void Function()? onAuthFailure}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(milliseconds: AppConfig.connectTimeoutMs),
      receiveTimeout: const Duration(milliseconds: AppConfig.receiveTimeoutMs),
      contentType: 'application/json',
      validateStatus: (s) => s != null && s < 500,
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await storage.accessToken;
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (err, handler) async {
        final req = err.requestOptions;
        final is401 = err.response?.statusCode == 401;
        final isAuthCall = req.path.contains('/auth/');
        final alreadyRetried = req.extra['__retried'] == true;

        if (is401 && !isAuthCall && !alreadyRetried) {
          final refreshed = await _tryRefresh(storage);
          if (refreshed != null) {
            req.extra['__retried'] = true;
            req.headers['Authorization'] = 'Bearer $refreshed';
            try {
              final res = await dio.fetch<dynamic>(req);
              return handler.resolve(res);
            } catch (_) {
              // jatuh ke pembersihan sesi di bawah
            }
          }
          await storage.clear();
          onAuthFailure?.call();
        }
        handler.next(err);
      },
    ),
  );

  return dio;
}

Future<String?> _tryRefresh(SecureStorage storage) async {
  final refresh = await storage.refreshToken;
  if (refresh == null) return null;
  try {
    final bare = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
    final r = await bare.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: {'refreshToken': refresh},
    );
    final data = r.data!;
    await storage.saveTokens(
      access: data['accessToken'] as String,
      refresh: data['refreshToken'] as String,
    );
    return data['accessToken'] as String;
  } catch (_) {
    return null;
  }
}
