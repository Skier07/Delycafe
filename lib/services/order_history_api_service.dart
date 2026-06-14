import 'dart:convert';

import 'package:delycafe/models/order.dart';
import 'package:http/http.dart' as http;

class OrderHistoryApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.delycafe.ru',
  );

  Uri _uri(
    String path, {
    Map<String, String>? queryParameters,
  }) {
    final cleanBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    return Uri.parse('$cleanBaseUrl$path').replace(
      queryParameters: queryParameters,
    );
  }

  Future<List<Order>> fetchOrders({
    required String phone,
  }) async {
    final response = await http.get(
      _uri(
        '/api/orders/history/',
        queryParameters: {
          'phone': phone,
        },
      ),
    );

    final decodedBody = utf8.decode(response.bodyBytes);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(decodedBody);
    }

    final data = jsonDecode(decodedBody);

    if (data is! List) {
      throw Exception('Сервер вернул неожиданный формат истории заказов.');
    }

    return data.whereType<Map<String, dynamic>>().map(Order.fromJson).toList();
  }
}
