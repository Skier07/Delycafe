import 'dart:convert';

import 'package:delycafe/config/api_config.dart';
import 'package:http/http.dart' as http;

class OrderCreateResult {
  final int id;
  final int totalPrice;
  final int paymentAmount;
  final String paymentStatus;
  final String paymentType;
  final String paymentUrl;
  final String? paymentError;

  const OrderCreateResult({
    required this.id,
    required this.totalPrice,
    required this.paymentAmount,
    required this.paymentStatus,
    required this.paymentType,
    required this.paymentUrl,
    this.paymentError,
  });

  factory OrderCreateResult.fromJson(Map<String, dynamic> json) {
    return OrderCreateResult(
      id: _toInt(json['id']),
      totalPrice: _toInt(json['total_price']),
      paymentAmount: _toInt(json['payment_amount']),
      paymentStatus: json['payment_status']?.toString() ?? '',
      paymentType: json['payment_type']?.toString() ?? '',
      paymentUrl: json['payment_url']?.toString() ?? '',
      paymentError: json['payment_error']?.toString(),
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
  Future<OrderCreateResult> createOrder({
    required String phone,
    required String customerName,
    required String deliveryType,
    required String address,
    String addressLocality = '',
    String addressEntrance = '',
    String addressFloor = '',
    String addressApartment = '',
    required String deliveryTimeType,
    required String deliveryTime,
    required String paymentType,
    required String comment,
    required List<Map<String, dynamic>> items,
    int bonusSpent = 0,
  }) async {
    final uri = ApiConfig.uri('/api/orders/');

    final body = {
      'phone': phone,
      'customer_name': customerName,
      'delivery_type': deliveryType,
      'address': address,
      'address_locality': addressLocality,
      'address_entrance': addressEntrance,
      'address_floor': addressFloor,
      'address_apartment': addressApartment,
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
