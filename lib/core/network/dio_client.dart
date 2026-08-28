import 'package:dio/dio.dart';

import '../config/app_config.dart';

/// Factory Dio terpusat untuk memanggil backend eskul.
///
/// FASE 0: hanya opsi dasar (base URL + timeout). Interceptor auth
/// (inject Bearer token, auto-refresh saat 401) dan logging ditambahkan di Fase 1.
Dio createDioClient() {
  return Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(milliseconds: AppConfig.connectTimeoutMs),
      receiveTimeout: const Duration(milliseconds: AppConfig.receiveTimeoutMs),
      contentType: 'application/json',
    ),
  );
}
