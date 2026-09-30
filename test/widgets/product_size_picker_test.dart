import 'package:delycafe/models/catalog_item.dart';
import 'package:delycafe/services/cart_service.dart';
import 'package:delycafe/widgets/catalog/catalog_card.dart';
import 'package:delycafe/widgets/catalog/cart_shortcut.dart';
import 'package:delycafe/widgets/catalog/product_size_picker.dart';
import 'package:delycafe/screens/catalog/product_detail_screen.dart';
import 'package:delycafe/utils/haptic_feedback.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const pizza = CatalogItem(
    id: 'pizza',
    title: 'Пицца',
    category: 'Пицца',
    price: 500,
    image: '',
    description: '',
    variants: [
      ProductVariant(id: 's', title: 'Маленькая', price: 300),
      ProductVariant(id: 'm', title: 'Средняя', price: 500),
      ProductVariant(id: 'l', title: 'Большая', price: 700),
    ]);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('catalog refresh rejects an outdated price from an open picker',
      (tester) async {
    final item = ValueNotifier(pizza);
    addTearDown(item.dispose);
    var additions = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Center(
                child: SizedBox(
                    width: 220,
                    height: 320,
                    child: ValueListenableBuilder<CatalogItem>(
                        valueListenable: item,
                        builder: (_, value, child) => CatalogCard(
                            item: value,
                            onAddToCart: ({variant}) => additions++)))))));
    await tester.tap(find.text('Выбрать'));
    await tester.pumpAndSettle();
    item.value = CatalogItem(
        id: pizza.id,
        title: pizza.title,
        category: pizza.category,
        price: 600,
        image: '',
        description: '',
        variants: const [
          ProductVariant(id: 's', title: 'Маленькая', price: 300),
          ProductVariant(id: 'm', title: 'Средняя', price: 600),
        ]);
    await tester.pump();
    await tester.tap(find.text('Добавить'));
    await tester.pumpAndSettle();
    expect(additions, 0);
    expect(find.text('Товар изменился. Пожалуйста, выберите размер ещё раз.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'size selection adds the exact variant with one impact per action',
      (tester) async {
    final cart = CartService();
    addTearDown(cart.dispose);
    final impacts = <Object?>[];
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') impacts.add(call.arguments);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: cart,
        child: MaterialApp(
            home: Scaffold(
          body: Center(
              child: SizedBox(
                  width: 220,
                  height: 320,
                  child: CatalogCard(
                      item: pizza,
                      onAddToCart: ({variant}) =>
                          cart.addToCart(pizza, variant: variant)))),
          bottomNavigationBar: const FloatingCartBar(),
        ))));
    await tester.tap(find.text('Выбрать'));
    await tester.pumpAndSettle();
    expect(cart.isEmpty, isTrue);
    expect(impacts, isEmpty);
    for (final pair in [
      ('Маленькая', 'lightImpact', .86),
      ('Средняя', 'mediumImpact', .93),
      ('Большая', 'heavyImpact', 1.0)
    ]) {
      await tester.tap(find.widgetWithText(
          ChoiceChip,
          '${pair.$1}\n${pair.$1 == 'Маленькая' ? 300 : pair.$1 == 'Средняя' ? 500 : 700} ₽'));
      await tester.pumpAndSettle();
      expect(impacts.last, 'HapticFeedbackType.${pair.$2}');
      final scale = tester.widget<AnimatedScale>(find.descendant(
          of: find.byType(SizePreview), matching: find.byType(AnimatedScale)));
      expect(scale.scale, pair.$3);
    }
    expect(impacts.length, 3);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Большая\n700 ₽'));
    await tester.pumpAndSettle();
    expect(impacts.length, 3);
    // A rapid second callback during the closing transition must not pop
    // the underlying catalog or submit twice.
    final submit = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Добавить'))
        .onPressed!;
    submit();
    submit();
    await tester.pumpAndSettle();
    expect(impacts, hasLength(4));
    expect(impacts.last, 'HapticFeedbackType.heavyImpact');
    expect(cart.items.single.variant?.id, 'l');
    expect(cart.totalPrice, 700);
    expect(find.text('1 товар · 700 ₽'), findsOneWidget);
    await tester.tap(find.text('Выбрать'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('Добавить'))).pop();
    await tester.pumpAndSettle();
    expect(cart.totalItems, 1);
    expect(impacts.length, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'detail adds selected size and reduced motion keeps the cart still',
      (tester) async {
    final cart = CartService();
    addTearDown(cart.dispose);
    AppHaptics.enabled = false;
    addTearDown(() => AppHaptics.enabled = true);
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: cart,
        child: MaterialApp(
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!),
            home: const ProductDetailScreen(item: pizza))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Маленькая'));
    await tester.tap(find.text('Маленькая'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('В корзину'));
    await tester.pumpAndSettle();
    expect(cart.items.single.variant?.id, 's');
    expect(cart.totalPrice, 300);
    final scale = tester.widget<AnimatedScale>(find.descendant(
        of: find.byType(SizePreview), matching: find.byType(AnimatedScale)));
    expect(scale.duration, Duration.zero);
    expect(scale.scale, .86);
    final pulse = tester.widget<ScaleTransition>(find
        .descendant(
            of: find.byType(CartAddPulse),
            matching: find.byType(ScaleTransition))
        .first);
    expect(pulse.scale.value, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('picker fits a narrow screen with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!),
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => showProductSizePicker(context, pizza),
                    child: const Text('Выбрать'))))));
    await tester.tap(find.text('Выбрать'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Добавить'));
    expect(tester.takeException(), isNull);
  });
}
