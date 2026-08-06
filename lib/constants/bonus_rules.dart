/// Default bonus / pickup rules when the API does not return percentages.
class BonusRules {
  /// Начисление в Saby Presto (программа лояльности).
  static const int earnPercent = 3;

  /// Максимум списания бонусами от суммы товаров (после скидок).
  static const int maxSpendPercent = 25;

  /// Скидка при самовывозе.
  static const int pickupDiscountPercent = 5;

  /// Отключено — не использовать в UI.
  static const int firstOrderDiscountPercent = 20;
}
