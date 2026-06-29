import 'package:delycafe/screens/home_screen.dart';
import 'package:delycafe/services/auth_service.dart';
import 'package:delycafe/services/pin_credential_service.dart';
import 'package:delycafe/ui/components/buttons/auth_button.dart';
import 'package:delycafe/widgets/auth/pin_code_input.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({
    super.key,
    required this.phone,
  });

  final String phone;

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final GlobalKey<PinCodeInputState> _firstPinKey = GlobalKey<PinCodeInputState>();
  final GlobalKey<PinCodeInputState> _confirmPinKey = GlobalKey<PinCodeInputState>();

  String? _firstPin;
  bool _isSaving = false;
  bool _enableBiometric = true;
  bool _biometricAvailable = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBiometricAvailability();
  }

  Future<void> _loadBiometricAvailability() async {
    final auth = context.read<AuthService>();
    final available = await auth.canUseBiometricUnlock();

    if (!mounted) {
      return;
    }

    setState(() {
      _biometricAvailable = available;
      _enableBiometric = available;
    });
  }

  Future<void> _onFirstPinCompleted(String pin) async {
    setState(() {
      _firstPin = pin;
      _errorMessage = null;
    });

    _confirmPinKey.currentState?.clear();
  }

  Future<void> _onConfirmPinCompleted(String pin) async {
    if (_isSaving || _firstPin == null) {
      return;
    }

    if (_firstPin != pin) {
      setState(() {
        _errorMessage = 'PIN-коды не совпали. Повторите ввод.';
        _firstPin = null;
      });

      _firstPinKey.currentState?.clear();
      _confirmPinKey.currentState?.clear();
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final auth = context.read<AuthService>();

    try {
      await auth.completePinSetup(
        phone: widget.phone,
        pin: pin,
        enableBiometric: _biometricAvailable && _enableBiometric,
      );

      if (!mounted) {
        return;
      }

      await Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
        _firstPin = null;
      });

      _firstPinKey.currentState?.clear();
      _confirmPinKey.currentState?.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final stepTitle = _firstPin == null ? 'Придумайте PIN' : 'Повторите PIN';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Защита аккаунта'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                stepTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'PIN из ${PinCredentialService.pinLength} цифр нужен для быстрого входа без SMS.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (_firstPin == null)
                PinCodeInput(
                  key: _firstPinKey,
                  length: PinCredentialService.pinLength,
                  enabled: !_isSaving,
                  onCompleted: _onFirstPinCompleted,
                )
              else
                PinCodeInput(
                  key: _confirmPinKey,
                  length: PinCredentialService.pinLength,
                  enabled: !_isSaving,
                  onCompleted: _onConfirmPinCompleted,
                ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              if (_isSaving) ...[
                const SizedBox(height: 24),
                const Center(child: CircularProgressIndicator()),
              ],
              if (_biometricAvailable) ...[
                const SizedBox(height: 32),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Входить по биометрии'),
                  subtitle: const Text('Face ID или отпечаток пальца'),
                  value: _enableBiometric,
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          setState(() {
                            _enableBiometric = value;
                          });
                        },
                ),
              ],
              const SizedBox(height: 24),
              AuthButton(
                text: 'Начать заново',
                onPressed: _isSaving
                    ? null
                    : () {
                        setState(() {
                          _firstPin = null;
                          _errorMessage = null;
                        });
                        _firstPinKey.currentState?.clear();
                        _confirmPinKey.currentState?.clear();
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
