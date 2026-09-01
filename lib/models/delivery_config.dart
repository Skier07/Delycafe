class DeliveryPriceTier {
  final int minCartTotal;
  final int price;

  const DeliveryPriceTier({
    required this.minCartTotal,
    required this.price,
  });

  factory DeliveryPriceTier.fromJson(Map<String, dynamic> json) {
    return DeliveryPriceTier(
      minCartTotal: _toInt(json['min_cart_total']),
      price: _toInt(json['price']),
    );
  }
}

class DeliveryZoneConfig {
  final String code;
  final String title;
  final String pricingMode;
  final int fixedPrice;
  final bool requiresAddress;
  final String defaultLocality;
  final int leadMinutes;
  final String checkoutDescription;
  final List<DeliveryPriceTier> tiers;

  const DeliveryZoneConfig({
    required this.code,
    required this.title,
    required this.pricingMode,
    required this.fixedPrice,
    required this.requiresAddress,
    required this.defaultLocality,
    required this.leadMinutes,
    required this.checkoutDescription,
    required this.tiers,
  });

  factory DeliveryZoneConfig.fromJson(Map<String, dynamic> json) {
    final tiersJson = json['price_tiers'];

    return DeliveryZoneConfig(
      code: json['code']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      pricingMode: json['pricing_mode']?.toString() ?? 'fixed',
      fixedPrice: _toInt(json['fixed_price']),
      requiresAddress: json['requires_address'] == true,
      defaultLocality: json['default_locality']?.toString() ?? '',
      leadMinutes: _toInt(json['lead_minutes'], fallback: 90),
      checkoutDescription: json['checkout_description']?.toString() ?? '',
      tiers: tiersJson is List
          ? tiersJson
              .map(
                (tier) => DeliveryPriceTier.fromJson(
                  tier as Map<String, dynamic>,
                ),
              )
              .toList(growable: false)
          : const [],
    );
  }
}

class DeliveryInfoSectionConfig {
  final String title;
  final String content;
  final String sectionType;

  const DeliveryInfoSectionConfig({
    required this.title,
    required this.content,
    required this.sectionType,
  });

  factory DeliveryInfoSectionConfig.fromJson(Map<String, dynamic> json) {
    return DeliveryInfoSectionConfig(
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      sectionType: json['section_type']?.toString() ?? 'info',
    );
  }

  bool get isWarning => sectionType == 'warning';
}

class DeliveryConfig {
  final List<DeliveryZoneConfig> zones;
  final List<DeliveryInfoSectionConfig> infoSections;

  const DeliveryConfig({
    required this.zones,
    required this.infoSections,
  });

  factory DeliveryConfig.fromJson(Map<String, dynamic> json) {
    final zonesJson = json['zones'];
    final sectionsJson = json['info_sections'];

    return DeliveryConfig(
      zones: zonesJson is List
          ? zonesJson
              .map(
                (zone) => DeliveryZoneConfig.fromJson(
                  zone as Map<String, dynamic>,
                ),
              )
              .toList(growable: false)
          : const [],
      infoSections: sectionsJson is List
          ? sectionsJson
              .map(
                (section) => DeliveryInfoSectionConfig.fromJson(
                  section as Map<String, dynamic>,
                ),
              )
              .toList(growable: false)
          : const [],
    );
  }

  static DeliveryConfig fallback() {
    return DeliveryConfig(
      zones: [
        DeliveryZoneConfig(
          code: 'ozersk',
          title: 'Озёрск',
          pricingMode: 'tiered',
          fixedPrice: 0,
          requiresAddress: true,
          defaultLocality: 'Озерск',
          leadMinutes: 90,
          checkoutDescription:
              'Озёрск: от 2000 ₽ бесплатно, от 1000 до 2000 ₽ — 250 ₽, '
              'до 1000 ₽ — 300 ₽',
          tiers: const [
            DeliveryPriceTier(minCartTotal: 0, price: 300),
            DeliveryPriceTier(minCartTotal: 1000, price: 250),
            DeliveryPriceTier(minCartTotal: 2000, price: 0),
          ],
        ),
        DeliveryZoneConfig(
          code: 'promploshadka',
          title: 'Промплощадка',
          pricingMode: 'fixed',
          fixedPrice: 400,
          requiresAddress: true,
          defaultLocality: 'Промплощадка',
          leadMinutes: 90,
          checkoutDescription: 'Промплощадка: доставка 400 ₽',
          tiers: const [],
        ),
        DeliveryZoneConfig(
          code: 'tatysh',
          title: 'Татыш',
          pricingMode: 'fixed',
          fixedPrice: 550,
          requiresAddress: true,
          defaultLocality: 'Татыш',
          leadMinutes: 120,
          checkoutDescription:
              'Татыш: доставка 550 ₽, минимальное время — около 2 часов',
          tiers: const [],
        ),
        DeliveryZoneConfig(
          code: 'pickup',
          title: 'Самовывоз',
          pricingMode: 'free',
          fixedPrice: 0,
          requiresAddress: false,
          defaultLocality: '',
          leadMinutes: 90,
          checkoutDescription: 'Самовывоз: скидка 5% на сумму заказа',
          tiers: const [],
        ),
      ],
      infoSections: const [],
    );
  }
}

int _toInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) return int.tryParse(value) ?? fallback;

  return fallback;
}
