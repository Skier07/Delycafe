/// Имена Hive box для DelyCafe.
abstract final class HiveBoxes {
  static const catalog = 'catalog_box';
  static const user = 'user_box';
  static const orders = 'orders_box';
  static const local = 'local_box';
}

/// Служебные ключи внутри [HiveBoxes.catalog].
abstract final class CatalogCacheKeys {
  static const categories = '__meta_categories__';
  static const updatedAt = '__meta_updated_at__';
}
