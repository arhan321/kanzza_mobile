class AppConfig {
  AppConfig._();
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://kanza.djncloud.my.id/api/v1',
  );

  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  static const String applicationName = 'Kanzza Frozen Food';

  // Backend Kanzza mulai commit 1cf156f mendukung COD untuk delivery.
  // Dart define tetap tersedia untuk mematikan fitur saat memakai backend lama.
  static const bool customerCodEnabled = bool.fromEnvironment(
    'CUSTOMER_COD_ENABLED',
    defaultValue: true,
  );
}
