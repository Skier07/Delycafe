import 'package:delycafe/models/order.dart';
import 'package:flutter/material.dart';

class OrderService extends ChangeNotifier {
  final List<Order> _orders = [];

  List<Order> get orders => _orders;

  void addOrder(Order order) {
    _orders.insert(0, order); // новые сверху
    notifyListeners();
  }
}
