import 'package:flutter/foundation.dart';

import '../../data/models/cart_item.dart';
import '../../data/models/product.dart';
import '../../data/repositories/cart_repository.dart';

class CartActionResult {
  final bool success;
  final String message;

  const CartActionResult({required this.success, required this.message});

  const CartActionResult.success(String message)
    : success = true,
      message = message;

  const CartActionResult.failure(String message)
    : success = false,
      message = message;
}

class CustomerCartProvider extends ChangeNotifier {
  CustomerCartProvider({CartRepository? repository})
    : _repository = repository ?? CartRepository();

  final CartRepository _repository;
  final List<CartItem> _items = [];

  bool _isLoading = false;
  bool _isInitialized = false;
  String? _loadedStorageKey;

  List<CartItem> get items => List.unmodifiable(_items);

  bool get isLoading => _isLoading;

  bool get isInitialized => _isInitialized;

  bool get isEmpty => _items.isEmpty;

  int get totalItems {
    return _items.fold<int>(0, (total, item) => total + item.quantity);
  }

  int get totalPrice {
    return _items.fold<int>(0, (total, item) => total + item.subtotal);
  }

  bool get hasInvalidItems {
    return _items.any((item) => !item.isAvailable || item.quantityExceedsStock);
  }

  Future<void> initialize({bool force = false}) async {
    if (_isLoading) {
      return;
    }

    final storageKey = await _repository.currentStorageKey();

    if (!force && _isInitialized && storageKey == _loadedStorageKey) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final storedItems = await _repository.loadItems();

      _items
        ..clear()
        ..addAll(storedItems);

      _loadedStorageKey = storageKey;
      _isInitialized = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<CartActionResult> addProduct(ProductModel product) async {
    if (!product.isActive) {
      return const CartActionResult.failure('Produk sedang tidak aktif.');
    }

    if (product.stock <= 0) {
      return const CartActionResult.failure('Stok produk sedang habis.');
    }

    final index = _items.indexWhere((item) => item.id == product.id);

    if (index >= 0) {
      final currentItem = _items[index];

      if (currentItem.quantity >= product.stock) {
        return CartActionResult.failure(
          'Jumlah produk sudah mencapai stok '
          '${product.stock} ${product.unit}.',
        );
      }

      _items[index] = currentItem.copyWith(
        name: product.name,
        price: product.sellingPrice,
        quantity: currentItem.quantity + 1,
        imageUrl: product.imageUrl ?? '',
        stock: product.stock,
        unit: product.unit,
        isActive: product.isActive,
      );
    } else {
      _items.add(CartItem.fromProduct(product));
    }

    await _persist();
    notifyListeners();

    return CartActionResult.success(
      '${product.name} ditambahkan ke keranjang.',
    );
  }

  Future<CartActionResult> addItem(CartItem item) async {
    if (!item.isAvailable) {
      return const CartActionResult.failure('Produk sedang tidak tersedia.');
    }

    final index = _items.indexWhere((currentItem) => currentItem.id == item.id);

    if (index >= 0) {
      final currentItem = _items[index];
      final nextQuantity = currentItem.quantity + item.quantity;

      if (nextQuantity > item.stock) {
        return CartActionResult.failure(
          'Jumlah produk melebihi stok yang tersedia.',
        );
      }

      _items[index] = item.copyWith(quantity: nextQuantity);
    } else {
      if (item.quantity > item.stock) {
        return const CartActionResult.failure(
          'Jumlah produk melebihi stok yang tersedia.',
        );
      }

      _items.add(item);
    }

    await _persist();
    notifyListeners();

    return CartActionResult.success('${item.name} ditambahkan ke keranjang.');
  }

  Future<CartActionResult> updateQuantity({
    required int productId,
    required int quantity,
  }) async {
    final index = _items.indexWhere((item) => item.id == productId);

    if (index < 0) {
      return const CartActionResult.failure(
        'Produk tidak ditemukan di keranjang.',
      );
    }

    if (quantity <= 0) {
      final removedItem = _items.removeAt(index);
      await _persist();
      notifyListeners();

      return CartActionResult.success(
        '${removedItem.name} dihapus dari keranjang.',
      );
    }

    final currentItem = _items[index];

    if (!currentItem.isAvailable) {
      return const CartActionResult.failure('Produk sedang tidak tersedia.');
    }

    if (quantity > currentItem.stock) {
      return CartActionResult.failure(
        'Jumlah maksimal ${currentItem.stock} '
        '${currentItem.unit}.',
      );
    }

    _items[index] = currentItem.copyWith(quantity: quantity);

    await _persist();
    notifyListeners();

    return const CartActionResult.success('Jumlah produk diperbarui.');
  }

  Future<void> removeItem(int productId) async {
    _items.removeWhere((item) => item.id == productId);

    await _persist();
    notifyListeners();
  }

  Future<void> clear() async {
    _items.clear();
    await _repository.clear();
    notifyListeners();
  }

  Future<void> synchronizeProducts(List<ProductModel> products) async {
    final productMap = <int, ProductModel>{
      for (final product in products) product.id: product,
    };

    bool changed = false;

    for (int index = 0; index < _items.length; index++) {
      final currentItem = _items[index];
      final product = productMap[currentItem.id];

      if (product == null) {
        final updatedItem = currentItem.copyWith(stock: 0, isActive: false);

        if (_different(currentItem, updatedItem)) {
          _items[index] = updatedItem;
          changed = true;
        }

        continue;
      }

      int nextQuantity = currentItem.quantity;

      if (product.stock > 0 && nextQuantity > product.stock) {
        nextQuantity = product.stock;
      }

      final updatedItem = currentItem.copyWith(
        name: product.name,
        price: product.sellingPrice,
        quantity: nextQuantity,
        imageUrl: product.imageUrl ?? '',
        stock: product.stock,
        unit: product.unit,
        isActive: product.isActive,
      );

      if (_different(currentItem, updatedItem)) {
        _items[index] = updatedItem;
        changed = true;
      }
    }

    if (changed) {
      await _persist();
      notifyListeners();
    }
  }

  List<CartItem> checkoutSnapshot() {
    return _items.map((item) => item.copyWith()).toList();
  }

  Future<void> _persist() {
    return _repository.saveItems(_items);
  }

  bool _different(CartItem first, CartItem second) {
    return first.id != second.id ||
        first.name != second.name ||
        first.price != second.price ||
        first.quantity != second.quantity ||
        first.imageUrl != second.imageUrl ||
        first.stock != second.stock ||
        first.unit != second.unit ||
        first.isActive != second.isActive;
  }
}
