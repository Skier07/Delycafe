import 'dart:convert';
import 'dart:math';

import 'package:delycafe/config/api_config.dart';
import 'package:delycafe/exceptions/auth_required_exception.dart';
import 'package:delycafe/services/api_auth_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class OrderCreateResult {
  final int id;
  final int totalPrice;
  final int paymentAmount;
  final String paymentStatus;
  final String paymentType;
  final String status;
  final String paymentUrl;
  final String? paymentError;
  final String orderAccessToken;

  const OrderCreateResult({
    required this.id,
    required this.totalPrice,
    required this.paymentAmount,
    required this.paymentStatus,
    required this.paymentType,
    required this.paymentUrl,
    this.paymentError,
    this.orderAccessToken = '',
    this.status = '',
  });

  factory OrderCreateResult.fromJson(Map<String, dynamic> json) {
    return OrderCreateResult(
      id: _toInt(json['id']),
      totalPrice: _toInt(json['total_price']),
      paymentAmount: _toInt(json['payment_amount']),
      paymentStatus: json['payment_status']?.toString() ?? '',
      paymentType: json['payment_type']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      paymentUrl: json['payment_url']?.toString() ?? '',
      paymentError: json['payment_error']?.toString(),
      orderAccessToken: json['order_access_token']?.toString() ?? '',
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
  static const _storage = FlutterSecureStorage();
  static const _pendingKey = 'pending_checkout_operation';
  static Future<void> clearPendingCheckout() =>
      _storage.delete(key: _pendingKey);

  Future<String> _requestKey(String body) async {
    final saved = await _storage.read(key: _pendingKey);
    if (saved != null) {
      try {
        final data = jsonDecode(saved);
        if (data is Map && data['body'] == body && data['key'] is String) {
          return data['key'] as String;
        }
      } catch (_) {/* Replace an invalid local draft. */}
    }
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex =
        bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    final key =
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    await _storage.write(
        key: _pendingKey, value: jsonEncode({'key': key, 'body': body}));
    return key;
  }

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
    bool termsAccepted = false,
    bool privacyAccepted = false,
    bool pdConsentAccepted = false,
    bool marketingConsentAccepted = false,
  }) async {
    final uri = ApiConfig.uri('/api/orders/');

    final payload = <String, dynamic>{
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
      'terms_accepted': termsAccepted,
      'privacy_accepted': privacyAccepted,
      'pd_consent_accepted': pdConsentAccepted,
      'marketing_consent_accepted': marketingConsentAccepted,
    };
    payload['checkout_key'] = await _requestKey(jsonEncode(payload));
    final body = jsonEncode(payload);

    final response = await http
        .post(
          uri,
          headers: await ApiAuthStorage.instance.authorizedHeaders(
            jsonContentType: true,
          ),
          body: body,
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode == 401 || response.statusCode == 403) {
      await ApiAuthStorage.instance.clearCustomerSession();

      throw const AuthRequiredException();
    }

    if (response.statusCode == 400) await clearPendingCheckout();
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
