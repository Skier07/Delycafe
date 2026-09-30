import 'dart:ui' as ui;

import 'package:delycafe/ui/components/glass/shader_glass_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

void main() {
  testWidgets('unsupported renderer keeps glass and a working button', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(
      child: ShaderGlassContainer(
        onPressed: () => taps++,
        padding: const EdgeInsets.all(8),
        child: const Icon(Icons.add, size: 24),
      ),
    ))));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(ShaderGlassContainer)), const Size(42, 42));
    if (!ui.ImageFilter.isShaderFilterSupported) {
      expect(find.byType(LiquidGlass), findsNothing);
      expect(find.byType(BackdropFilter), findsOneWidget);
    }
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nested icon button stays 48px and remains independently clickable', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Row(children: [
      SizedBox.square(dimension: 48, child: ShaderGlassContainer(
        padding: EdgeInsets.zero,
        child: IconButton(onPressed: () => taps++, icon: const Icon(Icons.arrow_back)),
      )),
      const Expanded(child: Text('Деликафе')),
    ]))));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(ShaderGlassContainer)), const Size(48, 48));
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('decorative badges do not create liquid layers', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Center(
      child: ShaderGlassContainer(child: Text('Бонусы')),
    ))));
    expect(find.byType(LiquidGlass), findsNothing);
  });
}
