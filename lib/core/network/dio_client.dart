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

  // Single-flight: request paralel yang 401 bersamaan (mis. beberapa panggilan
  // dashboard saat app dibuka lagi setelah lama idle) menumpang SATU percobaan
  // refresh yang sama, bukan masing-masing memanggil /auth/refresh sendiri.
  // Tanpa ini, refresh ke-2/ke-3 memakai refresh token yang SUDAH diputar
  // (revoked) oleh refresh pertama yang lebih dulu selesai → gagal → sesi yang
  // baru saja berhasil di-refresh ikut terhapus (storage.clear()).
  Future<String?>? inflightRefresh;
  Future<String?> refreshOnce() {
    return inflightRefresh ??= _tryRefresh(storage).whenComplete(() => inflightRefresh = null);
  }

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
          final refreshed = await refreshOnce();
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
    // PENTING: timeout eksplisit. Tanpa ini, Dio menunggu TANPA BATAS WAKTU —
    // kalau jaringan macet tepat saat app dibuka lagi setelah lama idle
    // (umum terjadi: radio/Wi-Fi baru bangun dari deep sleep), `await` di
    // bawah tidak pernah selesai, request asli yang memicu refresh ini pun
    // tidak pernah resolve, dan provider yang menunggunya macet di loading
    // selamanya — satu-satunya jalan keluar yang terlihat user adalah logout
    // manual lalu login ulang. Dengan timeout, refresh gagal cepat & jatuh ke
    // alur sesi-habis (storage.clear() + onAuthFailure) yang sudah benar.
    final bare = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(milliseconds: AppConfig.connectTimeoutMs),
        receiveTimeout: const Duration(milliseconds: AppConfig.receiveTimeoutMs),
      ),
    );
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
