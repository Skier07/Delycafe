import 'package:delycafe/models/catalog_item.dart';
import 'package:delycafe/models/order.dart';

class RepeatOrderMatch {
  final CatalogItem product;
  final ProductVariant? variant;
  final int quantity;

  const RepeatOrderMatch({
    required this.product,
    required this.variant,
    required this.quantity,
  });
}

class RepeatOrderResult {
  final List<RepeatOrderMatch> matches;
  final List<OrderItem> unavailableItems;

  const RepeatOrderResult({
    required this.matches,
    required this.unavailableItems,
  });

  bool get canRepeatFully =>
      unavailableItems.isEmpty && matches.isNotEmpty;
}

class RepeatOrderService {
  RepeatOrderResult resolve(
    Order order,
    List<CatalogItem> catalog,
  ) {
    if (order.items.isEmpty || catalog.isEmpty) {
      return RepeatOrderResult(
        matches: const [],
        unavailableItems: order.items,
      );
    }

    final matches = <RepeatOrderMatch>[];
    final unavailableItems = <OrderItem>[];

    for (final orderItem in order.items) {
      final match = _matchOrderItem(orderItem, catalog);

      if (match == null) {
        unavailableItems.add(orderItem);
        continue;
      }

      matches.add(
        RepeatOrderMatch(
          product: match.product,
          variant: match.variant,
          quantity: orderItem.quantity,
        ),
      );
    }

    return RepeatOrderResult(
      matches: matches,
      unavailableItems: unavailableItems,
    );
  }

  _ProductMatch? _matchOrderItem(
    OrderItem orderItem,
    List<CatalogItem> catalog,
  ) {
    final product = _findProduct(orderItem, catalog);

    if (product == null) {
      return null;
    }

    final variant = _findVariant(orderItem, product);

    if (product.variants.isNotEmpty && variant == null) {
      return null;
    }

    if (orderItem.variantTitle.isNotEmpty &&
        product.variants.isEmpty) {
      return null;
    }

    return _ProductMatch(
      product: product,
      variant: variant,
    );
  }

  CatalogItem? _findProduct(
    OrderItem orderItem,
    List<CatalogItem> catalog,
  ) {
    if (orderItem.productApiId.isNotEmpty) {
      for (final product in catalog) {
        if (product.id == orderItem.productApiId) {
          return product;
        }
      }
    }

    if (orderItem.sabyId != null) {
      for (final product in catalog) {
        if (product.sabyId == orderItem.sabyId) {
          return product;
        }

        for (final variant in product.variants) {
          if (variant.sabyId == orderItem.sabyId) {
            return product;
          }
        }
      }
    }

    final normalizedTitle = _normalize(orderItem.productTitle);

    for (final product in catalog) {
      if (_normalize(product.title) == normalizedTitle) {
        return product;
      }
    }

    return null;
  }

  ProductVariant? _findVariant(
    OrderItem orderItem,
    CatalogItem product,
  ) {
    if (product.variants.isEmpty) {
      return null;
    }

    if (orderItem.sabyId != null) {
      for (final variant in product.variants) {
        if (variant.sabyId == orderItem.sabyId) {
          return variant;
        }
      }
    }

    if (orderItem.variantTitle.isNotEmpty) {
      final normalizedVariantTitle = _normalize(orderItem.variantTitle);

      for (final variant in product.variants) {
        if (_normalize(variant.title) == normalizedVariantTitle) {
          return variant;
        }
      }
    }

    return null;
  }

  String _normalize(String value) {
    return value.trim().toLowerCase();
  }
}

class _ProductMatch {
  final CatalogItem product;
  final ProductVariant? variant;

  const _ProductMatch({
    required this.product,
    required this.variant,
  });
}
