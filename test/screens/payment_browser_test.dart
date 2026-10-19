import 'package:delycafe/screens/order_payment_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  const url =
      'https://payment.alfabank.ru/payment/?mdOrder=test&returnUrl=https%3A%2F%2Fapi.delycafe.ru%2F';

  testWidgets('card session starts in browser and retains complete gateway URL',
      (tester) async {
    final launches = <Map<dynamic, dynamic>>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      if (call.method == 'launch') {
        launches.add(call.arguments as Map<dynamic, dynamic>);
        return true;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    await tester.pumpWidget(const MaterialApp(
        home: OrderPaymentScreen(
            orderId: 123,
            paymentUrl: url,
            paymentAmount: 1000,
            paymentType: 'card')));
    await tester.pumpAndSettle();
    expect(launches, hasLength(1));
    expect(launches.single['url'], url);
    expect(launches.single['useWebView'], isFalse);
    expect(launches.single['useSafariVC'], isFalse);
    expect(find.text('Оплата на странице банка'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
