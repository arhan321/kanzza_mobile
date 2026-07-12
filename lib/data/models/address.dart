class AddressModel {
  final int id;
  final String label;
  final String recipientName;
  final String phone;
  final String fullAddress;
  final String? province;
  final String? city;
  final String? district;
  final String? postalCode;
  final double? latitude;
  final double? longitude;
  final bool isDefault;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AddressModel({
    required this.id,
    required this.label,
    required this.recipientName,
    required this.phone,
    required this.fullAddress,
    required this.isDefault,
    this.province,
    this.city,
    this.district,
    this.postalCode,
    this.latitude,
    this.longitude,
    this.createdAt,
    this.updatedAt,
  });

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      id: _parseInt(json['id']),
      label: json['label']?.toString() ?? '',
      recipientName:
          json['recipient_name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      fullAddress:
          json['full_address']?.toString() ?? '',
      province: _parseNullableString(json['province']),
      city: _parseNullableString(json['city']),
      district: _parseNullableString(json['district']),
      postalCode:
          _parseNullableString(json['postal_code']),
      latitude: _parseNullableDouble(json['latitude']),
      longitude:
          _parseNullableDouble(json['longitude']),
      isDefault: _parseBool(
        json['is_default'],
        fallback: false,
      ),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'recipient_name': recipientName,
      'phone': phone,
      'full_address': fullAddress,
      'province': province,
      'city': city,
      'district': district,
      'postal_code': postalCode,
      'latitude': latitude,
      'longitude': longitude,
      'is_default': isDefault,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  String get locationSummary {
    final parts = <String>[
      if (district != null && district!.trim().isNotEmpty)
        district!,
      if (city != null && city!.trim().isNotEmpty) city!,
      if (province != null && province!.trim().isNotEmpty)
        province!,
      if (postalCode != null &&
          postalCode!.trim().isNotEmpty)
        postalCode!,
    ];

    return parts.join(', ');
  }

  static int _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? _parseNullableDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
  }

  static bool _parseBool(
    dynamic value, {
    required bool fallback,
  }) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value.toInt() == 1;
    }

    final text = value?.toString().trim().toLowerCase();

    if (text == 'true' || text == '1') {
      return true;
    }

    if (text == 'false' || text == '0') {
      return false;
    }

    return fallback;
  }

  static String? _parseNullableString(dynamic value) {
    final text = value?.toString().trim();

    if (text == null ||
        text.isEmpty ||
        text.toLowerCase() == 'null') {
      return null;
    }

    return text;
  }

  static DateTime? _parseDateTime(dynamic value) {
    final text = value?.toString().trim();

    if (text == null || text.isEmpty) {
      return null;
    }

    return DateTime.tryParse(text);
  }
}
