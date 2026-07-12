import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_response.dart';

class ProductRemoteDataSource {
  ProductRemoteDataSource({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<ApiResponse> getCategories() {
    return _apiClient.get(
      ApiEndpoints.categories,
    );
  }

  Future<ApiResponse> getProducts({
    String? search,
    int? categoryId,
    bool isActive = true,
    bool lowStock = false,
    int perPage = 100,
  }) {
    return _apiClient.get(
      ApiEndpoints.products,
      queryParameters: {
        'search': search,
        'category_id': categoryId,
        'is_active': isActive,
        'low_stock': lowStock,
        'per_page': perPage,
      },
    );
  }

  Future<ApiResponse> getProductDetail(int productId) {
    return _apiClient.get(
      ApiEndpoints.productDetail(productId),
    );
  }
}
