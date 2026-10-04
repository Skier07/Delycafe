import 'package:delycafe/models/catalog_item.dart';
import 'package:delycafe/widgets/catalog/catalog_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final screenWidth in [280.0, 320.0, 360.0, 390.0, 400.0, 430.0, 600.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final available in [true, false]) {
        testWidgets(
            'card fits at $screenWidth, scale $scale, available $available',
            (tester) async {
          final pad = screenWidth < 400 ? 12.0 : 16.0;
          final spacing = screenWidth < 400 ? 10.0 : 12.0;
          final width = (screenWidth - pad * 2 - spacing) / 2;
          final scaler = TextScaler.linear(scale);
          final originalHeight = width / (screenWidth < 400 ? 0.56 : 0.63);
          final requiredHeight = CatalogCard.gridHeight(width, scaler);
          await tester.pumpWidget(MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: scaler),
              child: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: width,
                    height: requiredHeight > originalHeight
                        ? requiredHeight
                        : originalHeight,
                    child: CatalogCard(
                      item: CatalogItem(
                        id: 'pie',
                        title: 'Пирог с курицей и картофелем большой',
                        category: 'Пироги',
                        price: 12345,
                        image: '',
                        description:
                            'Длинное описание начинки домашнего пирога',
                        categoryPreorderCutoffEnabled: !available,
                        categoryPreorderCutoffTime: '00:00',
                      ),
                      onAddToCart: ({variant}) {},
                    ),
                  ),
                ),
              ),
            ),
          ));
          expect(tester.takeException(), isNull);
          final label = find.text(available ? 'В корзину' : 'Недоступно');
          final button = find
              .ancestor(of: label, matching: find.byType(GestureDetector))
              .first;
          final cardRect = tester.getRect(find.byType(CatalogCard));
          final buttonRect = tester.getRect(button);
          expect(buttonRect.bottom, lessThanOrEqualTo(cardRect.bottom - 8 + 0.001));
          expect(buttonRect.left, greaterThanOrEqualTo(cardRect.left));
          expect(buttonRect.right, lessThanOrEqualTo(cardRect.right));
          expect(tester.getRect(label).height, greaterThan(0));
        });
      }
    }
  }
}
