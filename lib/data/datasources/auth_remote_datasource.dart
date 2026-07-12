import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_response.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<ApiResponse> login({
    required String email,
    required String password,
    String deviceName = 'Kanzza Flutter',
  }) {
    return _apiClient.post(
      ApiEndpoints.login,
      requiresAuth: false,
      body: {
        'email': email.trim(),
        'password': password,
        'device_name': deviceName,
      },
    );
  }

  Future<ApiResponse> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirmation,
    String deviceName = 'Kanzza Flutter',
  }) {
    return _apiClient.post(
      ApiEndpoints.register,
      requiresAuth: false,
      body: {
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'password': password,
        'password_confirmation': passwordConfirmation,
        'device_name': deviceName,
      },
    );
  }

  Future<ApiResponse> getProfile() {
    return _apiClient.get(ApiEndpoints.profile);
  }

  Future<ApiResponse> logout() {
    return _apiClient.post(ApiEndpoints.logout);
  }
}
