/// Konfigurasi aplikasi yang di-inject saat build.
///
/// Nilai dilewatkan via `--dart-define`, mis.:
/// `flutter run --dart-define=API_BASE_URL=https://api.ekskul-sd.sch.id/api/v1`
class AppConfig {
  const AppConfig._();

  /// Base URL API backend (bagian 4 dokumen desain).
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api/v1', // 10.0.2.2 = localhost host dari emulator Android
  );

  /// Timeout default request (ms).
  static const int connectTimeoutMs = 15000;
  static const int receiveTimeoutMs = 20000;

  /// Expiry cache roster lokal (hari) — sesuai strategi offline bagian 6.
  static const int localRosterTtlDays = 14;
}
