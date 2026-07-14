import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_response.dart';

class CashierTransactionRemoteDataSource {
  CashierTransactionRemoteDataSource({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<ApiResponse> createTransaction({
    int? customerId,
    required List<Map<String, int>> items,
    required int paymentAmount,
    String? notes,
  }) {
    return _apiClient.post(
      ApiEndpoints.cashierTransactions,
      body: {
        'customer_id': ?customerId,
        'items': items,
        'payment_amount': paymentAmount,
        if (notes != null && notes.trim().isNotEmpty)
          'notes': notes.trim(),
      },
    );
  }

  Future<ApiResponse> getTransactions({
    int perPage = 100,
  }) {
    return _apiClient.get(
      ApiEndpoints.cashierTransactions,
      queryParameters: {
        'per_page': perPage,
      },
    );
  }
}
