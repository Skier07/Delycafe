import 'dart:math';

import 'package:delycafe/models/user.dart';
import 'package:flutter/material.dart';

class AuthService extends ChangeNotifier {
  String? _generatedCode;
  User? _currentUser;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  void senCode(String phone) {
    _generatedCode = '1234'; //временно
    debugPrint('Отправить код: $_generatedCode');
  }

  bool verifyCode(String phone, String code) {
    if (code == _generatedCode) {
      final points = 10 + Random().nextInt(41);
      _currentUser = User(phone: phone, points: points);
      notifyListeners();
      return true;
    }
    return false;
  }

  void logout() {
    _currentUser = null;
    _generatedCode = null;
    notifyListeners();
  }
}
