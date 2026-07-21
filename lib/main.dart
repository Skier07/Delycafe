import 'package:delycafe/data/hive/hive_init.dart';
import 'package:delycafe/screens/splash_screen.dart';
import 'package:delycafe/services/address_service.dart';
import 'package:delycafe/services/api_auth_storage.dart';
import 'package:delycafe/services/auth_service.dart';
import 'package:delycafe/services/cart_service.dart';
import 'package:delycafe/services/legal_consent_service.dart';
import 'package:delycafe/services/order_service.dart';
import 'package:delycafe/utils/app_timezone.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  initializeAppTimezone();

  await initHive();
  await ApiAuthStorage.instance.load();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthService(),
        ),
        ChangeNotifierProvider(
          create: (_) => CartService(),
        ),
        ChangeNotifierProvider(
          create: (_) => OrderService(),
        ),
        ChangeNotifierProvider(
          create: (_) => AddressService(),
        ),
        ChangeNotifierProvider(
          create: (_) => LegalConsentService(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}
