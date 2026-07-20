class OwnerTrendPointModel {
  const OwnerTrendPointModel({required this.label, required this.value});

  final String label;
  final int value;

  factory OwnerTrendPointModel.fromJson(Map<String, dynamic> json) {
    return OwnerTrendPointModel(
      label: json['label']?.toString() ?? '-',
      value: _int(json['value']),
    );
  }
}

class OwnerCategorySalesModel {
  const OwnerCategorySalesModel({
    required this.name,
    required this.totalQuantity,
    required this.totalSales,
  });

  final String name;
  final int totalQuantity;
  final int totalSales;

  factory OwnerCategorySalesModel.fromJson(Map<String, dynamic> json) {
    return OwnerCategorySalesModel(
      name: json['name']?.toString() ?? 'Tanpa Kategori',
      totalQuantity: _int(json['total_quantity']),
      totalSales: _int(json['total_sales']),
    );
  }
}

class OwnerTopProductModel {
  const OwnerTopProductModel({
    required this.productId,
    required this.name,
    required this.totalQuantity,
    required this.totalSales,
  });

  final int? productId;
  final String name;
  final int totalQuantity;
  final int totalSales;

  factory OwnerTopProductModel.fromJson(Map<String, dynamic> json) {
    return OwnerTopProductModel(
      productId: _nullableInt(json['product_id']),
      name: json['product_name']?.toString().trim() ?? 'Produk',
      totalQuantity: _int(json['total_quantity']),
      totalSales: _int(json['total_sales']),
    );
  }
}

class OwnerLowStockProductModel {
  const OwnerLowStockProductModel({
    required this.id,
    required this.name,
    required this.stock,
    required this.minimumStock,
    required this.unit,
  });

  final int id;
  final String name;
  final int stock;
  final int minimumStock;
  final String unit;

  factory OwnerLowStockProductModel.fromJson(Map<String, dynamic> json) {
    return OwnerLowStockProductModel(
      id: _int(json['id']),
      name: json['name']?.toString() ?? 'Produk',
      stock: _int(json['stock']),
      minimumStock: _int(json['minimum_stock']),
      unit: json['unit']?.toString() ?? 'unit',
    );
  }
}

class OwnerRecentOrderModel {
  const OwnerRecentOrderModel({
    required this.id,
    required this.orderNumber,
    required this.name,
    required this.channel,
    required this.orderStatus,
    required this.paymentStatus,
    required this.grandTotal,
    required this.createdAt,
  });

  final int id;
  final String orderNumber;
  final String name;
  final String channel;
  final String orderStatus;
  final String paymentStatus;
  final int grandTotal;
  final DateTime? createdAt;

  factory OwnerRecentOrderModel.fromJson(Map<String, dynamic> json) {
    return OwnerRecentOrderModel(
      id: _int(json['id']),
      orderNumber: json['order_number']?.toString() ?? '-',
      name: json['name']?.toString() ?? 'Pelanggan',
      channel: json['channel']?.toString() ?? 'online',
      orderStatus: json['order_status']?.toString() ?? 'pending_payment',
      paymentStatus: json['payment_status']?.toString() ?? 'unpaid',
      grandTotal: _int(json['grand_total']),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}

class OwnerDashboardModel {
  const OwnerDashboardModel({
    required this.periodKey,
    required this.periodStart,
    required this.periodEnd,
    required this.revenue,
    required this.transactions,
    required this.averageOrder,
    required this.revenueGrowthPercent,
    required this.itemsSold,
    required this.customerRetentionPercent,
    required this.activeCustomers,
    required this.repeatCustomers,
    required this.newCustomers,
    required this.stockTurnover,
    required this.totalProducts,
    required this.pendingOrders,
    required this.lowStockProducts,
    required this.salesTrend,
    required this.categorySales,
    required this.topProducts,
    required this.recentOrders,
  });

  final String periodKey;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final int revenue;
  final int transactions;
  final int averageOrder;
  final double revenueGrowthPercent;
  final int itemsSold;
  final double customerRetentionPercent;
  final int activeCustomers;
  final int repeatCustomers;
  final int newCustomers;
  final double stockTurnover;
  final int totalProducts;
  final int pendingOrders;
  final List<OwnerLowStockProductModel> lowStockProducts;
  final List<OwnerTrendPointModel> salesTrend;
  final List<OwnerCategorySalesModel> categorySales;
  final List<OwnerTopProductModel> topProducts;
  final List<OwnerRecentOrderModel> recentOrders;

  int get attentionCount => pendingOrders + lowStockProducts.length;

  factory OwnerDashboardModel.fromJson(Map<String, dynamic> json) {
    final period = _map(json['period']);
    return OwnerDashboardModel(
      periodKey: period['key']?.toString() ?? 'today',
      periodStart: DateTime.tryParse(period['start']?.toString() ?? ''),
      periodEnd: DateTime.tryParse(period['end']?.toString() ?? ''),
      revenue: _int(json['revenue']),
      transactions: _int(json['transactions']),
      averageOrder: _int(json['average_order']),
      revenueGrowthPercent: _double(json['revenue_growth_percent']),
      itemsSold: _int(json['items_sold']),
      customerRetentionPercent: _double(json['customer_retention_percent']),
      activeCustomers: _int(json['active_customers']),
      repeatCustomers: _int(json['repeat_customers']),
      newCustomers: _int(json['new_customers']),
      stockTurnover: _double(json['stock_turnover']),
      totalProducts: _int(json['total_products']),
      pendingOrders: _int(json['pending_orders']),
      lowStockProducts: _list(json['low_stock_products'], OwnerLowStockProductModel.fromJson),
      salesTrend: _list(json['sales_trend'], OwnerTrendPointModel.fromJson),
      categorySales: _list(json['category_sales'], OwnerCategorySalesModel.fromJson),
      topProducts: _list(json['top_products'], OwnerTopProductModel.fromJson),
      recentOrders: _list(json['recent_orders'], OwnerRecentOrderModel.fromJson),
    );
  }
}

Map<String, dynamic> _map(dynamic value) => value is Map
    ? Map<String, dynamic>.from(value)
    : <String, dynamic>{};

List<T> _list<T>(dynamic value, T Function(Map<String, dynamic>) parse) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => parse(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}

int _int(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _double(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int? _nullableInt(dynamic value) {
  if (value == null) return null;
  return _int(value);
}
