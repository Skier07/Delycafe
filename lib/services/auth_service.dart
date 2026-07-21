import 'dart:async';

import 'package:delycafe/models/user.dart';
import 'package:delycafe/services/biometric_auth_service.dart';
import 'package:delycafe/services/customer_api_service.dart';
import 'package:delycafe/services/pin_credential_service.dart';
import 'package:delycafe/services/user_profile_cache_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  AuthService({
    CustomerApiService? customerApiService,
    UserProfileCacheService? profileCacheService,
    PinCredentialService? pinCredentialService,
    BiometricAuthService? biometricAuthService,
  })  : _customerApiService = customerApiService ?? CustomerApiService(),
        _profileCacheService = profileCacheService ?? UserProfileCacheService(),
        _pinCredentialService = pinCredentialService ?? PinCredentialService(),
        _biometricAuthService = biometricAuthService ?? BiometricAuthService() {
    _loadSavedSession();
  }

  final CustomerApiService _customerApiService;
  final UserProfileCacheService _profileCacheService;
  final PinCredentialService _pinCredentialService;
  final BiometricAuthService _biometricAuthService;

  static const String _savedPhoneKey = 'saved_user_phone';
  static const String _otpSessionIdKey = 'otp_session_id';
  static const Duration _profileRequestTimeout = Duration(seconds: 8);

  final Completer<void> _sessionReadyCompleter = Completer<void>();

  int? _otpSessionId;
  User? _currentUser;
  String? _registeredPhone;
  bool _isLoadingSession = true;
  bool _isUnlocked = false;
  bool _guestSession = false;

  User? get currentUser => _isUnlocked ? _currentUser : null;
  bool get isLoggedIn => _currentUser != null && _isUnlocked;
  bool get isLoadingSession => _isLoadingSession;
  int? get otpSessionId => _otpSessionId;
  String? get registeredPhone => _registeredPhone;
  bool get needsPinUnlock =>
      !_guestSession &&
      _registeredPhone != null &&
      !_isUnlocked &&
      !_isLoadingSession;
  bool get needsPinSetup =>
      _currentUser != null &&
      !_isUnlocked &&
      _registeredPhone != null &&
      !_guestSession;

  Future<void> waitForSessionReady() => _sessionReadyCompleter.future;

  Future<void> sendCode(String phone) async {
    final result = await _customerApiService.sendOtp(phone: phone);

    _otpSessionId = result.sessionId;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_otpSessionIdKey, result.sessionId);
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

      await signInAfterOtp(result.phone.isNotEmpty ? result.phone : phone);
      await _clearOtpSession();
      return true;
    } on OtpApiException catch (error) {
      if (error.code == 'pending') {
        onProgress?.call('Подтверждаем вход...');
        await _waitForOtpVerification(
          phone: phone,
          sessionId: sessionId,
        );
        return true;
      }

      throw Exception(error.message);
    }
  }

  Future<void> _waitForOtpVerification({
    required String phone,
    required int sessionId,
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
        await signInAfterOtp(phone);
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

    _guestSession = false;
    _registeredPhone = normalizedPhone;
    _currentUser = User(phone: normalizedPhone);
    _isUnlocked = false;

    notifyListeners();

    await _savePhone(normalizedPhone);
    await loadCustomerProfile(normalizedPhone, keepLocked: true);
  }

  Future<void> completePinSetup({
    required String phone,
    required String pin,
    bool enableBiometric = false,
  }) async {
    final normalizedPhone = _normalizePhone(phone);

    await _pinCredentialService.savePin(normalizedPhone, pin);
    await _pinCredentialService.setBiometricEnabled(
      normalizedPhone,
      enableBiometric,
    );

    _registeredPhone = normalizedPhone;
    _guestSession = false;
    _isUnlocked = true;

    if (_currentUser == null) {
      _currentUser = User(phone: normalizedPhone);
    }

    await loadCustomerProfile(normalizedPhone);
  }

  Future<bool> unlockWithPin(String pin) async {
    final phone = _registeredPhone;

    if (phone == null) {
      return false;
    }

    final isValid = await _pinCredentialService.verifyPin(phone, pin);

    if (!isValid) {
      return false;
    }

    await _unlockRegisteredAccount(phone);
    return true;
  }

  Future<bool> unlockWithBiometric({String? phone}) async {
    final targetPhone = phone ?? _registeredPhone;

    if (targetPhone == null) {
      return false;
    }

    final biometricEnabled =
        await _pinCredentialService.isBiometricEnabled(targetPhone);

    if (!biometricEnabled) {
      return false;
    }

    final authenticated = await _biometricAuthService.authenticate();

    if (!authenticated) {
      return false;
    }

    await _unlockRegisteredAccount(targetPhone);
    return true;
  }

  Future<bool> canUseBiometricUnlock({String? phone}) async {
    final targetPhone = phone ?? _registeredPhone;

    if (targetPhone == null) {
      return false;
    }

    final enabled = await _pinCredentialService.isBiometricEnabled(targetPhone);

    if (!enabled) {
      return false;
    }

    return _biometricAuthService.isDeviceSupported();
  }

  void skipPinUnlockForSession() {
    _guestSession = true;
    _isUnlocked = false;
    _currentUser = null;
    notifyListeners();
  }

  Future<void> signInWithPhone(String phone) async {
    final normalizedPhone = _normalizePhone(phone);
    final hasPin = await _pinCredentialService.hasPin(normalizedPhone);
    final sameAccount = _normalizePhone(
          _registeredPhone ?? _currentUser?.phone ?? '',
        ) ==
        normalizedPhone;
    final preserveUnlock = _isUnlocked && sameAccount;

    _registeredPhone = normalizedPhone;
    _guestSession = false;
    _currentUser ??= User(phone: normalizedPhone);
    _isUnlocked = preserveUnlock || !hasPin;

    notifyListeners();

    await _savePhone(normalizedPhone);

    await loadCustomerProfile(
      normalizedPhone,
      keepLocked: hasPin && !preserveUnlock,
    );
  }

  Future<void> loadCustomerProfile(
    String phone, {
    bool keepLocked = false,
  }) async {
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

      if (!keepLocked) {
        _isUnlocked = true;
      }

      notifyListeners();
    } catch (error) {
      debugPrint('Ошибка загрузки профиля клиента: $error');

      final cachedUser = _profileCacheService.read(normalizedPhone);

      if (cachedUser != null) {
        _currentUser = cachedUser;

        if (!keepLocked) {
          _isUnlocked = true;
        }

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
    final phone = _currentUser?.phone ?? _registeredPhone;

    if (phone == null || phone.trim().isEmpty) return;

    final keepLocked = !_isUnlocked;

    await loadCustomerProfile(phone, keepLocked: keepLocked);
  }

  Future<void> resetAccountAccess() async {
    final phone = _registeredPhone ?? _currentUser?.phone;

    if (phone != null && phone.trim().isNotEmpty) {
      await _pinCredentialService.clearCredentials(phone);
      await _profileCacheService.clear(phone);
    }

    await logout(clearPin: false);
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

    await logout(clearPin: true);
    await _clearOtpSession();
  }

  Future<void> logout({bool clearPin = true}) async {
    final phone = _registeredPhone ?? _currentUser?.phone;

    _currentUser = null;
    _otpSessionId = null;
    _registeredPhone = null;
    _isUnlocked = false;
    _guestSession = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedPhoneKey);
    await prefs.remove(_otpSessionIdKey);

    if (phone != null && phone.trim().isNotEmpty) {
      if (clearPin) {
        await _pinCredentialService.clearCredentials(phone);
      }

      await _profileCacheService.clear(phone);
    }

    notifyListeners();
  }

  Future<void> _unlockRegisteredAccount(String phone) async {
    final normalizedPhone = _normalizePhone(phone);
    final cachedUser = _profileCacheService.read(normalizedPhone);

    _registeredPhone = normalizedPhone;
    _guestSession = false;
    _currentUser = cachedUser ?? User(phone: normalizedPhone);
    _isUnlocked = true;

    notifyListeners();

    await _savePhone(normalizedPhone);
    await loadCustomerProfile(normalizedPhone);
  }

  Future<void> _loadSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPhone = prefs.getString(_savedPhoneKey);
      _otpSessionId = prefs.getInt(_otpSessionIdKey);

      if (savedPhone != null && savedPhone.trim().isNotEmpty) {
        final normalizedPhone = _normalizePhone(savedPhone);
        final hasPin = await _pinCredentialService.hasPin(normalizedPhone);

        _registeredPhone = normalizedPhone;

        if (hasPin) {
          _isUnlocked = false;
          _currentUser = null;
        } else {
          final cachedUser = _profileCacheService.read(normalizedPhone);
          _currentUser = cachedUser ?? User(phone: normalizedPhone);
          _isUnlocked = true;
          await loadCustomerProfile(normalizedPhone);
        }
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
