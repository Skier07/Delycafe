import 'package:delycafe/models/catalog_item.dart';

class CartItem {
  final CatalogItem product;
  final ProductVariant? variant;
  int quantity;

  CartItem({
    required this.product,
    this.variant,
    this.quantity = 1,
  });

  int get unitPrice => variant?.price ?? product.price;

  int get totalPrice => unitPrice * quantity;

  String get displayTitle {
    if (variant == null) return product.title;
    return '${product.title} (${variant!.title})';
  }

  String get displayWeight {
    return variant?.weight ?? product.weight ?? '';
  }
}
