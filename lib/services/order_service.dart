import 'dart:convert';

import 'package:delycafe/config/api_config.dart';
import 'package:delycafe/models/order.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class OrderService extends ChangeNotifier {
  final List<Order> _orders = [];

  bool _isLoading = false;
  String? _errorMessage;

  List<Order> get orders => List.unmodifiable(_orders);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadOrders({
    required String phone,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final uri = ApiConfig.uri(
        '/api/orders/history/',
        queryParameters: {
          'phone': phone,
        },
      );

      final response = await http.get(uri);
      final decodedBody = utf8.decode(response.bodyBytes);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(decodedBody);
      }

      final data = jsonDecode(decodedBody);

      if (data is! List) {
        throw Exception('Сервер вернул неожиданный формат истории заказов.');
      }

      final loadedOrders =
          data.whereType<Map<String, dynamic>>().map(Order.fromJson).toList();

      _orders
        ..clear()
        ..addAll(loadedOrders);
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _orders.clear();
    _errorMessage = null;
    notifyListeners();
  }
}
