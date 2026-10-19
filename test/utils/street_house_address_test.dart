import 'package:delycafe/utils/delivery_address_parser.dart';
import 'package:delycafe/utils/street_house_address.dart';
import 'package:delycafe/services/checkout_draft_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('old addresses keep city, compound house and separate apartment details',
      () {
    for (final house in ['12А', '12/1', '12 корп. 2', '12 стр. 1', '12-14']) {
      final full = parseDeliveryAddress(
        'Озерск, Пушкина, д. $house, подъезд 1, этаж 1, кв. 3',
      );
      final fields = splitStreetAndHouse(full.street);
      expect(fields.street, 'Озерск, Пушкина');
      expect(fields.house, house);
      expect(full.entrance, '1');
      expect(full.apartment, '3');
      expect(fields.addressLine, 'Озерск, Пушкина, д. $house');
      expect(validateHouseNumber(fields.house), isNull);
    }
    expect(splitStreetAndHouse('Пушкина, 10').house, '10');
    expect(splitStreetAndHouse('Пушкина дом 10').house, '10');
  });

  test('numbers in street names and apartment details do not supply a house',
      () {
    for (final street in ['40 лет Победы', '8 Марта', 'улица 1905 года']) {
      final fields = splitStreetAndHouse(street);
      expect(fields.street, street);
      expect(fields.house, isEmpty);
    }
    final address = parseDeliveryAddress('Пушкина, подъезд 1, этаж 1, кв.3');
    expect(splitStreetAndHouse(address.street).house, isEmpty);
    expect(validateHouseNumber(''), isNotNull);
    expect(validateHouseNumber('А'), isNotNull);
  });

  test('draft retains a separate house and can read old draft format', () {
    const draft = CheckoutDraft(address: 'Пушкина', house: '12/1');
    final restored = CheckoutDraft.fromJson(draft.toJson());
    expect(restored.house, '12/1');
    expect(restored.address, 'Пушкина');
    expect(const CheckoutDraft(house: '1').isEmpty, isFalse);
    final old = CheckoutDraft.fromJson({'address': 'Пушкина, 10'});
    expect(old.house, isEmpty);
    expect(splitStreetAndHouse(old.address).house, '10');
  });
}
