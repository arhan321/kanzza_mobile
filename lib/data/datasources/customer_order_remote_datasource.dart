import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_response.dart';

class CustomerOrderRemoteDataSource {
  CustomerOrderRemoteDataSource({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<ApiResponse> getOrders({
    String? orderStatus,
    String? paymentStatus,
    String? search,
    int perPage = 100,
  }) {
    return _apiClient.get(
      ApiEndpoints.orders,
      queryParameters: {
        if (orderStatus != null && orderStatus.trim().isNotEmpty)
          'order_status': orderStatus.trim(),
        if (paymentStatus != null && paymentStatus.trim().isNotEmpty)
          'payment_status': paymentStatus.trim(),
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        'per_page': perPage,
      },
    );
  }

  Future<ApiResponse> createOrder({
    required String deliveryMethod,
    required String paymentMethod,
    double? distanceKm,
    int? shippingCost,
    int? addressId,
    required List<Map<String, int>> items,
    String? notes,
  }) {
    return _apiClient.post(
      ApiEndpoints.orders,
      body: {
        'delivery_method': deliveryMethod,
        'payment_method': paymentMethod,
        if (distanceKm != null) 'distance_km': distanceKm,
        if (shippingCost != null) 'shipping_cost': shippingCost,
        if (addressId != null) 'address_id': addressId,
        'items': items,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
  }

  Future<ApiResponse> getOrderDetail(int orderId) {
    return _apiClient.get(ApiEndpoints.orderDetail(orderId));
  }

  Future<ApiResponse> cancelOrder(int orderId) {
    return _apiClient.post(ApiEndpoints.cancelOrder(orderId));
  }

  Future<ApiResponse> createOrReusePayment(int orderId) {
    return _apiClient.post(ApiEndpoints.orderPayment(orderId));
  }

  Future<ApiResponse> checkPaymentStatus(int orderId) {
    return _apiClient.post(ApiEndpoints.checkOrderPayment(orderId));
  }
}
