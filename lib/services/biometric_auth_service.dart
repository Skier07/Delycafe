import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricAuthService {
  BiometricAuthService({
    LocalAuthentication? localAuth,
  }) : _localAuth = localAuth ?? LocalAuthentication();

  final LocalAuthentication _localAuth;

  Future<bool> isDeviceSupported() async {
    try {
      return await _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  /// Биометрия реально доступна: устройство поддерживает и отпечаток/Face ID настроен.
  Future<bool> isBiometricReady() async {
    try {
      if (!await isDeviceSupported()) {
        return false;
      }

      if (!await canCheckBiometrics()) {
        return false;
      }

      final biometrics = await _localAuth.getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate({
    String reason = 'Подтвердите вход в DelyCafe',
  }) async {
    try {
      if (!await isBiometricReady()) {
        return false;
      }

      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: false,
          biometricOnly: true,
        ),
      );
    } on PlatformException catch (error) {
      if (_isUserCancellation(error)) {
        return false;
      }

      debugPrint('Биометрия недоступна: ${error.code} ${error.message}');
      return false;
    }
  }

  bool _isUserCancellation(PlatformException error) {
    const cancelCodes = {
      'UserCancel',
      'UserCanceled',
      'userCanceled',
      'canceled',
      'cancelled',
      'auth_in_progress',
      'AuthenticationCanceled',
    };

    return cancelCodes.contains(error.code);
  }
}
