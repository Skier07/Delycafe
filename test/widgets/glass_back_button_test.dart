import 'package:delycafe/ui/components/glass/glass_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('back control keeps its size and pops the route', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(navigatorKey: navigator,
        home: const Scaffold(body: Text('Каталог'))));
    navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) =>
        const Scaffold(body: Row(children: [GlassBackButton(lightBackground: true)]))));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(GlassBackButton)), const Size(44, 44));
    await tester.tap(find.byType(GlassBackButton));
    await tester.pumpAndSettle();
    expect(find.text('Каталог'), findsOneWidget);
    expect(find.byType(GlassBackButton), findsNothing);
  });

  testWidgets('payment callback is disabled while busy', (tester) async {
    var calls = 0;
    Widget page(bool busy) => MaterialApp(home: Scaffold(body: Center(
      child: GlassBackButton(busy: busy, onPressed: () => calls++))));
    await tester.pumpWidget(page(true));
    await tester.tap(find.byType(GlassBackButton));
    await tester.pump();
    expect(calls, 0);
    await tester.pumpWidget(page(false));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(GlassBackButton));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });
}
