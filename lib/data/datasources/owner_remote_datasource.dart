import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_response.dart';
import '../../core/network/api_download.dart';

class OwnerRemoteDataSource {
  OwnerRemoteDataSource({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<ApiResponse> getDashboard({String period = 'today'}) {
    return _apiClient.get(
      ApiEndpoints.ownerDashboard,
      queryParameters: {'period': period},
    );
  }

  Future<ApiResponse> getUsers({
    String? search,
    String? role,
    String? status,
    bool staffOnly = false,
    int perPage = 100,
  }) {
    return _apiClient.get(
      ApiEndpoints.ownerUsers,
      queryParameters: {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (role != null && role.trim().isNotEmpty) 'role': role.trim(),
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
        if (staffOnly) 'staff_only': true,
        'per_page': perPage,
      },
    );
  }

  Future<ApiResponse> createStaff({
    required String name,
    required String email,
    required String password,
    required String role,
    required String status,
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
        'status': status.trim().toLowerCase(),
      },
    );
  }

  Future<ApiResponse> getSalesReport({
    required DateTime startDate,
    required DateTime endDate,
    String? channel,
  }) {
    return _apiClient.get(
      ApiEndpoints.ownerSalesReports,
      queryParameters: {
        'start_date': _date(startDate),
        'end_date': _date(endDate),
        if (channel != null) 'channel': channel,
        'per_page': 100,
      },
    );
  }

  Future<ApiDownload> downloadSalesReport({
    required DateTime startDate,
    required DateTime endDate,
    required String format,
    String? channel,
  }) {
    return _apiClient.download(
      ApiEndpoints.ownerSalesReportExport,
      queryParameters: {
        'start_date': _date(startDate),
        'end_date': _date(endDate),
        if (channel != null) 'channel': channel,
        'format': format,
      },
    );
  }

  String _date(DateTime value) {
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
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
