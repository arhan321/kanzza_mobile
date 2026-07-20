import '../../core/network/api_exception.dart';
import '../datasources/cashier_notification_remote_datasource.dart';
import '../models/cashier_notification.dart';

class CashierNotificationRepository {
  CashierNotificationRepository({
    CashierNotificationRemoteDataSource? remoteDataSource,
  }) : _remoteDataSource =
           remoteDataSource ?? CashierNotificationRemoteDataSource();

  final CashierNotificationRemoteDataSource _remoteDataSource;

  Future<List<CashierNotificationModel>> getNotifications({
    int perPage = 100,
  }) async {
    final response = await _remoteDataSource.getNotifications(perPage: perPage);

    try {
      return response.dataAsList
          .whereType<Map>()
          .map(
            (item) => CashierNotificationModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    } catch (error) {
      throw ApiException(
        message: 'Daftar notifikasi kasir tidak dapat dibaca: $error',
      );
    }
  }

  Future<int> getUnreadCount() async {
    final response = await _remoteDataSource.getUnreadCount();
    final data = response.dataAsMap;

    if (data == null) {
      throw const ApiException(
        message: 'Jumlah notifikasi kasir dari server tidak lengkap.',
      );
    }

    return _parseInt(data['unread_count']);
  }

  Future<CashierNotificationModel> markAsRead(int notificationId) async {
    final response = await _remoteDataSource.markAsRead(notificationId);
    final data = response.dataAsMap;

    if (data == null) {
      throw const ApiException(
        message: 'Data notifikasi kasir yang diperbarui tidak lengkap.',
      );
    }

    try {
      return CashierNotificationModel.fromJson(data);
    } catch (error) {
      throw ApiException(
        message: 'Notifikasi kasir yang diperbarui tidak dapat dibaca: $error',
      );
    }
  }

  Future<int> markAllAsRead() async {
    final response = await _remoteDataSource.markAllAsRead();
    return _parseInt(response.dataAsMap?['updated_count']);
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
