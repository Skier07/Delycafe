import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PinCredentialService {
  PinCredentialService({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  static const int pinLength = 4;

  final FlutterSecureStorage _storage;

  String _pinHashKey(String phone) => 'pin_hash_${_phoneKey(phone)}';

  String _biometricKey(String phone) => 'pin_biometric_${_phoneKey(phone)}';

  String _phoneKey(String phone) {
    return phone.replaceAll(RegExp(r'\D'), '');
  }

  String hashPin(String phone, String pin) {
    final normalizedPhone = _phoneKey(phone);
    final payload = utf8.encode('$normalizedPhone:$pin');
    return sha256.convert(payload).toString();
  }

  Future<bool> hasPin(String phone) async {
    final value = await _storage.read(key: _pinHashKey(phone));
    return value != null && value.isNotEmpty;
  }

  Future<void> savePin(String phone, String pin) async {
    await _storage.write(
      key: _pinHashKey(phone),
      value: hashPin(phone, pin),
    );
  }

  Future<bool> verifyPin(String phone, String pin) async {
    final stored = await _storage.read(key: _pinHashKey(phone));

    if (stored == null || stored.isEmpty) {
      return false;
    }

    return stored == hashPin(phone, pin);
  }

  Future<bool> isBiometricEnabled(String phone) async {
    final value = await _storage.read(key: _biometricKey(phone));
    return value == '1';
  }

  Future<void> setBiometricEnabled(String phone, bool enabled) async {
    await _storage.write(
      key: _biometricKey(phone),
      value: enabled ? '1' : '0',
    );
  }

  Future<void> clearCredentials(String phone) async {
    await _storage.delete(key: _pinHashKey(phone));
    await _storage.delete(key: _biometricKey(phone));
  }
}
