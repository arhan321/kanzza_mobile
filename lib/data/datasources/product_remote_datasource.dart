import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_response.dart';

class ProductRemoteDataSource {
  ProductRemoteDataSource({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<ApiResponse> getCategories({int perPage = 100}) {
    return _apiClient.get(
      ApiEndpoints.categories,
      queryParameters: {'per_page': perPage},
    );
  }

  Future<ApiResponse> getProducts({
    String? search,
    int? categoryId,
    bool? isActive = true,
    bool lowStock = false,
    int perPage = 100,
  }) {
    return _apiClient.get(
      ApiEndpoints.products,
      queryParameters: {
        'search': search,
        'category_id': categoryId,
        'is_active': ?isActive,
        'low_stock': lowStock,
        'per_page': perPage,
      },
    );
  }

  Future<ApiResponse> getProductDetail(int productId) {
    return _apiClient.get(ApiEndpoints.productDetail(productId));
  }

  Future<ApiResponse> createCashierProduct({
    required Map<String, dynamic> fields,
    String? imagePath,
  }) {
    return _apiClient.postMultipart(
      ApiEndpoints.cashierProducts,
      fields: fields,
      filePaths: imagePath == null ? null : {'image': imagePath},
    );
  }

  Future<ApiResponse> updateCashierProduct({
    required int productId,
    required Map<String, dynamic> fields,
    String? imagePath,
  }) {
    return _apiClient.postMultipart(
      ApiEndpoints.cashierProductDetail(productId),
      fields: fields,
      filePaths: imagePath == null ? null : {'image': imagePath},
    );
  }

  Future<ApiResponse> deleteCashierProduct(int productId) {
    return _apiClient.delete(ApiEndpoints.cashierProductDetail(productId));
  }

  Future<ApiResponse> createOwnerProduct({
    required Map<String, dynamic> fields,
    String? imagePath,
  }) {
    return _apiClient.postMultipart(
      ApiEndpoints.ownerProducts,
      fields: fields,
      filePaths: imagePath == null ? null : {'image': imagePath},
    );
  }

  Future<ApiResponse> updateOwnerProduct({
    required int productId,
    required Map<String, dynamic> fields,
    String? imagePath,
  }) {
    return _apiClient.postMultipart(
      ApiEndpoints.ownerProductDetail(productId),
      fields: fields,
      filePaths: imagePath == null ? null : {'image': imagePath},
    );
  }

  Future<ApiResponse> deleteOwnerProduct(int productId) {
    return _apiClient.delete(ApiEndpoints.ownerProductDetail(productId));
  }

  Future<ApiResponse> createOwnerCategory({
    required String name,
    String? description,
    bool isActive = true,
  }) {
    return _apiClient.post(
      ApiEndpoints.ownerCategories,
      body: {
        'name': name.trim(),
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        'is_active': isActive,
      },
    );
  }

  Future<ApiResponse> updateOwnerCategory({
    required int categoryId,
    required String name,
    String? description,
    required bool isActive,
  }) {
    return _apiClient.patch(
      ApiEndpoints.ownerCategoryDetail(categoryId),
      body: {
        'name': name.trim(),
        'description': description?.trim(),
        'is_active': isActive,
      },
    );
  }

  Future<ApiResponse> deleteOwnerCategory(int categoryId) {
    return _apiClient.delete(ApiEndpoints.ownerCategoryDetail(categoryId));
  }
}
