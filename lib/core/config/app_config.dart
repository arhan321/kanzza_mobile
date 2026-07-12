class AppConfig {
  AppConfig._();
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://kanza.djncloud.my.id/api/v1',
  );

  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  static const String applicationName = 'Kanzza Frozen Food';
}
