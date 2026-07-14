import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/storage/auth_storage.dart';
import '../models/cart_item.dart';

class CartRepository {
  CartRepository({
    FlutterSecureStorage? secureStorage,
    AuthStorage? authStorage,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _authStorage = authStorage ?? AuthStorage.instance;

  static const String _storagePrefix = 'kanzza_customer_cart';

  final FlutterSecureStorage _secureStorage;
  final AuthStorage _authStorage;

  Future<String> currentStorageKey() async {
    final user = await _authStorage.getUser();
    final userId = user?['id']?.toString().trim();

    if (userId == null || userId.isEmpty) {
      return '${_storagePrefix}_guest';
    }

    return '${_storagePrefix}_$userId';
  }

  Future<List<CartItem>> loadItems() async {
    final key = await currentStorageKey();
    final rawCart = await _secureStorage.read(key: key);

    if (rawCart == null || rawCart.trim().isEmpty) {
      return <CartItem>[];
    }

    try {
      final decoded = jsonDecode(rawCart);

      if (decoded is! List) {
        await _secureStorage.delete(key: key);
        return <CartItem>[];
      }

      return decoded
          .whereType<Map>()
          .map((item) => CartItem.fromJson(Map<String, dynamic>.from(item)))
          .where(
            (item) =>
                item.id > 0 && item.name.trim().isNotEmpty && item.quantity > 0,
          )
          .toList();
    } catch (_) {
      await _secureStorage.delete(key: key);
      return <CartItem>[];
    }
  }

  Future<void> saveItems(List<CartItem> items) async {
    final key = await currentStorageKey();

    if (items.isEmpty) {
      await _secureStorage.delete(key: key);
      return;
    }

    await _secureStorage.write(
      key: key,
      value: jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> clear() async {
    final key = await currentStorageKey();
    await _secureStorage.delete(key: key);
  }
}
