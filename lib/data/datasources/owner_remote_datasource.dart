import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_response.dart';

class OwnerRemoteDataSource {
  OwnerRemoteDataSource({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<ApiResponse> getDashboard() {
    return _apiClient.get(ApiEndpoints.ownerDashboard);
  }

  Future<ApiResponse> getUsers({
    String? search,
    String? role,
    String? status,
    int perPage = 100,
  }) {
    return _apiClient.get(
      ApiEndpoints.ownerUsers,
      queryParameters: {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (role != null && role.trim().isNotEmpty) 'role': role.trim(),
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
        'per_page': perPage,
      },
    );
  }

  Future<ApiResponse> createStaff({
    required String name,
    required String email,
    required String password,
    required String role,
    String? phone,
  }) {
    return _apiClient.post(
      ApiEndpoints.ownerUsers,
      body: {
        'name': name.trim(),
        'email': email.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        'password': password,
        'password_confirmation': password,
        'role': role.trim().toLowerCase(),
      },
    );
  }

  Future<ApiResponse> updateUserRole({
    required int userId,
    required String role,
  }) {
    return _apiClient.patch(
      ApiEndpoints.ownerUserRole(userId),
      body: {'role': role.trim().toLowerCase()},
    );
  }

  Future<ApiResponse> updateUserStatus({
    required int userId,
    required String status,
  }) {
    return _apiClient.patch(
      ApiEndpoints.ownerUserStatus(userId),
      body: {'status': status.trim().toLowerCase()},
    );
  }
}
