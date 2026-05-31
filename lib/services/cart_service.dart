import 'package:delycafe/models/cart_item.dart';
import 'package:delycafe/models/catalog_item.dart';
import 'package:flutter/material.dart';

class CartService extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  int get totalItems {
    int total = 0;

    for (final item in _items) {
      total += item.quantity;
    }

    return total;
  }

  int get totalPrice {
    int total = 0;

    for (final item in _items) {
      total += item.totalPrice;
    }

    return total;
  }

  bool get isEmpty => _items.isEmpty;

  void addToCart(
    CatalogItem product, {
    ProductVariant? variant,
  }) {
    final index = _items.indexWhere(
      (item) =>
          item.product.id == product.id && item.variant?.id == variant?.id,
    );

    if (index != -1) {
      _items[index].quantity++;
    } else {
      _items.add(
        CartItem(
          product: product,
          variant: variant,
        ),
      );
    }

    notifyListeners();
  }

  void increaseCartItem(CartItem cartItem) {
    cartItem.quantity++;
    notifyListeners();
  }

  void decreaseCartItem(CartItem cartItem) {
    if (cartItem.quantity > 1) {
      cartItem.quantity--;
    } else {
      _items.remove(cartItem);
    }

    notifyListeners();
  }

  List<Map<String, dynamic>> toOrderApiItems() {
    return _items.map((cartItem) {
      final product = cartItem.product;
      final variant = cartItem.variant;

      final price = variant?.price ?? product.price;
      final sabyId = variant?.sabyId ?? product.sabyId;

      return {
        'product_title': product.title,
        'variant_title': variant?.title ?? '',
        'product_api_id': product.id,
        'saby_id': sabyId,
        'quantity': cartItem.quantity,
        'price': price,
      };
    }).toList();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }

  void clear() {
    clearCart();
  }
}
