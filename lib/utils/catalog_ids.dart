/// Нормализует идентификаторы каталога для API заказа.
class CatalogIds {
  const CatalogIds._();

  /// Числовой PK товара в Django (`123`) или пустая строка.
  static String orderProductApiId(String catalogProductId) {
    final raw = catalogProductId.trim();

    if (raw.isEmpty) {
      return '';
    }

    if (RegExp(r'^\d+$').hasMatch(raw)) {
      return raw;
    }

    if (raw.startsWith('api_')) {
      final suffix = raw.substring(4);

      if (RegExp(r'^\d+$').hasMatch(suffix)) {
        return suffix;
      }
    }

    return '';
  }

  /// Saby ID из поля товара или префикса `saby_23`.
  static int? orderSabyId({
    required String catalogProductId,
    int? productSabyId,
    int? variantSabyId,
  }) {
    if (variantSabyId != null) {
      return variantSabyId;
    }

    if (productSabyId != null) {
      return productSabyId;
    }

    final raw = catalogProductId.trim();

    if (raw.startsWith('saby_')) {
      return int.tryParse(raw.substring(5));
    }

    return null;
  }
}
