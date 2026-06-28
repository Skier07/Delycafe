class ParsedDeliveryAddress {
  final String street;
  final String entrance;
  final String floor;
  final String apartment;

  const ParsedDeliveryAddress({
    this.street = '',
    this.entrance = '',
    this.floor = '',
    this.apartment = '',
  });

  String get displayLine {
    final parts = <String>[
      if (street.isNotEmpty) street,
      if (entrance.isNotEmpty) 'подъезд $entrance',
      if (floor.isNotEmpty) 'этаж $floor',
      if (apartment.isNotEmpty) 'кв. $apartment',
    ];

    return parts.join(', ');
  }
}

final _entrancePattern = RegExp(
  r'(?:^|,\s*)подъезд\s+([^,]+)',
  caseSensitive: false,
);
final _floorPattern = RegExp(
  r'(?:^|,\s*)этаж\s+([^,]+)',
  caseSensitive: false,
);
final _apartmentPattern = RegExp(
  r'(?:^|,\s*)кв\.?(?:\s*/\s*офис)?\s+([^,]+)',
  caseSensitive: false,
);

ParsedDeliveryAddress parseDeliveryAddress(String raw) {
  var value = raw.trim();

  if (value.isEmpty) {
    return const ParsedDeliveryAddress();
  }

  var entrance = '';
  var floor = '';
  var apartment = '';

  final entranceMatch = _entrancePattern.firstMatch(value);
  if (entranceMatch != null) {
    entrance = entranceMatch.group(1)?.trim() ?? '';
    value = value.replaceFirst(entranceMatch.group(0)!, '');
  }

  final floorMatch = _floorPattern.firstMatch(value);
  if (floorMatch != null) {
    floor = floorMatch.group(1)?.trim() ?? '';
    value = value.replaceFirst(floorMatch.group(0)!, '');
  }

  final apartmentMatch = _apartmentPattern.firstMatch(value);
  if (apartmentMatch != null) {
    apartment = apartmentMatch.group(1)?.trim() ?? '';
    value = value.replaceFirst(apartmentMatch.group(0)!, '');
  }

  final street = value
      .replaceAll(RegExp(r'\s*,\s*'), ', ')
      .replaceAll(RegExp(r'^,\s*'), '')
      .replaceAll(RegExp(r'\s*,$'), '')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();

  return ParsedDeliveryAddress(
    street: street,
    entrance: entrance,
    floor: floor,
    apartment: apartment,
  );
}
