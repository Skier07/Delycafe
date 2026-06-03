import 'package:delycafe/models/user.dart';
import 'package:delycafe/services/customer_api_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  final CustomerApiService _customerApiService = CustomerApiService();

  static const String _savedPhoneKey = 'saved_user_phone';

  String? _generatedCode;
  User? _currentUser;
  bool _isLoadingSession = true;

  AuthService() {
    _loadSavedSession();
  }

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoadingSession => _isLoadingSession;

  void senCode(String phone) {
    _generatedCode = '1234'; // временно
    debugPrint('Отправить код: $_generatedCode');
  }

  void sendCode(String phone) {
    senCode(phone);
  }

  bool verifyCode(String phone, String code) {
    if (code != _generatedCode) {
      return false;
    }

    final normalizedPhone = _normalizePhone(phone);

    _currentUser = User(
      phone: normalizedPhone,
    );

    notifyListeners();

    _savePhone(normalizedPhone);
    loadCustomerProfile(normalizedPhone);

    return true;
  }

  Future<void> loadCustomerProfile(String phone) async {
    try {
      final normalizedPhone = _normalizePhone(phone);

      final user = await _customerApiService.fetchProfile(
        phone: normalizedPhone,
      );

      _currentUser = user;

      await _savePhone(user.phone);

      notifyListeners();
    } catch (error) {
      debugPrint('Ошибка загрузки профиля клиента: $error');
    }
  }

  Future<void> refreshCurrentUser() async {
    final user = _currentUser;

    if (user == null) return;

    await loadCustomerProfile(user.phone);
  }

  Future<void> logout() async {
    _currentUser = null;
    _generatedCode = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedPhoneKey);

    notifyListeners();
  }

  Future<void> _loadSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPhone = prefs.getString(_savedPhoneKey);

      if (savedPhone != null && savedPhone.trim().isNotEmpty) {
        final normalizedPhone = _normalizePhone(savedPhone);

        _currentUser = User(
          phone: normalizedPhone,
        );

        notifyListeners();

        await loadCustomerProfile(normalizedPhone);
      }
    } catch (error) {
      debugPrint('Ошибка восстановления сессии: $error');
    } finally {
      _isLoadingSession = false;
      notifyListeners();
    }
  }

  Future<void> _savePhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _savedPhoneKey,
      _normalizePhone(phone),
    );
  }

  String _normalizePhone(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');

    if (digits.length == 11 && digits.startsWith('8')) {
      digits = '7${digits.substring(1)}';
    }

    if (digits.length == 10) {
      digits = '7$digits';
    }

    if (digits.length == 11 && digits.startsWith('7')) {
      return '+$digits';
    }

    return value;
  }
}
