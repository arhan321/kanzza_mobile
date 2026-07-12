import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_response.dart';

class CustomerOrderRemoteDataSource {
  CustomerOrderRemoteDataSource({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<ApiResponse> createOrder({
    required String deliveryMethod,
    int? addressId,
    required List<Map<String, int>> items,
    String? notes,
  }) {
    return _apiClient.post(
      ApiEndpoints.orders,
      body: {
        'delivery_method': deliveryMethod,
        if (addressId != null) 'address_id': addressId,
        'items': items,
        if (notes != null && notes.trim().isNotEmpty)
          'notes': notes.trim(),
      },
    );
  }

  Future<ApiResponse> createOrReusePayment(int orderId) {
    return _apiClient.post(
      ApiEndpoints.orderPayment(orderId),
    );
  }

  Future<ApiResponse> checkPaymentStatus(int orderId) {
    return _apiClient.post(
      ApiEndpoints.checkOrderPayment(orderId),
    );
  }

  Future<ApiResponse> getOrderDetail(int orderId) {
    return _apiClient.get(
      ApiEndpoints.orderDetail(orderId),
    );
  }
}
