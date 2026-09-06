import 'package:delycafe/utils/pickup_discount.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pickupDiscountForLines', () {
    test('matches Saby per-item floor, not total*percent~/100', () {
      // 509 * 5% = 25.45 → total floor = 25
      // per-item: 509*95~/100 = 483 → discount 26
      expect(
        pickupDiscountForLines([(unitPrice: 509, quantity: 1)], 5),
        26,
      );
      expect(509 * 5 ~/ 100, 25);
    });

    test('sums line discounts for mixed cart', () {
      final lines = [
        (unitPrice: 100, quantity: 1),
        (unitPrice: 109, quantity: 2),
        (unitPrice: 521, quantity: 1),
      ];

      var expected = 0;
      for (final line in lines) {
        final discounted = line.unitPrice * 95 ~/ 100;
        expected += (line.unitPrice - discounted) * line.quantity;
      }

      expect(pickupDiscountForLines(lines, 5), expected);
    });

    test('returns 0 for empty or zero percent', () {
      expect(pickupDiscountForLines(const [], 5), 0);
      expect(
        pickupDiscountForLines([(unitPrice: 1000, quantity: 1)], 0),
        0,
      );
    });
  });
}
