import 'dart:convert';

import 'package:delycafe/config/api_config.dart';
import 'package:delycafe/services/api_auth_storage.dart';
import 'package:http/http.dart' as http;

class PaymentSession {
  final int orderId;
  final String paymentUrl;
  final int amount;

  const PaymentSession({
    required this.orderId,
    required this.paymentUrl,
    required this.amount,
  });

  factory PaymentSession.fromJson(Map<String, dynamic> json) {
    return PaymentSession(
      orderId: _toInt(json['order_id']),
      paymentUrl: json['payment_url']?.toString() ?? '',
      amount: _toInt(json['amount']),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;

    return 0;
  }
}

class PaymentStatusResult {
  final int orderId;
  final String paymentStatus;
  final String orderStatus;

  const PaymentStatusResult({
    required this.orderId,
    required this.paymentStatus,
    required this.orderStatus,
  });

  bool get isPaid => paymentStatus == 'paid';
  bool get isFailed => paymentStatus == 'failed';

  factory PaymentStatusResult.fromJson(Map<String, dynamic> json) {
    return PaymentStatusResult(
      orderId: PaymentSession._toInt(json['order_id']),
      paymentStatus: json['payment_status']?.toString() ?? '',
      orderStatus: json['status']?.toString() ?? '',
    );
  }
}

class PaymentApiService {
  Map<String, String> _paymentHeaders({bool jsonContentType = false}) {
    return ApiAuthStorage.instance.headers(
      includeOrderAccess: true,
      jsonContentType: jsonContentType,
    );
  }

  Future<PaymentSession> createPayment(int orderId) async {
    final uri = ApiConfig.uri('/api/payments/alfa/create/');

    final response = await http.post(
      uri,
      headers: _paymentHeaders(jsonContentType: true),
      body: jsonEncode({'order_id': orderId}),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Не удалось создать платёж: ${response.statusCode}\n'
        '${utf8.decode(response.bodyBytes)}',
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Неверный формат ответа платежа');
    }

    return PaymentSession.fromJson(decoded);
  }

  Future<PaymentStatusResult> checkStatus(int orderId) async {
    final uri = ApiConfig.uri(
      '/api/payments/alfa/status/',
      queryParameters: {
        'order_id': orderId.toString(),
      },
    );

    final response = await http.get(
      uri,
      headers: _paymentHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Не удалось проверить оплату: ${response.statusCode}\n'
        '${utf8.decode(response.bodyBytes)}',
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Неверный формат статуса оплаты');
    }

    return PaymentStatusResult.fromJson(decoded);
  }
}
