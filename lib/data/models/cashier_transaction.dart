class CashierTransactionItemModel {
  final int id;
  final int? productId;
  final String productName;
  final int price;
  final int quantity;
  final int subtotal;

  const CashierTransactionItemModel({
    required this.id,
    required this.productName,
    required this.price,
    required this.quantity,
    required this.subtotal,
    this.productId,
  });

  factory CashierTransactionItemModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return CashierTransactionItemModel(
      id: _parseInt(json['id']),
      productId: _parseNullableInt(json['product_id']),
      productName:
          json['product_name']?.toString() ??
          _extractProductName(json['product']) ??
          'Produk',
      price: _parseInt(json['price']),
      quantity: _parseInt(json['quantity']),
      subtotal: _parseInt(json['subtotal']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'price': price,
      'quantity': quantity,
      'subtotal': subtotal,
    };
  }

  static String? _extractProductName(dynamic product) {
    if (product is Map) {
      final name = product['name']?.toString().trim();

      if (name != null && name.isNotEmpty) {
        return name;
      }
    }

    return null;
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

    return _parseInt(value);
  }
}

class CashierTransactionModel {
  final int id;
  final String orderNumber;
  final String? customerName;
  final String? cashierName;
  final String channel;
  final String orderStatus;
  final String paymentStatus;
  final String deliveryMethod;
  final String paymentMethod;
  final int subtotal;
  final int shippingCost;
  final int discount;
  final int grandTotal;
  final int paymentAmount;
  final int changeAmount;
  final String? notes;
  final DateTime? paidAt;
  final DateTime? createdAt;
  final List<CashierTransactionItemModel> items;

  const CashierTransactionModel({
    required this.id,
    required this.orderNumber,
    required this.channel,
    required this.orderStatus,
    required this.paymentStatus,
    required this.deliveryMethod,
    required this.paymentMethod,
    required this.subtotal,
    required this.shippingCost,
    required this.discount,
    required this.grandTotal,
    required this.paymentAmount,
    required this.changeAmount,
    required this.items,
    this.customerName,
    this.cashierName,
    this.notes,
    this.paidAt,
    this.createdAt,
  });

  factory CashierTransactionModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawItems = json['items'];

    return CashierTransactionModel(
      id: _parseInt(json['id']),
      orderNumber:
          json['order_number']?.toString() ??
          'POS-${json['id'] ?? ''}',
      customerName: _extractUserName(json['customer']),
      cashierName: _extractUserName(json['cashier']),
      channel:
          json['channel']?.toString().trim().toLowerCase() ??
          'cashier',
      orderStatus:
          json['order_status']
              ?.toString()
              .trim()
              .toLowerCase() ??
          'confirmed',
      paymentStatus:
          json['payment_status']
              ?.toString()
              .trim()
              .toLowerCase() ??
          'paid',
      deliveryMethod:
          json['delivery_method']
              ?.toString()
              .trim()
              .toLowerCase() ??
          'pickup',
      paymentMethod:
          json['payment_method']
              ?.toString()
              .trim()
              .toLowerCase() ??
          'cash',
      subtotal: _parseInt(json['subtotal']),
      shippingCost: _parseInt(json['shipping_cost']),
      discount: _parseInt(json['discount']),
      grandTotal: _parseInt(json['grand_total']),
      paymentAmount: _parseInt(json['payment_amount']),
      changeAmount: _parseInt(json['change_amount']),
      notes: _parseNullableString(json['notes']),
      paidAt: _parseDateTime(json['paid_at']),
      createdAt: _parseDateTime(json['created_at']),
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (item) =>
                      CashierTransactionItemModel.fromJson(
                        Map<String, dynamic>.from(item),
                      ),
                )
                .toList()
          : const <CashierTransactionItemModel>[],
    );
  }

  int get totalQuantity {
    return items.fold<int>(
      0,
      (total, item) => total + item.quantity,
    );
  }

  bool get isPaid => paymentStatus == 'paid';

  String get displayCustomerName {
    final name = customerName?.trim();

    if (name == null || name.isEmpty) {
      return 'Pelanggan umum';
    }

    return name;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_number': orderNumber,
      'customer_name': customerName,
      'cashier_name': cashierName,
      'channel': channel,
      'order_status': orderStatus,
      'payment_status': paymentStatus,
      'delivery_method': deliveryMethod,
      'payment_method': paymentMethod,
      'subtotal': subtotal,
      'shipping_cost': shippingCost,
      'discount': discount,
      'grand_total': grandTotal,
      'payment_amount': paymentAmount,
      'change_amount': changeAmount,
      'notes': notes,
      'paid_at': paidAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  static String? _extractUserName(dynamic user) {
    if (user is Map) {
      final name = user['name']?.toString().trim();

      if (name != null && name.isNotEmpty) {
        return name;
      }
    }

    return null;
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

  static String? _parseNullableString(dynamic value) {
    final text = value?.toString().trim();

    if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
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
