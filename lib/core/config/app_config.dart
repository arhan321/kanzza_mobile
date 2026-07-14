class AppConfig {
  AppConfig._();
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://kanza.djncloud.my.id/api/v1',
  );

  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  static const String applicationName = 'Kanzza Frozen Food';

  // Aktifkan hanya setelah endpoint POST /orders backend menerima dan
  // mengembalikan payment_method "cash" untuk pesanan customer.
  static const bool customerCodEnabled = bool.fromEnvironment(
    'CUSTOMER_COD_ENABLED',
    defaultValue: false,
  );
}
