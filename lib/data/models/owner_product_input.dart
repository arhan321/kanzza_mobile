class OwnerProductInput {
  final int? categoryId;
  final String sku;
  final String name;
  final String? description;
  final int costPrice;
  final int sellingPrice;
  final int stock;
  final int minimumStock;
  final String unit;
  final bool isActive;
  final String? imagePath;

  const OwnerProductInput({
    required this.categoryId,
    required this.sku,
    required this.name,
    required this.description,
    required this.costPrice,
    required this.sellingPrice,
    required this.stock,
    required this.minimumStock,
    required this.unit,
    required this.isActive,
    this.imagePath,
  });

  Map<String, dynamic> toMultipartFields() {
    return {
      if (categoryId != null) 'category_id': categoryId,
      'sku': sku.trim(),
      'name': name.trim(),
      if (description != null && description!.trim().isNotEmpty)
        'description': description!.trim(),
      'cost_price': costPrice,
      'selling_price': sellingPrice,
      'stock': stock,
      'minimum_stock': minimumStock,
      'unit': unit.trim(),
      'is_active': isActive,
    };
  }
}
