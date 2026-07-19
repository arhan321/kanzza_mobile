import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_response.dart';

class CustomerNotificationRemoteDataSource {
  CustomerNotificationRemoteDataSource({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<ApiResponse> getNotifications({int perPage = 100}) {
    return _apiClient.get(
      ApiEndpoints.notifications,
      queryParameters: {'per_page': perPage},
    );
  }

  Future<ApiResponse> getUnreadCount() {
    return _apiClient.get(ApiEndpoints.notificationUnreadCount);
  }

  Future<ApiResponse> markAsRead(int notificationId) {
    return _apiClient.patch(
      ApiEndpoints.markNotificationAsRead(notificationId),
    );
  }

  Future<ApiResponse> markAllAsRead() {
    return _apiClient.post(ApiEndpoints.markAllNotificationsAsRead);
  }
}
