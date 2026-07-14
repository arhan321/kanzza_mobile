import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_response.dart';

class AddressRemoteDataSource {
  AddressRemoteDataSource({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<ApiResponse> getAddresses() {
    return _apiClient.get(
      ApiEndpoints.addresses,
    );
  }

  Future<ApiResponse> createAddress({
    required String label,
    required String recipientName,
    required String phone,
    required String fullAddress,
    String? province,
    String? city,
    String? district,
    String? postalCode,
    double? latitude,
    double? longitude,
    bool isDefault = false,
  }) {
    return _apiClient.post(
      ApiEndpoints.addresses,
      body: {
        'label': label.trim(),
        'recipient_name': recipientName.trim(),
        'phone': phone.trim(),
        'full_address': fullAddress.trim(),
        if (province != null &&
            province.trim().isNotEmpty)
          'province': province.trim(),
        if (city != null && city.trim().isNotEmpty)
          'city': city.trim(),
        if (district != null &&
            district.trim().isNotEmpty)
          'district': district.trim(),
        if (postalCode != null &&
            postalCode.trim().isNotEmpty)
          'postal_code': postalCode.trim(),
        'latitude': ?latitude,
        'longitude': ?longitude,
        'is_default': isDefault,
      },
    );
  }

  Future<ApiResponse> updateAddress({
    required int addressId,
    required Map<String, dynamic> body,
  }) {
    return _apiClient.patch(
      ApiEndpoints.addressDetail(addressId),
      body: body,
    );
  }

  Future<ApiResponse> deleteAddress(int addressId) {
    return _apiClient.delete(
      ApiEndpoints.addressDetail(addressId),
    );
  }
}
