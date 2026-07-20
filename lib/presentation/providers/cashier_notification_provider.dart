import 'package:flutter/foundation.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/cashier_notification.dart';
import '../../data/repositories/cashier_notification_repository.dart';

class CashierNotificationProvider extends ChangeNotifier {
  CashierNotificationProvider({CashierNotificationRepository? repository})
    : _repository = repository ?? CashierNotificationRepository();

  final CashierNotificationRepository _repository;
  final List<CashierNotificationModel> _notifications = [];

  int _unreadCount = 0;
  bool _isLoading = false;
  String? _errorMessage;

  List<CashierNotificationModel> get notifications =>
      List.unmodifiable(_notifications);

  int get unreadCount => _unreadCount;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  Future<void> refreshUnreadCount({bool throwOnError = false}) async {
    try {
      _unreadCount = await _repository.getUnreadCount();
      notifyListeners();
    } catch (error) {
      debugPrint('LOAD CASHIER NOTIFICATION COUNT ERROR: $error');
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
        ..addAll(results[0] as List<CashierNotificationModel>);
      _unreadCount = results[1] as int;
    } on ApiException catch (error) {
      _errorMessage = error.firstValidationError;
      rethrow;
    } catch (_) {
      _errorMessage = 'Notifikasi kasir gagal dimuat. Silakan coba kembali.';
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
