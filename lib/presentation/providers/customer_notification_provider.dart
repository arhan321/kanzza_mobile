import 'package:flutter/foundation.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/customer_notification.dart';
import '../../data/repositories/customer_notification_repository.dart';

class CustomerNotificationProvider extends ChangeNotifier {
  CustomerNotificationProvider({CustomerNotificationRepository? repository})
    : _repository = repository ?? CustomerNotificationRepository();

  final CustomerNotificationRepository _repository;
  final List<CustomerNotificationModel> _notifications = [];

  int _unreadCount = 0;
  bool _isLoading = false;
  String? _errorMessage;

  List<CustomerNotificationModel> get notifications =>
      List.unmodifiable(_notifications);

  int get unreadCount => _unreadCount;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  Future<void> refreshUnreadCount({bool throwOnError = false}) async {
    try {
      final count = await _repository.getUnreadCount();
      _unreadCount = count;
      notifyListeners();
    } catch (error) {
      debugPrint('LOAD UNREAD NOTIFICATION COUNT ERROR: $error');

      if (throwOnError) {
        rethrow;
      }
    }
  }

  Future<void> loadNotifications() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait<dynamic>([
        _repository.getNotifications(),
        _repository.getUnreadCount(),
      ]);

      _notifications
        ..clear()
        ..addAll(results[0] as List<CustomerNotificationModel>);
      _unreadCount = results[1] as int;
    } on ApiException catch (error) {
      _errorMessage = error.firstValidationError;
      rethrow;
    } catch (error) {
      _errorMessage = 'Notifikasi gagal dimuat. Silakan coba kembali.';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(int notificationId) async {
    final index = _notifications.indexWhere(
      (notification) => notification.id == notificationId,
    );

    if (index < 0 || _notifications[index].isRead) {
      return;
    }

    final updated = await _repository.markAsRead(notificationId);
    _notifications[index] = updated;
    _unreadCount = (_unreadCount - 1).clamp(0, 999999).toInt();
    notifyListeners();
  }

  Future<void> markAllAsRead() async {
    if (_unreadCount == 0) {
      return;
    }

    await _repository.markAllAsRead();
    final readAt = DateTime.now();

    for (var index = 0; index < _notifications.length; index++) {
      final notification = _notifications[index];

      if (!notification.isRead) {
        _notifications[index] = notification.copyWith(
          isRead: true,
          readAt: readAt,
        );
      }
    }

    _unreadCount = 0;
    notifyListeners();
  }

  void clear() {
    _notifications.clear();
    _unreadCount = 0;
    _errorMessage = null;
    notifyListeners();
  }
}
