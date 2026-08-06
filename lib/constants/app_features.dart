/// Feature flags for gradual rollout.
class AppFeatures {
  AppFeatures._();

  /// Накопительные бонусы (экран, списание, начисление в Saby).
  static const bool bonusesEnabled = true;

  /// Скидка 20% на первый заказ — отключена.
  static const bool firstOrderDiscountEnabled = false;
}
