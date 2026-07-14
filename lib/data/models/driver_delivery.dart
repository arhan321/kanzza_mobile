import 'user.dart';

class DriverDeliveryItemModel {
  final int id;
  final int productId;
  final String productName;
  final String productSku;
  final int price;
  final int quantity;
  final int subtotal;

  const DriverDeliveryItemModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productSku,
    required this.price,
    required this.quantity,
    required this.subtotal,
  });

  factory DriverDeliveryItemModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return DriverDeliveryItemModel(
      id: _parseInt(json['id']),
      productId: _parseInt(json['product_id']),
      productName:
          json['product_name']?.toString() ?? 'Produk',
      productSku:
          json['product_sku']?.toString() ?? '',
      price: _parseInt(json['price']),
      quantity: _parseInt(json['quantity']),
      subtotal: _parseInt(json['subtotal']),
    );
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

class DriverDeliveryOrderModel {
  final int id;
  final String orderNumber;
  final UserModel? customer;
  final String channel;
  final String orderStatus;
  final String paymentStatus;
  final String deliveryMethod;
  final String? paymentMethod;
  final int subtotal;
  final int shippingCost;
  final int discount;
  final int grandTotal;
  final Map<String, dynamic>? address;
  final String? notes;
  final List<DriverDeliveryItemModel> items;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DriverDeliveryOrderModel({
    required this.id,
    required this.orderNumber,
    required this.channel,
    required this.orderStatus,
    required this.paymentStatus,
    required this.deliveryMethod,
    required this.subtotal,
    required this.shippingCost,
    required this.discount,
    required this.grandTotal,
    required this.items,
    this.customer,
    this.paymentMethod,
    this.address,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory DriverDeliveryOrderModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawCustomer = json['customer'];
    final rawAddress = json['address'];
    final rawItems = json['items'];

    return DriverDeliveryOrderModel(
      id: _parseInt(json['id']),
      orderNumber:
          json['order_number']?.toString() ??
          'ORDER-${json['id'] ?? ''}',
      customer: rawCustomer is Map
          ? UserModel.fromJson(
              Map<String, dynamic>.from(rawCustomer),
            )
          : null,
      channel:
          json['channel']?.toString().trim().toLowerCase() ??
          'online',
      orderStatus: json['order_status']
              ?.toString()
              .trim()
              .toLowerCase() ??
          'assigned',
      paymentStatus: json['payment_status']
              ?.toString()
              .trim()
              .toLowerCase() ??
          'paid',
      deliveryMethod: json['delivery_method']
              ?.toString()
              .trim()
              .toLowerCase() ??
          'delivery',
      paymentMethod:
          _nullableString(json['payment_method']),
      subtotal: _parseInt(json['subtotal']),
      shippingCost: _parseInt(json['shipping_cost']),
      discount: _parseInt(json['discount']),
      grandTotal: _parseInt(json['grand_total']),
      address: rawAddress is Map
          ? Map<String, dynamic>.from(rawAddress)
          : null,
      notes: _nullableString(json['notes']),
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map(
                (item) => DriverDeliveryItemModel.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
          : const <DriverDeliveryItemModel>[],
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  int get totalQuantity {
    return items.fold<int>(
      0,
      (total, item) => total + item.quantity,
    );
  }

  String get customerName {
    final name = customer?.name.trim();

    if (name != null && name.isNotEmpty) {
      return name;
    }

    final recipient =
        address?['recipient_name']?.toString().trim();

    if (recipient != null && recipient.isNotEmpty) {
      return recipient;
    }

    return 'Customer';
  }

  String get customerPhone {
    final addressPhone =
        address?['phone']?.toString().trim();

    if (addressPhone != null &&
        addressPhone.isNotEmpty) {
      return addressPhone;
    }

    final userPhone = customer?.phone?.trim();

    if (userPhone != null && userPhone.isNotEmpty) {
      return userPhone;
    }

    return '-';
  }

  String get fullAddress {
    final value =
        address?['full_address']?.toString().trim();

    if (value != null && value.isNotEmpty) {
      return value;
    }

    return 'Alamat tidak tersedia';
  }

  String get locationSummary {
    final values = <String?>[
      address?['district']?.toString(),
      address?['city']?.toString(),
      address?['province']?.toString(),
      address?['postal_code']?.toString(),
    ];

    return values
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .join(', ');
  }

  double? get latitude {
    return _parseNullableDouble(address?['latitude']);
  }

  double? get longitude {
    return _parseNullableDouble(address?['longitude']);
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

  static double? _parseNullableDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
  }

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim();

    if (text == null ||
        text.isEmpty ||
        text.toLowerCase() == 'null') {
      return null;
    }

    return text;
  }

  static DateTime? _parseDateTime(dynamic value) {
    final text = value?.toString().trim();

    if (text == null || text.isEmpty) {
      return null;
    }

    return DateTime.tryParse(text);
  }
}

class DriverDeliveryModel {
  final int id;
  final int orderId;
  final UserModel? driver;
  final String status;
  final DateTime? assignedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final bool codPaymentReceived;
  final DateTime? codPaymentReceivedAt;
  final UserModel? codPaymentReceivedBy;
  final String? proofImage;
  final String? notes;
  final DriverDeliveryOrderModel? order;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DriverDeliveryModel({
    required this.id,
    required this.orderId,
    required this.status,
    this.driver,
    this.assignedAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.codPaymentReceived = false,
    this.codPaymentReceivedAt,
    this.codPaymentReceivedBy,
    this.proofImage,
    this.notes,
    this.order,
    this.createdAt,
    this.updatedAt,
  });

  factory DriverDeliveryModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawDriver = json['driver'];
    final rawCodPaymentReceiver =
        json['cod_payment_received_by'];
    final rawOrder = json['order'];

    return DriverDeliveryModel(
      id: _parseInt(json['id']),
      orderId: _parseInt(json['order_id']),
      driver: rawDriver is Map
          ? UserModel.fromJson(
              Map<String, dynamic>.from(rawDriver),
            )
          : null,
      status:
          json['status']?.toString().trim().toLowerCase() ??
          'assigned',
      assignedAt: _parseDateTime(json['assigned_at']),
      pickedUpAt: _parseDateTime(json['picked_up_at']),
      deliveredAt: _parseDateTime(json['delivered_at']),
      codPaymentReceived:
          json['cod_payment_received'] == true,
      codPaymentReceivedAt:
          _parseDateTime(json['cod_payment_received_at']),
      codPaymentReceivedBy: rawCodPaymentReceiver is Map
          ? UserModel.fromJson(
              Map<String, dynamic>.from(rawCodPaymentReceiver),
            )
          : null,
      proofImage: _nullableString(json['proof_image']),
      notes: _nullableString(json['notes']),
      order: rawOrder is Map
          ? DriverDeliveryOrderModel.fromJson(
              Map<String, dynamic>.from(rawOrder),
            )
          : null,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  bool get isAssigned => status == 'assigned';

  bool get isPickedUp => status == 'picked_up';

  bool get isOnDelivery => status == 'on_delivery';

  bool get isDelivered => status == 'delivered';

  bool get isActive => !isDelivered;

  String? get nextStatus {
    switch (status) {
      case 'assigned':
        return 'picked_up';
      case 'picked_up':
        return 'on_delivery';
      case 'on_delivery':
        return 'delivered';
      default:
        return null;
    }
  }

  String get orderNumber {
    return order?.orderNumber ?? 'ORDER-$orderId';
  }

  DateTime get sortDate {
    return assignedAt ??
        createdAt ??
        updatedAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
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

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim();

    if (text == null ||
        text.isEmpty ||
        text.toLowerCase() == 'null') {
      return null;
    }

    return text;
  }

  static DateTime? _parseDateTime(dynamic value) {
    final text = value?.toString().trim();

    if (text == null || text.isEmpty) {
      return null;
    }

    return DateTime.tryParse(text);
  }
}
