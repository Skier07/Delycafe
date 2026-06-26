import 'dart:async';

import 'package:delycafe/models/user.dart';
import 'package:delycafe/services/customer_api_service.dart';
import 'package:delycafe/services/user_profile_cache_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  AuthService({
    CustomerApiService? customerApiService,
    UserProfileCacheService? profileCacheService,
  })  : _customerApiService = customerApiService ?? CustomerApiService(),
        _profileCacheService = profileCacheService ?? UserProfileCacheService() {
    _loadSavedSession();
  }

  final CustomerApiService _customerApiService;
  final UserProfileCacheService _profileCacheService;

  static const String _savedPhoneKey = 'saved_user_phone';
  static const Duration _profileRequestTimeout = Duration(seconds: 8);

  final Completer<void> _sessionReadyCompleter = Completer<void>();

  String? _generatedCode;
  User? _currentUser;
  bool _isLoadingSession = true;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoadingSession => _isLoadingSession;

  Future<void> waitForSessionReady() => _sessionReadyCompleter.future;

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

    unawaited(signInWithPhone(phone));

    return true;
  }

  Future<void> signInWithPhone(String phone) async {
    final normalizedPhone = _normalizePhone(phone);

    _currentUser = User(
      phone: normalizedPhone,
    );

    notifyListeners();

    await _savePhone(normalizedPhone);
    await loadCustomerProfile(normalizedPhone);
  }

  Future<void> loadCustomerProfile(String phone) async {
    final normalizedPhone = _normalizePhone(phone);

    try {
      final user = await _customerApiService
          .fetchProfile(
            phone: normalizedPhone,
          )
          .timeout(_profileRequestTimeout);

      _currentUser = user;

      await _savePhone(user.phone);
      await _profileCacheService.save(user);

      notifyListeners();
    } catch (error) {
      debugPrint('Ошибка загрузки профиля клиента: $error');

      final cachedUser = _profileCacheService.read(normalizedPhone);

      if (cachedUser != null) {
        _currentUser = cachedUser;
        notifyListeners();
      }
    }
  }

  Future<void> updateProfileName(String name) async {
    final user = _currentUser;

    if (user == null) {
      return;
    }

    final updatedUser = await _customerApiService.updateProfile(
      phone: user.phone,
      name: name,
    );

    _currentUser = updatedUser;
    await _profileCacheService.save(updatedUser);
    notifyListeners();
  }

  Future<void> refreshCurrentUser() async {
    final user = _currentUser;

    if (user == null) return;

    await loadCustomerProfile(user.phone);
  }

  Future<void> logout() async {
    final phone = _currentUser?.phone;

    _currentUser = null;
    _generatedCode = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedPhoneKey);

    if (phone != null && phone.trim().isNotEmpty) {
      await _profileCacheService.clear(phone);
    }

    notifyListeners();
  }

  Future<void> _loadSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPhone = prefs.getString(_savedPhoneKey);

      if (savedPhone != null && savedPhone.trim().isNotEmpty) {
        final normalizedPhone = _normalizePhone(savedPhone);
        final cachedUser = _profileCacheService.read(normalizedPhone);

        _currentUser = cachedUser ?? User(phone: normalizedPhone);

        notifyListeners();

        await loadCustomerProfile(normalizedPhone);
      }
    } catch (error) {
      debugPrint('Ошибка восстановления сессии: $error');
    } finally {
      _isLoadingSession = false;

      if (!_sessionReadyCompleter.isCompleted) {
        _sessionReadyCompleter.complete();
      }

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
