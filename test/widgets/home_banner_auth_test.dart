import 'package:delycafe/models/user.dart';
import 'package:delycafe/screens/home_screen.dart';
import 'package:delycafe/services/auth_service.dart';
import 'package:delycafe/services/cart_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_app.dart';

class BannerAuth extends AuthService {
  User? user;
  @override
  User? get currentUser => user;

  void setUser(User? value) {
    user = value;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await initTestEnvironment();
  });

  testWidgets('right banner controls follow login and logout', (tester) async {
    final auth = BannerAuth();
    await tester.runAsync(auth.waitForSessionReady);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: auth),
        ChangeNotifierProvider(create: (_) => CartService()),
      ],
      child: MaterialApp(
          home: Scaffold(
              body: SizedBox(
                  height: 240,
                  child: HomeBanner(
                      screenHeight: 900,
                      cartIconKey: GlobalKey(),
                      onMenuPressed: () {},
                      onAccountPressed: () {})))),
    ));
    expect(find.text('ВОЙТИ'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.text_justify), findsNothing);
    expect(find.byIcon(CupertinoIcons.cart), findsNothing);

    auth.setUser(const User(phone: '79000000000'));
    await tester.pump();
    expect(find.text('ВОЙТИ'), findsNothing);
    expect(find.byIcon(CupertinoIcons.text_justify), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.cart), findsOneWidget);

    auth.setUser(null);
    await tester.pump();
    expect(find.text('ВОЙТИ'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.text_justify), findsNothing);
    expect(find.byIcon(CupertinoIcons.cart), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
  });
}
