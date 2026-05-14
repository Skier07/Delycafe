class ProductVariant {
  final String id;
  final String title;
  final int price;
  final String weight;

  const ProductVariant({
    required this.id,
    required this.title,
    required this.price,
    required this.weight,
  });
}

class CatalogItem {
  final String id;
  final String title;
  final String category;
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
    required this.title,
    required this.category,
    required this.price,
    required this.image,
    required this.description,
    this.shortDescription,
    this.isHit = false,
    this.isNew = false,
    this.isAvailable = true,
    this.isVisible = true,
    this.oldPrice,
    this.sortOrder = 0,
    this.weight,
    this.composition,
    this.variants = const [],
  });
}
