class OwnerTopProductModel {
  final int? productId;
  final String name;
  final int totalQuantity;
  final int totalSales;

  const OwnerTopProductModel({
    required this.productId,
    required this.name,
    required this.totalQuantity,
    required this.totalSales,
  });

  factory OwnerTopProductModel.fromJson(Map<String, dynamic> json) {
    return OwnerTopProductModel(
      productId: _nullableInt(json['product_id']),
      name: json['product_name']?.toString().trim() ?? 'Produk',
      totalQuantity: _int(json['total_quantity']),
      totalSales: _int(json['total_sales']),
    );
  }
}

class OwnerDashboardModel {
  final int todayRevenue;
  final int todayTransactions;
  final int pendingOrders;
  final int lowStockProducts;
  final int activeCustomers;
  final List<OwnerTopProductModel> topProducts;

  const OwnerDashboardModel({
    required this.todayRevenue,
    required this.todayTransactions,
    required this.pendingOrders,
    required this.lowStockProducts,
    required this.activeCustomers,
    required this.topProducts,
  });

  factory OwnerDashboardModel.fromJson(Map<String, dynamic> json) {
    final rawTopProducts = json['top_products'];

    return OwnerDashboardModel(
      todayRevenue: _int(json['today_revenue']),
      todayTransactions: _int(json['today_transactions']),
      pendingOrders: _int(json['pending_orders']),
      lowStockProducts: _int(json['low_stock_products']),
      activeCustomers: _int(json['active_customers']),
      topProducts: rawTopProducts is List
          ? rawTopProducts
                .whereType<Map>()
                .map(
                  (item) => OwnerTopProductModel.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const <OwnerTopProductModel>[],
    );
  }
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _nullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}
