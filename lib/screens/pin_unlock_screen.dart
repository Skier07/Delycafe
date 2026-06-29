import 'package:delycafe/features/auth/auth_screen.dart';
import 'package:delycafe/root_screen.dart';
import 'package:delycafe/services/auth_service.dart';
import 'package:delycafe/services/pin_credential_service.dart';
import 'package:delycafe/ui/components/buttons/auth_button.dart';
import 'package:delycafe/widgets/auth/pin_code_input.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PinUnlockScreen extends StatefulWidget {
  const PinUnlockScreen({
    super.key,
    this.allowGuest = true,
  });

  final bool allowGuest;

  @override
  State<PinUnlockScreen> createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends State<PinUnlockScreen> {
  final GlobalKey<PinCodeInputState> _pinInputKey = GlobalKey<PinCodeInputState>();

  bool _isUnlocking = false;
  bool _biometricEnabled = false;
  String? _errorMessage;
  bool _autoBiometricAttempted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepareBiometricUnlock();
    });
  }

  Future<void> _prepareBiometricUnlock() async {
    final auth = context.read<AuthService>();
    final phone = auth.registeredPhone;

    if (phone == null) {
      return;
    }

    final canUseBiometric = await auth.canUseBiometricUnlock(phone: phone);

    if (!mounted) {
      return;
    }

    setState(() {
      _biometricEnabled = canUseBiometric;
    });

    if (canUseBiometric && !_autoBiometricAttempted) {
      _autoBiometricAttempted = true;
      await _unlockWithBiometric();
    }
  }

  Future<void> _unlockWithPin(String pin) async {
    if (_isUnlocking) {
      return;
    }

    setState(() {
      _isUnlocking = true;
      _errorMessage = null;
    });

    final auth = context.read<AuthService>();
    final isValid = await auth.unlockWithPin(pin);

    if (!mounted) {
      return;
    }

    if (isValid) {
      await _goToHome();
      return;
    }

    setState(() {
      _isUnlocking = false;
      _errorMessage = 'Неверный PIN.';
    });

    _pinInputKey.currentState?.clear();
  }

  Future<void> _unlockWithBiometric() async {
    if (_isUnlocking) {
      return;
    }

    setState(() {
      _isUnlocking = true;
      _errorMessage = null;
    });

    final auth = context.read<AuthService>();
    final isValid = await auth.unlockWithBiometric();

    if (!mounted) {
      return;
    }

    if (isValid) {
      await _goToHome();
      return;
    }

    setState(() {
      _isUnlocking = false;
    });
  }

  Future<void> _goToHome() async {
    if (!mounted) {
      return;
    }

    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const RootScreen()),
    );
  }

  Future<void> _continueAsGuest() async {
    final auth = context.read<AuthService>();
    auth.skipPinUnlockForSession();

    if (!mounted) {
      return;
    }

    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const RootScreen()),
    );
  }

  Future<void> _resetWithSms() async {
    final auth = context.read<AuthService>();
    await auth.resetAccountAccess();

    if (!mounted) {
      return;
    }

    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final phone = auth.registeredPhone ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Вход в аккаунт'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                phone,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Введите PIN или используйте биометрию',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (!_isUnlocking)
                PinCodeInput(
                  key: _pinInputKey,
                  length: PinCredentialService.pinLength,
                  onCompleted: _unlockWithPin,
                ),
              if (_isUnlocking) const CircularProgressIndicator(),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              const Spacer(),
              if (_biometricEnabled) ...[
                AuthButton(
                  text: 'Войти по биометрии',
                  onPressed: _isUnlocking ? null : _unlockWithBiometric,
                ),
                const SizedBox(height: 12),
              ],
              AuthButton(
                text: 'Забыли PIN? Войти по SMS',
                onPressed: _isUnlocking ? null : _resetWithSms,
              ),
              if (widget.allowGuest) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isUnlocking ? null : _continueAsGuest,
                  child: const Text('Продолжить как гость'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
