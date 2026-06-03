import 'dart:convert';

import 'package:http/http.dart' as http;

class OrderApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  Future<int> createOrder({
    required String phone,
    required String customerName,
    required String deliveryType,
    required String address,
    required String deliveryTimeType,
    required String deliveryTime,
    required String paymentType,
    required String comment,
    required List<Map<String, dynamic>> items,
    int bonusSpent = 0,
  }) async {
    final uri = Uri.parse('$baseUrl/api/orders/');

    final body = {
      'phone': phone,
      'customer_name': customerName,
      'delivery_type': deliveryType,
      'address': address,
      'delivery_time_type': deliveryTimeType,
      'delivery_time': deliveryTime,
      'payment_type': paymentType,
      'comment': comment,
      'bonus_spent': bonusSpent,
      'items': items,
    };

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 201) {
      throw Exception(
        'Ошибка оформления заказа: ${response.statusCode}\n${utf8.decode(response.bodyBytes)}',
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));

    return decoded['id'] as int;
  }
}
