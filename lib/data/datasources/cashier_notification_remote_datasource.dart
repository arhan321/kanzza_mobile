import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_response.dart';

class CashierNotificationRemoteDataSource {
  CashierNotificationRemoteDataSource({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<ApiResponse> getNotifications({int perPage = 100}) {
    return _apiClient.get(
      ApiEndpoints.cashierNotifications,
      queryParameters: {'per_page': perPage},
    );
  }

  Future<ApiResponse> getUnreadCount() {
    return _apiClient.get(ApiEndpoints.cashierNotificationUnreadCount);
  }

  Future<ApiResponse> markAsRead(int notificationId) {
    return _apiClient.patch(
      ApiEndpoints.markCashierNotificationAsRead(notificationId),
    );
  }

  Future<ApiResponse> markAllAsRead() {
    return _apiClient.post(ApiEndpoints.markAllCashierNotificationsAsRead);
  }
}
