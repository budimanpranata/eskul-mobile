import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';

const String defaultAppName = 'Eskul';
const String defaultLogoAsset = 'assets/logo_eskul.png';

/// Nama aplikasi + logo untuk layar login — `GET /settings/branding` (publik,
/// bisa dipanggil sebelum login). Kosong/null dari backend → fallback bawaan
/// (nama 'Eskul' + [defaultLogoAsset]) ditangani di sisi UI, bukan di sini.
class Branding {
  const Branding({required this.appName, required this.logoUrl});

  final String appName;
  final String? logoUrl;

  factory Branding.fromJson(Map<String, dynamic> j) => Branding(
        appName: (j['appName'] as String?)?.trim().isNotEmpty == true
            ? j['appName'] as String
            : defaultAppName,
        logoUrl: j['logoUrl'] as String?,
      );

  /// URL absolut siap pakai di `Image.network`, atau null → pakai aset bawaan.
  String? get absoluteLogoUrl => logoUrl == null ? null : '${AppConfig.apiOrigin}$logoUrl';
}

/// Gagal (offline, dll.) → null; UI harus pakai fallback bawaan, bukan error.
final brandingProvider = FutureProvider.autoDispose<Branding?>((ref) async {
  try {
    final dio = ref.watch(dioProvider);
    final r = await dio.get<Map<String, dynamic>>('/settings/branding');
    if (r.statusCode != 200 || r.data == null) return null;
    return Branding.fromJson(r.data!);
  } on DioException {
    return null;
  }
});
