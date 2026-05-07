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
      total += item.product.price * item.quantity;
    }
    return total;
  }

  void addToCart(CatalogItem product) {
    final index = _items.indexWhere(
      (item) => item.product.id == product.id,
    );

    if (index != -1) {
      _items[index].quantity++;
    } else {
      _items.add(CartItem(product: product));
    }

    notifyListeners();
  }

  void increaseQuantity(String productId) {
    final index = _items.indexWhere(
      (item) => item.product.id == productId,
    );

    if (index == -1) return;

    _items[index].quantity++;
    notifyListeners();
  }

  void decreaseQuantity(String productId) {
    final index = _items.indexWhere(
      (item) => item.product.id == productId,
    );

    if (index == -1) return;

    if (_items[index].quantity > 1) {
      _items[index].quantity--;
    } else {
      _items.removeAt(index);
    }

    notifyListeners();
  }

  // void increaseQuantity(CartItem cartItem) {
  //   cartItem.quantity++;
  //   notifyListeners();
  // }

  // void decreaseQuantity(CartItem cartItem) {
  //   if (cartItem.quantity > 1) {
  //     cartItem.quantity--;
  //   } else {
  //     items.remove(cartItem);
  //   }
  //   notifyListeners();
  // }

  void removeFromCart(String productId) {
    _items.removeWhere((item) => item.product.id == productId);
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}
