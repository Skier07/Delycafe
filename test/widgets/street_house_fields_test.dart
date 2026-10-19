import 'package:delycafe/widgets/checkout/street_house_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in [(320.0, 1.0), (390.0, 1.0), (320.0, 2.0)]) {
    testWidgets('house required without overflow at $size', (tester) async {
      tester.view.physicalSize = Size(size.$1, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final street = TextEditingController(text: 'Пушкина');
      final house = TextEditingController();
      final form = GlobalKey<FormState>();
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(size.$2)),
          child: Scaffold(
              body: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
                key: form,
                child: StreetHouseFields(
                  streetController: street,
                  houseController: house,
                  decoration: (label) => InputDecoration(
                    labelText: label,
                    border: const OutlineInputBorder(),
                  ),
                )),
          )),
        ),
      ));
      expect(form.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Укажите дом'), findsOneWidget);
      expect(tester.takeException(), isNull);
      house.text = '12А/1';
      expect(form.currentState!.validate(), isTrue);
      // Restored values do not pass through formatters, so validate those too.
      street.text = 'Пушкина, 12';
      expect(form.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Уберите цифры из улицы'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextFormField).first, 'Пушкина 123');
      expect(street.text, 'Пушкина ');
      await tester.enterText(find.byType(TextFormField).first, '123');
      expect(street.text, isEmpty);
      expect(form.currentState!.validate(), isFalse);
      await tester.enterText(find.byType(TextFormField).first, 'Пушкина');
      await tester.enterText(find.byType(TextFormField).last, '12А/1');
      expect(house.text, '12А/1');
      expect(form.currentState!.validate(), isTrue);
      await tester.pump();
      expect(tester.takeException(), isNull);
      final streetY = tester.getTopLeft(find.byType(TextFormField).first).dy;
      final houseY = tester.getTopLeft(find.byType(TextFormField).last).dy;
      if (size.$1 == 390 && size.$2 == 1) {
        expect(houseY, streetY);
      } else {
        expect(houseY, greaterThan(streetY));
      }
      await tester.pumpWidget(const SizedBox());
      street.dispose();
      house.dispose();
    });
  }
}
