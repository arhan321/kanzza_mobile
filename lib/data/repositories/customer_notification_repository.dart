import '../../core/network/api_exception.dart';
import '../datasources/customer_notification_remote_datasource.dart';
import '../models/customer_notification.dart';

class CustomerNotificationRepository {
  CustomerNotificationRepository({
    CustomerNotificationRemoteDataSource? remoteDataSource,
  }) : _remoteDataSource =
           remoteDataSource ?? CustomerNotificationRemoteDataSource();

  final CustomerNotificationRemoteDataSource _remoteDataSource;

  Future<List<CustomerNotificationModel>> getNotifications({
    int perPage = 100,
  }) async {
    final response = await _remoteDataSource.getNotifications(perPage: perPage);

    try {
      return response.dataAsList
          .whereType<Map>()
          .map(
            (item) => CustomerNotificationModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    } catch (error) {
      throw ApiException(
        message: 'Daftar notifikasi dari server tidak dapat dibaca: $error',
      );
    }
  }

  Future<int> getUnreadCount() async {
    final response = await _remoteDataSource.getUnreadCount();
    final data = response.dataAsMap;

    if (data == null) {
      throw const ApiException(
        message: 'Jumlah notifikasi dari server tidak lengkap.',
      );
    }

    return _parseInt(data['unread_count']);
  }

  Future<CustomerNotificationModel> markAsRead(int notificationId) async {
    final response = await _remoteDataSource.markAsRead(notificationId);
    final data = response.dataAsMap;

    if (data == null) {
      throw const ApiException(
        message: 'Data notifikasi yang diperbarui tidak lengkap.',
      );
    }

    try {
      return CustomerNotificationModel.fromJson(data);
    } catch (error) {
      throw ApiException(
        message: 'Notifikasi yang diperbarui tidak dapat dibaca: $error',
      );
    }
  }

  Future<int> markAllAsRead() async {
    final response = await _remoteDataSource.markAllAsRead();
    final data = response.dataAsMap;

    return _parseInt(data?['updated_count']);
  }

  static int _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
