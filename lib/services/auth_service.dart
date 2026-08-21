import 'dart:async';

import 'package:delycafe/exceptions/auth_required_exception.dart';
import 'package:delycafe/models/user.dart';
import 'package:delycafe/services/api_auth_storage.dart';
import 'package:delycafe/services/customer_api_service.dart';
import 'package:delycafe/services/user_profile_cache_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  AuthService({
    CustomerApiService? customerApiService,
    UserProfileCacheService? profileCacheService,
  })  : _customerApiService = customerApiService ?? CustomerApiService(),
        _profileCacheService =
            profileCacheService ?? UserProfileCacheService() {
    _loadSavedSession();
  }

  final CustomerApiService _customerApiService;
  final UserProfileCacheService _profileCacheService;

  static const String _savedPhoneKey = 'saved_user_phone';
  static const String _otpSessionIdKey = 'otp_session_id';
  static const Duration _profileRequestTimeout = Duration(seconds: 8);
  static const FlutterSecureStorage _legacyPinStorage = FlutterSecureStorage();

  final Completer<void> _sessionReadyCompleter = Completer<void>();

  int? _otpSessionId;
  User? _currentUser;
  String? _registeredPhone;
  bool _isLoadingSession = true;
  bool _needsAccessTokenRefresh = false;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoadingSession => _isLoadingSession;
  bool get needsAccessTokenRefresh =>
      _needsAccessTokenRefresh && _registeredPhone != null;
  int? get otpSessionId => _otpSessionId;
  String? get registeredPhone => _registeredPhone;

  Future<void> waitForSessionReady() => _sessionReadyCompleter.future;

  Future<void> sendCode(String phone) async {
    final result = await _customerApiService.sendOtp(phone: phone);

    _otpSessionId = result.sessionId;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_otpSessionIdKey, result.sessionId);
  }

  Future<OtpStatusResult> fetchOtpStatus(String phone) async {
    final sessionId = _otpSessionId ?? await _readSavedSessionId();

    if (sessionId == null) {
      throw Exception('Сессия не найдена. Запросите код повторно.');
    }

    return _customerApiService.fetchOtpStatus(
      sessionId: sessionId,
      phone: phone,
    );
  }

  Future<bool> completeVerifiedOtp(
    String phone, {
    void Function(String message)? onProgress,
  }) async {
    final sessionId = _otpSessionId ?? await _readSavedSessionId();

    if (sessionId == null) {
      throw Exception('Сессия не найдена. Запросите код повторно.');
    }

    onProgress?.call('Входим в приложение...');

    final result = await _customerApiService.completeOtpSession(
      sessionId: sessionId,
      phone: phone,
    );

    if (!result.verified) {
      return false;
    }

    await _saveAuthSession(result);
    await signInAfterOtp(result.phone.isNotEmpty ? result.phone : phone);
    await _clearOtpSession();
    return true;
  }

  Future<bool> verifyCode(
    String phone,
    String code, {
    void Function(String message)? onProgress,
  }) async {
    final sessionId = _otpSessionId ?? await _readSavedSessionId();

    if (sessionId == null) {
      throw Exception('Сессия не найдена. Запросите код повторно.');
    }

    try {
      final result = await _customerApiService.verifyOtp(
        sessionId: sessionId,
        phone: phone,
        code: code,
      );

      if (!result.verified) {
        return false;
      }

      await _saveAuthSession(result);
      await signInAfterOtp(result.phone.isNotEmpty ? result.phone : phone);
      await _clearOtpSession();
      return true;
    } on OtpApiException catch (error) {
      if (error.code == 'pending') {
        onProgress?.call('Подтверждаем вход...');
        await _waitForOtpVerification(
          phone: phone,
          sessionId: sessionId,
          code: code,
        );
        return true;
      }

      throw Exception(error.message);
    }
  }

  Future<void> _waitForOtpVerification({
    required String phone,
    required int sessionId,
    required String code,
  }) async {
    const maxAttempts = 30;
    const pollInterval = Duration(seconds: 2);

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (attempt > 0) {
        await Future.delayed(pollInterval);
      }

      final status = await _customerApiService.fetchOtpStatus(
        sessionId: sessionId,
        phone: phone,
      );

      if (status.verified) {
        final result = await _customerApiService.verifyOtp(
          sessionId: sessionId,
          phone: phone,
          code: code,
        );

        await _saveAuthSession(result);
        await signInAfterOtp(
          result.phone.isNotEmpty ? result.phone : phone,
        );
        await _clearOtpSession();
        return;
      }

      if (status.status == 'failed') {
        throw Exception('Верификация не пройдена. Запросите код заново.');
      }
    }

    throw Exception('Не удалось подтвердить вход. Запросите код заново.');
  }

  Future<void> signInAfterOtp(String phone) async {
    final normalizedPhone = _normalizePhone(phone);

    _registeredPhone = normalizedPhone;
    _currentUser = User(phone: normalizedPhone);
    notifyListeners();

    await _clearLegacyPin(normalizedPhone);
    await _savePhone(normalizedPhone);
    await loadCustomerProfile(normalizedPhone);
  }

  Future<void> signInWithPhone(String phone) async {
    final normalizedPhone = _normalizePhone(phone);

    _registeredPhone = normalizedPhone;
    _currentUser ??= User(phone: normalizedPhone);
    notifyListeners();

    await _savePhone(normalizedPhone);
    await loadCustomerProfile(normalizedPhone);
  }

  Future<void> loadCustomerProfile(String phone) async {
    final normalizedPhone = _normalizePhone(phone);

    if (!ApiAuthStorage.instance.hasCustomerSession) {
      _needsAccessTokenRefresh = true;
      final cachedUser = _profileCacheService.read(normalizedPhone);

      if (cachedUser != null) {
        _currentUser = cachedUser;
        notifyListeners();
      }

      return;
    }

    try {
      final user = await _customerApiService
          .fetchProfile(
            phone: normalizedPhone,
          )
          .timeout(_profileRequestTimeout);

      _currentUser = user;
      _needsAccessTokenRefresh = false;

      await _savePhone(user.phone);
      await _profileCacheService.save(user);
      notifyListeners();
    } on AuthRequiredException {
      _needsAccessTokenRefresh = true;

      final cachedUser = _profileCacheService.read(normalizedPhone);

      if (cachedUser != null) {
        _currentUser = cachedUser;
        notifyListeners();
      }
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

    if (!ApiAuthStorage.instance.hasCustomerSession) {
      _needsAccessTokenRefresh = true;
      notifyListeners();
      throw const AuthRequiredException(
        'Сессия истекла. Войдите по SMS для сохранения изменений.',
      );
    }

    final updatedUser = await _customerApiService.updateProfile(
      phone: user.phone,
      name: name,
    );

    _currentUser = updatedUser;
    _needsAccessTokenRefresh = false;
    await _profileCacheService.save(updatedUser);
    notifyListeners();
  }

  void markAccessTokenRefreshRequired() {
    _needsAccessTokenRefresh = true;
    notifyListeners();
  }

  void clearAccessTokenRefreshRequired() {
    _needsAccessTokenRefresh = false;
    notifyListeners();
  }

  Future<void> refreshCurrentUser() async {
    final phone = _currentUser?.phone ?? _registeredPhone;

    if (phone == null || phone.trim().isEmpty) return;

    await loadCustomerProfile(phone);
  }

  Future<void> synchronizeBonusBalance(int bonusBalance) async {
    final user = _currentUser;
    if (user == null) return;

    final normalizedBalance = bonusBalance < 0 ? 0 : bonusBalance;
    if (user.bonusBalance == normalizedBalance) return;

    final updatedUser = user.copyWith(bonusBalance: normalizedBalance);
    _currentUser = updatedUser;
    await _profileCacheService.save(updatedUser);
    notifyListeners();
  }

  Future<void> beginSmsRecovery() async {
    await ApiAuthStorage.instance.revokeRefreshToken();
    await ApiAuthStorage.instance.clearCustomerSession();
    _currentUser = null;
    _needsAccessTokenRefresh = true;
    notifyListeners();
  }

  Future<void> resetAccountAccess() async {
    final phone = _registeredPhone ?? _currentUser?.phone;

    if (phone != null && phone.trim().isNotEmpty) {
      await _clearLegacyPin(phone);
      await _profileCacheService.clear(phone);
    }

    await logout();
  }

  Future<void> sendAccountDeletionCode(String phone) async {
    await sendCode(phone);
  }

  Future<void> deleteAccount({
    required String phone,
    required String code,
  }) async {
    final sessionId = _otpSessionId ?? await _readSavedSessionId();

    if (sessionId == null) {
      throw Exception('Сессия не найдена. Запросите код повторно.');
    }

    await _customerApiService.deleteAccount(
      phone: phone,
      sessionId: sessionId,
      code: code,
    );

    await logout();
    await _clearOtpSession();
  }

  Future<void> logout() async {
    final phone = _registeredPhone ?? _currentUser?.phone;

    _currentUser = null;
    _otpSessionId = null;
    _registeredPhone = null;
    _needsAccessTokenRefresh = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedPhoneKey);
    await prefs.remove(_otpSessionIdKey);

    if (phone != null && phone.trim().isNotEmpty) {
      await _clearLegacyPin(phone);
      await _profileCacheService.clear(phone);
    }

    await ApiAuthStorage.instance.revokeRefreshToken();
    await ApiAuthStorage.instance.clearAll();

    notifyListeners();
  }

  Future<void> _loadSavedSession() async {
    try {
      await ApiAuthStorage.instance.load();

      final prefs = await SharedPreferences.getInstance();
      final savedPhone = prefs.getString(_savedPhoneKey);
      _otpSessionId = prefs.getInt(_otpSessionIdKey);

      if (savedPhone != null && savedPhone.trim().isNotEmpty) {
        final normalizedPhone = _normalizePhone(savedPhone);
        _registeredPhone = normalizedPhone;
        await _clearLegacyPin(normalizedPhone);

        final cachedUser = _profileCacheService.read(normalizedPhone);
        _currentUser = cachedUser ?? User(phone: normalizedPhone);
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

  Future<void> _saveAuthSession(OtpVerifyResult result) async {
    if (result.accessToken.isEmpty) return;

    if (result.refreshToken.isNotEmpty) {
      await ApiAuthStorage.instance.saveSession(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
      );
    } else {
      await ApiAuthStorage.instance.saveAccessToken(result.accessToken);
    }

    _needsAccessTokenRefresh = false;
  }

  Future<void> _clearLegacyPin(String phone) async {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;

    try {
      await _legacyPinStorage.delete(key: 'pin_hash_$digits');
      await _legacyPinStorage.delete(key: 'pin_biometric_$digits');
    } catch (error) {
      debugPrint('Не удалось удалить старый PIN: $error');
    }
  }

  Future<int?> _readSavedSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_otpSessionIdKey);
  }

  Future<void> _clearOtpSession() async {
    _otpSessionId = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_otpSessionIdKey);
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
