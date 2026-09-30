import 'package:delycafe/services/glass_settings.dart';
import 'package:delycafe/ui/components/glass/glass_back_button.dart';
import 'package:delycafe/ui/components/glass/shader_glass_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Android back button uses blur even with refraction enabled',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await GlassSettings.instance.setEnabled(true);
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Center(
                child: GlassBackButton(
                    lightBackground: true, onPressed: () => taps++)))));
    expect(
        tester
            .widget<ShaderGlassContainer>(find.byType(ShaderGlassContainer))
            .forceSimpleBlur,
        isTrue);
    expect(find.byType(LiquidGlass), findsNothing);
    expect(find.byType(BackdropFilter), findsOneWidget);
    await tester.tap(find.byType(GlassBackButton));
    await tester.pumpAndSettle();
    expect(taps, 1);
    await GlassSettings.instance.setEnabled(false);
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
