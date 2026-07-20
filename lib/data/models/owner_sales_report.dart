class OwnerSalesSummaryModel {
  const OwnerSalesSummaryModel({
    required this.totalTransactions,
    required this.totalRevenue,
    required this.totalItems,
    required this.averageOrder,
  });

  final int totalTransactions;
  final int totalRevenue;
  final int totalItems;
  final int averageOrder;

  factory OwnerSalesSummaryModel.fromJson(Map<String, dynamic> json) {
    return OwnerSalesSummaryModel(
      totalTransactions: _int(json['total_transactions']),
      totalRevenue: _int(json['total_revenue']),
      totalItems: _int(json['total_items']),
      averageOrder: _int(json['average_order']),
    );
  }
}

class OwnerSalesTransactionModel {
  const OwnerSalesTransactionModel({
    required this.id,
    required this.orderNumber,
    required this.channel,
    required this.orderStatus,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.customerName,
    required this.totalQuantity,
    required this.grandTotal,
    required this.paidAt,
  });

  final int id;
  final String orderNumber;
  final String channel;
  final String orderStatus;
  final String paymentStatus;
  final String paymentMethod;
  final String customerName;
  final int totalQuantity;
  final int grandTotal;
  final DateTime? paidAt;

  bool get isOnline => channel == 'online';

  factory OwnerSalesTransactionModel.fromJson(Map<String, dynamic> json) {
    return OwnerSalesTransactionModel(
      id: _int(json['id']),
      orderNumber: json['order_number']?.toString() ?? '-',
      channel: json['channel']?.toString() ?? 'online',
      orderStatus: json['order_status']?.toString() ?? '-',
      paymentStatus: json['payment_status']?.toString() ?? '-',
      paymentMethod: json['payment_method']?.toString() ?? '-',
      customerName: json['customer_name']?.toString() ?? 'Pelanggan',
      totalQuantity: _int(json['total_quantity']),
      grandTotal: _int(json['grand_total']),
      paidAt: DateTime.tryParse(json['paid_at']?.toString() ?? ''),
    );
  }
}

class OwnerSalesReportModel {
  const OwnerSalesReportModel({
    required this.summary,
    required this.transactions,
  });

  final OwnerSalesSummaryModel summary;
  final List<OwnerSalesTransactionModel> transactions;

  factory OwnerSalesReportModel.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'];
    final rawTransactions = json['transactions'];
    return OwnerSalesReportModel(
      summary: OwnerSalesSummaryModel.fromJson(
        summary is Map ? Map<String, dynamic>.from(summary) : const {},
      ),
      transactions: rawTransactions is List
          ? rawTransactions
              .whereType<Map>()
              .map((item) => OwnerSalesTransactionModel.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .toList(growable: false)
          : const [],
    );
  }
}

int _int(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
