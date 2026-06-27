/// Feature flags for gradual rollout.
class AppFeatures {
  AppFeatures._();

  /// Накопительные бонусы (экран, списание, начисление).
  static const bool bonusesEnabled = false;

  /// Скидка 20% на первый заказ.
  static const bool firstOrderDiscountEnabled = false;
}
