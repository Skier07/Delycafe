import 'dart:convert';

import 'package:http/http.dart' as http;

class OrderCreateResult {
  final int id;
  final int totalPrice;
  final int paymentAmount;
  final String paymentStatus;
  final String paymentType;
  final String paymentUrl;

  const OrderCreateResult({
    required this.id,
    required this.totalPrice,
    required this.paymentAmount,
    required this.paymentStatus,
    required this.paymentType,
    required this.paymentUrl,
  });

  factory OrderCreateResult.fromJson(Map<String, dynamic> json) {
    return OrderCreateResult(
      id: _toInt(json['id']),
      totalPrice: _toInt(json['total_price']),
      paymentAmount: _toInt(json['payment_amount']),
      paymentStatus: json['payment_status']?.toString() ?? '',
      paymentType: json['payment_type']?.toString() ?? '',
      paymentUrl: json['payment_url']?.toString() ?? '',
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;

    return 0;
  }
}

class OrderApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  Future<OrderCreateResult> createOrder({
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
        'Ошибка оформления заказа: ${response.statusCode}\n'
        '${utf8.decode(response.bodyBytes)}',
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Неверный формат ответа заказа');
    }

    return OrderCreateResult.fromJson(decoded);
  }
}
