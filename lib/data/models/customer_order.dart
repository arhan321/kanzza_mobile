import 'user.dart';

class CustomerOrderItemModel {
  final int id;
  final int productId;
  final String productName;
  final String productSku;
  final int price;
  final int quantity;
  final int subtotal;

  const CustomerOrderItemModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productSku,
    required this.price,
    required this.quantity,
    required this.subtotal,
  });

  factory CustomerOrderItemModel.fromJson(Map<String, dynamic> json) {
    return CustomerOrderItemModel(
      id: _parseInt(json['id']),
      productId: _parseInt(json['product_id']),
      productName: json['product_name']?.toString() ?? 'Produk',
      productSku: json['product_sku']?.toString() ?? '',
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

class PaymentModel {
  final int id;
  final int orderId;
  final int attemptNumber;
  final String provider;
  final String? midtransOrderId;
  final String? midtransTransactionId;
  final String? snapToken;
  final String? redirectUrl;
  final String? paymentType;
  final int grossAmount;
  final String status;
  final String? fraudStatus;
  final DateTime? transactionTime;
  final DateTime? settlementTime;
  final DateTime? expiryTime;
  final DateTime? paidAt;
  final DateTime? createdAt;

  const PaymentModel({
    required this.id,
    required this.orderId,
    required this.attemptNumber,
    required this.provider,
    required this.grossAmount,
    required this.status,
    this.midtransOrderId,
    this.midtransTransactionId,
    this.snapToken,
    this.redirectUrl,
    this.paymentType,
    this.fraudStatus,
    this.transactionTime,
    this.settlementTime,
    this.expiryTime,
    this.paidAt,
    this.createdAt,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: _parseInt(json['id']),
      orderId: _parseInt(json['order_id']),
      attemptNumber: _parseInt(json['attempt_number']),
      provider: json['provider']?.toString() ?? 'midtrans',
      midtransOrderId: _parseNullableString(json['midtrans_order_id']),
      midtransTransactionId: _parseNullableString(
        json['midtrans_transaction_id'],
      ),
      snapToken: _parseNullableString(json['snap_token']),
      redirectUrl: _parseNullableString(json['redirect_url']),
      paymentType: _parseNullableString(json['payment_type']),
      grossAmount: _parseInt(json['gross_amount']),
      status: json['status']?.toString().trim().toLowerCase() ?? 'pending',
      fraudStatus: _parseNullableString(json['fraud_status']),
      transactionTime: _parseDateTime(json['transaction_time']),
      settlementTime: _parseDateTime(json['settlement_time']),
      expiryTime: _parseDateTime(json['expiry_time']),
      paidAt: _parseDateTime(json['paid_at']),
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  bool get isPaid => status == 'paid';

  bool get isPending => status == 'pending';

  bool get canOpenPayment {
    return redirectUrl != null && redirectUrl!.trim().isNotEmpty;
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

class CustomerOrderModel {
  final int id;
  final String orderNumber;
  final String channel;
  final String orderStatus;
  final String paymentStatus;
  final String deliveryMethod;
  final String? paymentMethod;
  final UserModel? customer;
  final UserModel? cashier;
  final int subtotal;
  final int shippingCost;
  final int discount;
  final int grandTotal;
  final int paymentAmount;
  final int changeAmount;
  final Map<String, dynamic>? addressSnapshot;
  final String? notes;
  final DateTime? paidAt;
  final List<CustomerOrderItemModel> items;
  final PaymentModel? latestPayment;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CustomerOrderModel({
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
    required this.paymentAmount,
    required this.changeAmount,
    required this.items,
    this.paymentMethod,
    this.customer,
    this.cashier,
    this.addressSnapshot,
    this.notes,
    this.paidAt,
    this.latestPayment,
    this.createdAt,
    this.updatedAt,
  });

  factory CustomerOrderModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final rawPayment = json['latest_payment'];
    final rawAddress = json['address'];
    final rawCustomer = json['customer'];
    final rawCashier = json['cashier'];

    return CustomerOrderModel(
      id: _parseInt(json['id']),
      orderNumber:
          json['order_number']?.toString() ?? 'ORDER-${json['id'] ?? ''}',
      channel: json['channel']?.toString().trim().toLowerCase() ?? 'online',
      orderStatus:
          json['order_status']?.toString().trim().toLowerCase() ??
          'pending_payment',
      paymentStatus:
          json['payment_status']?.toString().trim().toLowerCase() ?? 'unpaid',
      deliveryMethod:
          json['delivery_method']?.toString().trim().toLowerCase() ??
          'delivery',
      paymentMethod: _parseNullableString(json['payment_method']),
      customer: rawCustomer is Map
          ? UserModel.fromJson(Map<String, dynamic>.from(rawCustomer))
          : null,
      cashier: rawCashier is Map
          ? UserModel.fromJson(Map<String, dynamic>.from(rawCashier))
          : null,
      subtotal: _parseInt(json['subtotal']),
      shippingCost: _parseInt(json['shipping_cost']),
      discount: _parseInt(json['discount']),
      grandTotal: _parseInt(json['grand_total']),
      paymentAmount: _parseInt(json['payment_amount']),
      changeAmount: _parseInt(json['change_amount']),
      addressSnapshot: rawAddress is Map
          ? Map<String, dynamic>.from(rawAddress)
          : null,
      notes: _parseNullableString(json['notes']),
      paidAt: _parseDateTime(json['paid_at']),
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (item) => CustomerOrderItemModel.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const <CustomerOrderItemModel>[],
      latestPayment: rawPayment is Map
          ? PaymentModel.fromJson(Map<String, dynamic>.from(rawPayment))
          : null,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  bool get isPaid => paymentStatus == 'paid';

  bool get isPickup => deliveryMethod == 'pickup';

  bool get isCod => paymentMethod?.trim().toLowerCase() == 'cash';

  bool get isMidtrans => !isCod;

  bool get canCustomerPayOnline {
    return isMidtrans &&
        !isPaid &&
        !const {'cancelled', 'delivered'}.contains(orderStatus);
  }

  bool get canCustomerCancel {
    return !isPaid &&
        const {
          'pending_payment',
          'confirmed',
          'processing',
          'ready',
        }.contains(orderStatus);
  }

  int get totalQuantity {
    return items.fold<int>(0, (total, item) => total + item.quantity);
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

class PaymentStatusResult {
  final PaymentModel payment;
  final String? midtransStatus;
  final bool statusChanged;
  final String orderPaymentStatus;
  final String orderStatus;
  final String message;

  const PaymentStatusResult({
    required this.payment,
    required this.statusChanged,
    required this.orderPaymentStatus,
    required this.orderStatus,
    required this.message,
    this.midtransStatus,
  });

  bool get isPaid {
    return payment.isPaid || orderPaymentStatus == 'paid';
  }

  bool get isPending {
    return payment.isPending || orderPaymentStatus == 'unpaid';
  }
}
