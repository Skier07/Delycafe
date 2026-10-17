import 'package:delycafe/models/delivery_config.dart';

int calculateDeliveryPrice(DeliveryZoneConfig zone, int cartTotal) {
  switch (zone.pricingMode) {
    case 'free':
      return 0;
    case 'fixed':
      return zone.fixedPrice;
    case 'tiered':
      final tiers = zone.tiers.toList()
        ..sort((a, b) => b.minCartTotal.compareTo(a.minCartTotal));

      for (final tier in tiers) {
        if (cartTotal >= tier.minCartTotal) {
          return tier.price;
        }
      }

      // Below the minimum the checkout is blocked; do not advertise free delivery.
      return tiers.isEmpty ? 0 : tiers.last.price;
    default:
      return 0;
  }
}
