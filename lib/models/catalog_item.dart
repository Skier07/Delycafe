class ProductVariant {
  final String id;
  final int? sabyId;
  final String title;
  final int price;
  final String weight;

  const ProductVariant({
    required this.id,
    this.sabyId,
    required this.title,
    required this.price,
    this.weight = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'saby_id': sabyId,
      'title': title,
      'price': price,
      'weight': weight,
    };
  }

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      id: json['id']?.toString() ?? '',
      sabyId: _toNullableInt(json['saby_id']),
      title: json['title']?.toString() ?? '',
      price: _toInt(json['price']),
      weight: json['weight']?.toString() ?? '',
    );
  }
}

class CatalogItem {
  final String id;
  final int? sabyId;
  final String title;
  final String category;
  final int categorySortOrder;
  final int price;
  final String image;
  final String description;
  final String? shortDescription;
  final bool isHit;
  final bool isNew;
  final bool isAvailable;
  final bool isVisible;
  final int? oldPrice;
  final int sortOrder;
  final String? weight;
  final String? composition;
  final List<ProductVariant> variants;

  const CatalogItem({
    required this.id,
    this.sabyId,
    required this.title,
    required this.category,
    this.categorySortOrder = 500,
    required this.price,
    required this.image,
    required this.description,
    this.shortDescription,
    this.isHit = false,
    this.isNew = false,
    this.isAvailable = true,
    this.isVisible = true,
    this.oldPrice,
    this.sortOrder = 999999999,
    this.weight,
    this.composition,
    this.variants = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'saby_id': sabyId,
      'title': title,
      'category': category,
      'category_sort_order': categorySortOrder,
      'price': price,
      'image': image,
      'description': description,
      'short_description': shortDescription,
      'is_hit': isHit,
      'is_new': isNew,
      'is_available': isAvailable,
      'is_visible': isVisible,
      'old_price': oldPrice,
      'sort_order': sortOrder,
      'weight': weight,
      'composition': composition,
      'variants': variants.map((variant) => variant.toJson()).toList(),
    };
  }

  factory CatalogItem.fromJson(Map<String, dynamic> json) {
    final variantsJson = json['variants'];

    final variants = variantsJson is List
        ? variantsJson
            .whereType<Map>()
            .map(
              (variantJson) => ProductVariant.fromJson(
                Map<String, dynamic>.from(variantJson),
              ),
            )
            .toList()
        : <ProductVariant>[];

    return CatalogItem(
      id: json['id']?.toString() ?? '',
      sabyId: _toNullableInt(json['saby_id']),
      title: json['title']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Другое',
      categorySortOrder: _toInt(
        json['category_sort_order'],
        defaultValue: 500,
      ),
      price: _toInt(json['price']),
      image: json['image']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      shortDescription: json['short_description']?.toString(),
      isHit: json['is_hit'] == true,
      isNew: json['is_new'] == true,
      isAvailable: json['is_available'] != false,
      isVisible: json['is_visible'] != false,
      oldPrice: _toNullableInt(json['old_price']),
      sortOrder: _toInt(json['sort_order'], defaultValue: 999999999),
      weight: json['weight']?.toString(),
      composition: json['composition']?.toString(),
      variants: variants,
    );
  }
}

int _toInt(
  dynamic value, {
  int defaultValue = 0,
}) {
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) return int.tryParse(value) ?? defaultValue;

  return defaultValue;
}

int? _toNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) return int.tryParse(value);

  return null;
}
