import 'package:delycafe/models/catalog_item.dart';

class CartItem {
  final CatalogItem product;
  int quantity;

  CartItem({
    required this.product,
    this.quantity = 1,
  });
}
