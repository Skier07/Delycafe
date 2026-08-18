import 'package:delycafe/features/auth/auth_screen.dart';
import 'package:delycafe/root_screen.dart';
import 'package:delycafe/services/auth_service.dart';
import 'package:delycafe/services/pin_credential_service.dart';
import 'package:delycafe/ui/components/buttons/auth_button.dart';
import 'package:delycafe/widgets/auth/pin_code_input.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PinUnlockScreen extends StatefulWidget {
  const PinUnlockScreen({super.key});

  @override
  State<PinUnlockScreen> createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends State<PinUnlockScreen> {
  final GlobalKey<PinCodeInputState> _pinInputKey =
      GlobalKey<PinCodeInputState>();

  bool _isSubmittingPin = false;
  bool _isBiometricInProgress = false;
  bool _biometricEnabled = false;
  String? _errorMessage;
  bool _autoBiometricAttempted = false;

  bool get _isBusy => _isSubmittingPin || _isBiometricInProgress;

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
      await _unlockWithBiometric(autoAttempt: true);
    }
  }

  Future<void> _unlockWithPin(String pin) async {
    if (_isBusy) {
      return;
    }

    setState(() {
      _isSubmittingPin = true;
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
      _isSubmittingPin = false;
      _errorMessage = 'Неверный PIN.';
    });

    _pinInputKey.currentState?.clear();
  }

  Future<void> _unlockWithBiometric({bool autoAttempt = false}) async {
    if (_isBusy) {
      return;
    }

    setState(() {
      _isBiometricInProgress = true;
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
      _isBiometricInProgress = false;
    });

    if (!autoAttempt && mounted) {
      setState(() {
        _errorMessage = 'Биометрия не подтверждена. Введите PIN.';
      });
    }
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

  Future<void> _resetWithSms() async {
    final auth = context.read<AuthService>();
    await auth.beginSmsRecovery();

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

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Вход в аккаунт'),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 48,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        Text(
                          phone,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _biometricEnabled
                              ? 'Введите PIN или используйте биометрию'
                              : 'Введите PIN для входа',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        PinCodeInput(
                          key: _pinInputKey,
                          length: PinCredentialService.pinLength,
                          enabled: !_isSubmittingPin,
                          onCompleted: _unlockWithPin,
                        ),
                        if (_isSubmittingPin) ...[
                          const SizedBox(height: 16),
                          const CircularProgressIndicator(),
                        ],
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
                            text: _isBiometricInProgress
                                ? 'Подтвердите биометрию…'
                                : 'Войти по биометрии',
                            onPressed: _isBusy ? null : _unlockWithBiometric,
                          ),
                          const SizedBox(height: 12),
                        ],
                        AuthButton(
                          text: 'Забыли PIN? Войти по SMS',
                          onPressed: _isBusy ? null : _resetWithSms,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
