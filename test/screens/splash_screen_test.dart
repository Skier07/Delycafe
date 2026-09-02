import 'dart:async';

import 'package:delycafe/root_screen.dart';
import 'package:delycafe/services/auth_service.dart';
import 'package:delycafe/services/catalog_sync_service.dart';
import 'package:flutter/material.dart';
import '../test_app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Имитирует зависание восстановления сессии (сценарий 1.4.2).
class HangingAuthService extends AuthService {
  @override
  Future<void> waitForSessionReady() {
    return Completer<void>().future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initTestEnvironment();
  });

  tearDown(() {
    CatalogSyncService.instance.onAppBackground();
  });

  testWidgets('opens home when session restore hangs', (tester) async {
    final auth = HangingAuthService();

    await tester.pumpWidget(buildTestApp(authService: auth));

    expect(find.byType(RootScreen), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(RootScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    CatalogSyncService.instance.onAppBackground();
  });
}
