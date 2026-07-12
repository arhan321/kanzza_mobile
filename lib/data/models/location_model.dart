// data/models/location_model.dart

class LocationModel {
  final double latitude;
  final double longitude;
  final String address;
  final double distance; // in km
  final int shippingCost;

  LocationModel({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.distance,
    required this.shippingCost,
  });
}

class StoreLocation {
  // ⬇️ KOORDINAT TOKO CURUG, TANGERANG ⬇️
  static const double latitude = -6.282288;
  static const double longitude = 106.554848;
  
  // Informasi toko
  static const String storeName = "Kanzza Frozen Food";
  static const String address = "Jalan Raya PLP Curug No. 124, Legok, Tangerang Regency, Banten 15820, Indonesia";
  static const String phone = "+62 812-3456-7890";
  static const String email = "info@kanzza.com";
}