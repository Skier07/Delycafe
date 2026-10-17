import 'package:delycafe/widgets/checkout/price_change_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final accept in [true, false]) {
    testWidgets('price change requires explicit choice: $accept',
        (tester) async {
      bool? result;
      await tester.pumpWidget(MaterialApp(
          home: Builder(
              builder: (context) => TextButton(
                  onPressed: () async {
                    result = await confirmCheckoutPriceChange(context,
                        previousAmount: 1600, currentAmount: 1650);
                  },
                  child: const Text('Оплатить')))));
      await tester.tap(find.text('Оплатить'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.textContaining('Было: 1600 ₽'), findsOneWidget);
      await tester.tap(
          find.text(accept ? 'Продолжить за 1650 ₽' : 'Вернуться к заказу'));
      await tester.pumpAndSettle();
      expect(result, accept);
    });
  }
  testWidgets('unchanged amount proceeds without an extra dialog',
      (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => TextButton(
                onPressed: () async {
                  result = await confirmCheckoutPriceChange(context,
                      previousAmount: 1600, currentAmount: 1600);
                },
                child: const Text('Оплатить')))));
    await tester.tap(find.text('Оплатить'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
