import 'dart:convert';

import 'package:delycafe/services/delivery_config_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> deliveryConfig(int price) => {
      'zones': [
        {
          'code': 'ozersk',
          'title': 'Озёрск',
          'pricing_mode': 'fixed',
          'fixed_price': price,
          'requires_address': true,
          'checkout_description': 'Доставка $price ₽',
          'price_tiers': [],
        }
      ],
      'info_sections': [],
      'price_basis': 'after_discounts',
    };

void main() {
  test('forced fetch replaces both price and description in the same process',
      () async {
    var price = 300;
    var calls = 0;
    final service = DeliveryConfigService(client: MockClient((_) async {
      calls++;
      return http.Response(jsonEncode(deliveryConfig(price)), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }));
    expect((await service.fetch()).zones.single.fixedPrice, 300);
    price = 350;
    expect((await service.fetch()).zones.single.fixedPrice, 300);
    final updated = await service.fetch(forceRefresh: true);
    expect(updated.zones.single.fixedPrice, 350);
    expect(updated.zones.single.checkoutDescription, 'Доставка 350 ₽');
    expect(updated.priceAfterDiscounts, isTrue);
    expect(calls, 2);
  });

  test(
      'offline fetch preserves last successful rates; payment requires fresh data',
      () async {
    var status = 200;
    final service = DeliveryConfigService(
        client: MockClient((_) async => http.Response(
            jsonEncode(deliveryConfig(450)), status,
            headers: {'content-type': 'application/json; charset=utf-8'})));
    await service.fetch();
    status = 503;
    expect(
        (await service.fetch(forceRefresh: true)).zones.single.fixedPrice, 450);
    await expectLater(service.fetch(requireFresh: true), throwsException);
    status = 200;
    expect(
        (await service.fetch(requireFresh: true)).zones.single.fixedPrice, 450);
  });

  test('failed first request does not cache fallback prices', () async {
    var status = 500;
    final service = DeliveryConfigService(
        client: MockClient((_) async => http.Response(
            jsonEncode(deliveryConfig(475)), status,
            headers: {'content-type': 'application/json; charset=utf-8'})));
    await service.fetch();
    status = 200;
    expect((await service.fetch()).zones.single.fixedPrice, 475);
  });

  test('empty or malformed response cannot authorize checkout', () async {
    for (final body in ['{}', '{"zones":[]}', 'not json']) {
      final service = DeliveryConfigService(
          client: MockClient((_) async => http.Response(body, 200)));
      await expectLater(service.fetch(requireFresh: true), throwsException);
    }
  });
}
