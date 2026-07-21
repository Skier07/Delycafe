import 'dart:convert';

import 'package:delycafe/config/api_config.dart';
import 'package:delycafe/models/order.dart';
import 'package:delycafe/services/api_auth_storage.dart';
import 'package:http/http.dart' as http;

class OrderHistoryApiService {
  Future<List<Order>> fetchOrders() async {
    final response = await http.get(
      ApiConfig.uri('/api/orders/history/'),
      headers: ApiAuthStorage.instance.headers(),
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
