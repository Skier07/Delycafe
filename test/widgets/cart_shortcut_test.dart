import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:delycafe/models/catalog_item.dart';
import 'package:delycafe/services/cart_service.dart';
import 'package:delycafe/widgets/catalog/cart_shortcut.dart';

void main() {
  testWidgets('bar appears, updates quantity and disappears on empty cart',
      (tester) async {
    final cart = CartService();
    addTearDown(cart.dispose);
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: cart,
        child: const MaterialApp(
            home: Scaffold(bottomNavigationBar: FloatingCartBar()))));
    expect(find.byType(CartShortcut), findsNothing);
    const product = CatalogItem(
        id: '1',
        title: 'Паста',
        category: 'Паста',
        price: 380,
        image: '',
        description: '');
    cart.addToCart(product);
    await tester.pumpAndSettle();
    expect(find.text('1 товар · 380 ₽'), findsOneWidget);
    cart.addToCart(product, quantity: 2);
    await tester.pumpAndSettle();
    expect(find.text('3 товара · 1140 ₽'), findsOneWidget);
    cart.clear();
    await tester.pumpAndSettle();
    expect(find.byType(CartShortcut), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
