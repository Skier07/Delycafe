/// Separate UI fields while keeping the existing server address contract.
class StreetHouseAddress {
  const StreetHouseAddress(this.street, this.house);

  final String street;
  final String house;

  String get addressLine => [
        if (street.trim().isNotEmpty) street.trim(),
        if (house.trim().isNotEmpty) 'д. ${house.trim()}',
      ].join(', ');
}

/// Only split an explicit house marker or a final comma-separated number.
/// Digits in street names (e.g. «40 лет Победы») are not house numbers.
StreetHouseAddress splitStreetAndHouse(String address) {
  final value = address.trim();
  final match = RegExp(
    r'^(.*?)(?:,\s*(?:(?:дом|д)\.?\s*)?|\s+(?:дом|д)\.?\s*)(\d[0-9а-яёa-z /\-]*(?:\s*(?:корпус|корп\.?|к\.?|строение|стр\.?)\s*[0-9а-яёa-z/\-]+)?)$',
    caseSensitive: false,
  ).firstMatch(value);
  if (match == null || match.group(1)!.trim().isEmpty) {
    return StreetHouseAddress(value, '');
  }
  return StreetHouseAddress(match.group(1)!.trim(), match.group(2)!.trim());
}

String? validateHouseNumber(String? value) {
  final house = (value ?? '').trim();
  if (house.isEmpty) return 'Укажите дом';
  if (house.length > 30 ||
      !RegExp(r'^\d[0-9а-яёa-z /\.\-]*$', caseSensitive: false)
          .hasMatch(house)) {
    return 'Например, 12А';
  }
  return null;
}
