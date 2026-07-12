import 'product.dart';

class CartItem {
  final int id;
  final String name;
  final int price;
  final int quantity;
  final String imageUrl;
  final double rating;
  final int stock;
  final String unit;
  final bool isActive;

  const CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    required this.imageUrl,
    this.rating = 0,
    this.stock = 0,
    this.unit = 'pcs',
    this.isActive = true,
  });

  factory CartItem.fromProduct(
    ProductModel product, {
    int quantity = 1,
  }) {
    return CartItem(
      id: product.id,
      name: product.name,
      price: product.sellingPrice,
      quantity: quantity,
      imageUrl: product.imageUrl ?? '',
      stock: product.stock,
      unit: product.unit,
      isActive: product.isActive,
    );
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: _parseInt(json['id']),
      name: json['name']?.toString() ?? '',
      price: _parseInt(json['price']),
      quantity: _parseInt(json['quantity']),
      imageUrl: json['image_url']?.toString() ?? '',
      rating: _parseDouble(json['rating']),
      stock: _parseInt(json['stock']),
      unit: json['unit']?.toString() ?? 'pcs',
      isActive: _parseBool(
        json['is_active'],
        fallback: true,
      ),
    );
  }

  int get subtotal => price * quantity;

  bool get isOutOfStock => stock <= 0;

  bool get isAvailable => isActive && !isOutOfStock;

  bool get quantityExceedsStock => quantity > stock;

  bool get canIncrease => isAvailable && quantity < stock;

  CartItem copyWith({
    int? id,
    String? name,
    int? price,
    int? quantity,
    String? imageUrl,
    double? rating,
    int? stock,
    String? unit,
    bool? isActive,
  }) {
    return CartItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl ?? this.imageUrl,
      rating: rating ?? this.rating,
      stock: stock ?? this.stock,
      unit: unit ?? this.unit,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'quantity': quantity,
      'image_url': imageUrl,
      'rating': rating,
      'stock': stock,
      'unit': unit,
      'is_active': isActive,
    };
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

  static double _parseDouble(dynamic value) {
    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _parseBool(
    dynamic value, {
    required bool fallback,
  }) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value.toInt() == 1;
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
}
