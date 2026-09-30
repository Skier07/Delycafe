import 'package:delycafe/services/glass_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('Android defaults to blur; iOS defaults to refraction', () async {
    final settings = GlassSettings();
    await settings.load();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(settings.enabled, isFalse);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(settings.enabled, isTrue);
    settings.dispose();
  });
  test('choice notifies immediately and survives reload', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final settings = GlassSettings();
    var notifications = 0;
    settings.addListener(() => notifications++);
    await settings.setEnabled(true);
    expect(settings.enabled, isTrue);
    expect(notifications, 1);
    final restored = GlassSettings();
    await restored.load();
    expect(restored.enabled, isTrue);
    await restored.setEnabled(false);
    await settings.load();
    expect(settings.enabled, isFalse);
    settings.dispose();
    restored.dispose();
  });
}
