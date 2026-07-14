import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_response.dart';

class DriverDeliveryRemoteDataSource {
  DriverDeliveryRemoteDataSource({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<ApiResponse> getDeliveries({String? status, int perPage = 100}) {
    return _apiClient.get(
      ApiEndpoints.driverDeliveries,
      queryParameters: {
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
        'per_page': perPage,
      },
    );
  }

  Future<ApiResponse> getDeliveryDetail(int deliveryId) {
    return _apiClient.get(ApiEndpoints.driverDeliveryDetail(deliveryId));
  }

  Future<ApiResponse> updateDeliveryStatus({
    required int deliveryId,
    required String status,
    String? notes,
    String? proofImagePath,
    bool? paymentReceived,
  }) {
    return _apiClient.patch(
      ApiEndpoints.updateDriverDeliveryStatus(deliveryId),
      body: {
        'status': status,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        if (proofImagePath != null && proofImagePath.trim().isNotEmpty)
          'proof_image_path': proofImagePath.trim(),
        'payment_received': ?paymentReceived,
      },
    );
  }
}
