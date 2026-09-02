import 'dart:io';

import 'package:delycafe/data/hive/hive_boxes.dart';
import 'package:delycafe/screens/splash_screen.dart';
import 'package:delycafe/services/address_service.dart';
import 'package:delycafe/services/auth_service.dart';
import 'package:delycafe/services/cart_service.dart';
import 'package:delycafe/services/legal_consent_service.dart';
import 'package:delycafe/services/order_service.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

Widget buildTestApp({
  required AuthService authService,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthService>.value(value: authService),
      ChangeNotifierProvider(create: (_) => CartService()),
      ChangeNotifierProvider(create: (_) => OrderService()),
      ChangeNotifierProvider(create: (_) => AddressService()),
      ChangeNotifierProvider(create: (_) => LegalConsentService()),
    ],
    child: const MaterialApp(
      home: SplashScreen(),
    ),
  );
}

Future<void> initTestEnvironment() async {
  final tempDir = Directory.systemTemp.createTempSync('delycafe_test_hive');
  Hive.init(tempDir.path);

  await Hive.openBox<Map>(HiveBoxes.catalog);
  await Hive.openBox(HiveBoxes.user);
  await Hive.openBox(HiveBoxes.orders);
  await Hive.openBox(HiveBoxes.local);
}
