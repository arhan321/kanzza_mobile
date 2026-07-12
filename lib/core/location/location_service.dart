import 'dart:async';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class DetectedLocation {
  final double latitude;
  final double longitude;
  final double accuracy;
  final String fullAddress;
  final String? district;
  final String? city;
  final String? province;
  final String? postalCode;

  const DetectedLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.fullAddress,
    this.district,
    this.city,
    this.province,
    this.postalCode,
  });
}

enum LocationFailureType {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  unavailable,
}

class LocationFailure implements Exception {
  final LocationFailureType type;
  final String message;

  const LocationFailure(this.type, this.message);

  @override
  String toString() => message;
}

class LocationService {
  const LocationService();

  Future<DetectedLocation> detectCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw const LocationFailure(
        LocationFailureType.serviceDisabled,
        'GPS belum aktif. Aktifkan layanan lokasi lalu coba kembali.',
      );
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const LocationFailure(
        LocationFailureType.permissionDenied,
        'Izin lokasi ditolak. Izin diperlukan untuk mendeteksi alamat.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationFailure(
        LocationFailureType.permissionDeniedForever,
        'Izin lokasi ditolak permanen. Aktifkan izin dari pengaturan aplikasi.',
      );
    }

    Position? position;

    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      ).timeout(const Duration(seconds: 20));
    } on TimeoutException {
      position = await Geolocator.getLastKnownPosition();

      if (position == null) {
        throw const LocationFailure(
          LocationFailureType.timeout,
          'Lokasi belum ditemukan. Pastikan GPS aktif dan coba di area terbuka.',
        );
      }
    } catch (error) {
      if (error is LocationFailure) {
        rethrow;
      }

      position = await Geolocator.getLastKnownPosition();

      if (position == null) {
        throw LocationFailure(
          LocationFailureType.unavailable,
          'Lokasi gagal dideteksi: $error',
        );
      }
    }

    return _buildDetectedLocation(position);
  }

  Future<DetectedLocation> _buildDetectedLocation(Position position) async {
    Placemark? placemark;

    try {
      await setLocaleIdentifier('id_ID');

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(const Duration(seconds: 12));

      if (placemarks.isNotEmpty) {
        placemark = placemarks.first;
      }
    } catch (_) {
      placemark = null;
    }

    final district = _firstNotEmpty([
      placemark?.subLocality,
      placemark?.locality,
    ]);

    final city = _firstNotEmpty([
      placemark?.subAdministrativeArea,
      placemark?.locality,
    ]);

    final province = _clean(placemark?.administrativeArea);

    final postalCode = _clean(placemark?.postalCode);

    final addressParts = _uniqueNotEmpty([
      placemark?.street,
      placemark?.subLocality,
      placemark?.locality,
      placemark?.subAdministrativeArea,
      placemark?.administrativeArea,
      placemark?.postalCode,
    ]);

    final fallbackAddress =
        'Lokasi saat ini '
        '(${position.latitude.toStringAsFixed(6)}, '
        '${position.longitude.toStringAsFixed(6)})';

    return DetectedLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      fullAddress: addressParts.isEmpty
          ? fallbackAddress
          : addressParts.join(', '),
      district: district,
      city: city,
      province: province,
      postalCode: postalCode,
    );
  }

  static Future<bool> openLocationSettings() {
    return Geolocator.openLocationSettings();
  }

  static Future<bool> openAppSettings() {
    return Geolocator.openAppSettings();
  }

  static double distanceInKilometers({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    return Geolocator.distanceBetween(
          startLatitude,
          startLongitude,
          endLatitude,
          endLongitude,
        ) /
        1000;
  }

  static String? _firstNotEmpty(List<String?> values) {
    for (final value in values) {
      final cleaned = _clean(value);

      if (cleaned != null) {
        return cleaned;
      }
    }

    return null;
  }

  static List<String> _uniqueNotEmpty(List<String?> values) {
    final result = <String>[];
    final normalized = <String>{};

    for (final value in values) {
      final cleaned = _clean(value);

      if (cleaned == null) {
        continue;
      }

      final key = cleaned.toLowerCase();

      if (normalized.add(key)) {
        result.add(cleaned);
      }
    }

    return result;
  }

  static String? _clean(String? value) {
    final cleaned = value?.trim();

    if (cleaned == null || cleaned.isEmpty) {
      return null;
    }

    return cleaned;
  }
}
