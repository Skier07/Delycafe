import 'package:delycafe/data/hive/hive_boxes.dart';
import 'package:delycafe/models/catalog_item.dart';
import 'package:delycafe/models/category.dart';
import 'package:hive/hive.dart';

class CatalogSnapshot {
  final List<CatalogItem> products;
  final List<Category> categories;
  final DateTime? updatedAt;

  const CatalogSnapshot({
    required this.products,
    required this.categories,
    this.updatedAt,
  });

  List<String> get categoryTitles =>
      categories.map((category) => category.title).toList();
}

/// Кэш каталога: каждый товар — отдельная запись в [HiveBoxes.catalog].
class CatalogCacheService {
  Box<Map> get _box => Hive.box<Map>(HiveBoxes.catalog);

  bool get hasData {
    return _box.keys.any(
      (key) => key != CatalogCacheKeys.categories &&
          key != CatalogCacheKeys.updatedAt,
    );
  }

  CatalogSnapshot? readCached() {
    if (!hasData) {
      return null;
    }

    final products = <CatalogItem>[];

    for (final key in _box.keys) {
      if (key == CatalogCacheKeys.categories ||
          key == CatalogCacheKeys.updatedAt) {
        continue;
      }

      final raw = _box.get(key);
      if (raw == null) continue;

      products.add(
        CatalogItem.fromJson(Map<String, dynamic>.from(raw)),
      );
    }

    if (products.isEmpty) {
      return null;
    }

    final categories = _readCategories();
    final updatedAt = _readUpdatedAt();

    return CatalogSnapshot(
      products: products,
      categories: categories,
      updatedAt: updatedAt,
    );
  }

  Future<void> save({
    required List<CatalogItem> products,
    required List<Category> categories,
  }) async {
    final productIds = products.map((product) => product.id).toSet();

    for (final key in _box.keys.toList()) {
      if (key == CatalogCacheKeys.categories ||
          key == CatalogCacheKeys.updatedAt) {
        continue;
      }

      if (!productIds.contains(key)) {
        await _box.delete(key);
      }
    }

    for (final product in products) {
      await _box.put(product.id, product.toJson());
    }

    await _box.put(
      CatalogCacheKeys.categories,
      {
        'items': categories.map((category) => category.toJson()).toList(),
      },
    );
    await _box.put(
      CatalogCacheKeys.updatedAt,
      {'ms': DateTime.now().millisecondsSinceEpoch},
    );
  }

  List<Category> _readCategories() {
    final raw = _box.get(CatalogCacheKeys.categories);
    if (raw == null) {
      return const [];
    }

    final items = raw['items'];
    if (items is! List) {
      return const [];
    }

    return items
        .whereType<Map>()
        .map(
          (item) => Category.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  DateTime? _readUpdatedAt() {
    final raw = _box.get(CatalogCacheKeys.updatedAt);
    if (raw == null) {
      return null;
    }

    final ms = raw['ms'];
    if (ms is! int) {
      return null;
    }

    return DateTime.fromMillisecondsSinceEpoch(ms);
  }
}
