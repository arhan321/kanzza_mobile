class CashierNotificationModel {
  final int id;
  final String event;
  final String title;
  final String message;
  final int? orderId;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime? readAt;
  final DateTime? createdAt;

  const CashierNotificationModel({
    required this.id,
    required this.event,
    required this.title,
    required this.message,
    required this.data,
    required this.isRead,
    this.orderId,
    this.readAt,
    this.createdAt,
  });

  factory CashierNotificationModel.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final readAt = _parseDateTime(json['read_at']);

    return CashierNotificationModel(
      id: _parseInt(json['id']),
      event: json['event']?.toString().trim().toLowerCase() ?? 'general',
      title: json['title']?.toString().trim() ?? 'Notifikasi Kasir',
      message: json['message']?.toString().trim() ?? '',
      orderId: _parseNullableInt(json['order_id']),
      data: rawData is Map
          ? Map<String, dynamic>.from(rawData)
          : const <String, dynamic>{},
      isRead: _parseBool(json['is_read']) || readAt != null,
      readAt: readAt,
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  CashierNotificationModel copyWith({
    bool? isRead,
    DateTime? readAt,
  }) {
    return CashierNotificationModel(
      id: id,
      event: event,
      title: title,
      message: message,
      orderId: orderId,
      data: data,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
    );
  }

  bool get isNewOrder => event == 'cashier_order_created';

  bool get isPaymentConfirmed => event == 'cashier_payment_confirmed';

  String? get orderNumber {
    final value = data['order_number']?.toString().trim();
    return value == null || value.isEmpty ? null : value;
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

  static int? _parseNullableInt(dynamic value) {
    if (value == null) {
      return null;
    }
    final parsed = _parseInt(value);
    return parsed > 0 ? parsed : null;
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    return const {'1', 'true', 'yes'}.contains(
      value?.toString().trim().toLowerCase(),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    return DateTime.tryParse(text);
  }
}
