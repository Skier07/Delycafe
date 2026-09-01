import 'package:delycafe/models/product_info_block.dart';

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
  final bool categoryPreorderCutoffEnabled;
  final int categoryPreorderLeadDays;
  final String categoryPreorderCutoffTime;
  final int price;
  final String image;
  final List<String> images;
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
  final List<ProductInfoBlock>? infoBlocks;
  final bool canOrder;
  final String cannotOrderReason;

  const CatalogItem({
    required this.id,
    this.sabyId,
    required this.title,
    required this.category,
    this.categorySortOrder = 500,
    this.categoryPreorderCutoffEnabled = false,
    this.categoryPreorderLeadDays = 0,
    this.categoryPreorderCutoffTime = '',
    required this.price,
    required this.image,
    this.images = const [],
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
    this.infoBlocks,
    this.canOrder = true,
    this.cannotOrderReason = '',
  });

  List<String> get galleryImages {
    if (images.isNotEmpty) {
      return images;
    }

    if (image.trim().isNotEmpty) {
      return [image];
    }

    return const [];
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'saby_id': sabyId,
      'title': title,
      'category': category,
      'category_sort_order': categorySortOrder,
      'category_preorder_cutoff_enabled': categoryPreorderCutoffEnabled,
      'category_preorder_lead_days': categoryPreorderLeadDays,
      'category_preorder_cutoff_time': categoryPreorderCutoffTime,
      'price': price,
      'image': image,
      'images': images,
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
      if (infoBlocks != null)
        'info_blocks': infoBlocks!.map((block) => block.toJson()).toList(),
      'can_order': canOrder,
      'cannot_order_reason': cannotOrderReason,
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

    List<ProductInfoBlock>? infoBlocks;

    if (json.containsKey('info_blocks')) {
      final rawBlocks = json['info_blocks'];
      infoBlocks = rawBlocks is List
          ? rawBlocks
              .whereType<Map>()
              .map(
                (blockJson) => ProductInfoBlock.fromJson(
                  Map<String, dynamic>.from(blockJson),
                ),
              )
              .where((block) => block.resolvedLines().isNotEmpty)
              .toList()
          : <ProductInfoBlock>[];
    }

    final imagesJson = json['images'];
    final images = imagesJson is List
        ? imagesJson
            .map((value) => value?.toString() ?? '')
            .where((value) => value.trim().isNotEmpty)
            .toList(growable: false)
        : const <String>[];

    return CatalogItem(
      id: json['id']?.toString() ?? '',
      sabyId: _toNullableInt(json['saby_id']),
      title: json['title']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Другое',
      categorySortOrder: _toInt(
        json['category_sort_order'],
        defaultValue: 500,
      ),
      categoryPreorderCutoffEnabled:
          json['category_preorder_cutoff_enabled'] == true,
      categoryPreorderLeadDays: _toInt(json['category_preorder_lead_days']),
      categoryPreorderCutoffTime:
          json['category_preorder_cutoff_time']?.toString() ?? '',
      price: _toInt(json['price']),
      image: json['image']?.toString() ?? '',
      images: images,
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
      infoBlocks: infoBlocks,
      canOrder: json['can_order'] != false,
      cannotOrderReason: json['cannot_order_reason']?.toString() ?? '',
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
