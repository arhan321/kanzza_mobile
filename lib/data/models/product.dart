import 'category.dart';

class ProductModel {
  final int id;
  final int categoryId;
  final CategoryModel? category;
  final String sku;
  final String name;
  final String slug;
  final String? description;
  final int? costPrice;
  final int sellingPrice;
  final int stock;
  final int minimumStock;
  final bool isLowStock;
  final String unit;
  final String? imageUrl;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProductModel({
    required this.id,
    required this.categoryId,
    required this.sku,
    required this.name,
    required this.slug,
    required this.sellingPrice,
    required this.stock,
    required this.minimumStock,
    required this.isLowStock,
    required this.unit,
    required this.isActive,
    this.category,
    this.description,
    this.costPrice,
    this.imageUrl,
    this.createdAt,
    this.updatedAt,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final rawCategory = json['category'];

    return ProductModel(
      id: _parseInt(json['id']),
      categoryId: _parseInt(json['category_id']),
      category: rawCategory is Map
          ? CategoryModel.fromJson(
              Map<String, dynamic>.from(rawCategory),
            )
          : null,
      sku: json['sku']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      description: _parseNullableString(json['description']),
      costPrice: _parseNullableInt(json['cost_price']),
      sellingPrice: _parseInt(json['selling_price']),
      stock: _parseInt(json['stock']),
      minimumStock: _parseInt(json['minimum_stock']),
      isLowStock: _parseBool(
        json['is_low_stock'],
        fallback: _parseInt(json['stock']) <=
            _parseInt(json['minimum_stock']),
      ),
      unit: json['unit']?.toString() ?? 'pcs',
      imageUrl: _parseNullableString(json['image_url']),
      isActive: _parseBool(
        json['is_active'],
        fallback: true,
      ),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category_id': categoryId,
      'category': category?.toJson(),
      'sku': sku,
      'name': name,
      'slug': slug,
      'description': description,
      'cost_price': costPrice,
      'selling_price': sellingPrice,
      'stock': stock,
      'minimum_stock': minimumStock,
      'is_low_stock': isLowStock,
      'unit': unit,
      'image_url': imageUrl,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  bool get isOutOfStock => stock <= 0;

  bool get canBeSold => isActive && !isOutOfStock;

  String get categoryName {
    final value = category?.name.trim();

    if (value == null || value.isEmpty) {
      return 'Tanpa Kategori';
    }

    return value;
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

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString());
  }

  static bool _parseBool(
    dynamic value, {
    required bool fallback,
  }) {
    if (value is bool) {
      return value;
    }

    if (value is int) {
      return value == 1;
    }

    final text = value?.toString().trim().toLowerCase();

    if (text == 'true' || text == '1') {
      return true;
    }

    if (text == 'false' || text == '0') {
      return false;
    }

    return fallback;
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

  @override
  String toString() {
    return 'ProductModel('
        'id: $id, '
        'sku: $sku, '
        'name: $name, '
        'sellingPrice: $sellingPrice, '
        'stock: $stock'
        ')';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ProductModel &&
            runtimeType == other.runtimeType &&
            id == other.id;
  }

  @override
  int get hashCode => id.hashCode;
}
