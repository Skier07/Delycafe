import 'package:delycafe/screens/pin_setup_screen.dart';
import 'package:delycafe/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class CodeScreen extends StatefulWidget {
  final String phoneNumber;
  const CodeScreen({super.key, required this.phoneNumber});

  @override
  State<CodeScreen> createState() => _CodeScreenState();
}

class _CodeScreenState extends State<CodeScreen> {
  final List<TextEditingController> _controllers =
      List.generate(4, (_) => TextEditingController());

  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  bool _isVerifying = false;
  String? _errorMessage;
  String? _statusMessage;

  String get _enterCode => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (_isVerifying) {
      return;
    }

    if (value.isNotEmpty) {
      if (index < 3) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _verifyCode();
      }
    } else {
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }
  }

  KeyEventResult _onDigitKeyEvent(int index, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _goToPinSetup() async {
    await Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => PinSetupScreen(phone: widget.phoneNumber),
      ),
      (route) => false,
    );
  }

  Future<void> _verifyCode() async {
    if (_enterCode.length != 4 || _isVerifying) {
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
      _statusMessage = 'Проверяем код...';
    });

    final authService = context.read<AuthService>();

    try {
      final isValid = await authService.verifyCode(
        widget.phoneNumber,
        _enterCode,
        onProgress: (message) {
          if (!mounted) {
            return;
          }

          setState(() {
            _statusMessage = message;
          });
        },
      );

      if (!mounted) {
        return;
      }

      if (isValid) {
        await _goToPinSetup();
        return;
      }

      setState(() {
        _isVerifying = false;
        _statusMessage = null;
        _errorMessage = 'Неверный код. Попробуйте ещё раз.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isVerifying = false;
        _statusMessage = null;
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }

    for (final controller in _controllers) {
      controller.clear();
    }

    _focusNodes.first.requestFocus();
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Введите код')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_errorMessage != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_isVerifying) ...[
              const CircularProgressIndicator(),
              if (_statusMessage != null) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    _statusMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
            if (!_isVerifying)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  return Container(
                    width: 60,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    child: Focus(
                      onKeyEvent: (node, event) =>
                          _onDigitKeyEvent(index, event),
                      child: TextField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        decoration: const InputDecoration(
                          counterText: '',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(16)),
                          ),
                        ),
                        onChanged: (value) => _onDigitChanged(index, value),
                      ),
                    ),
                  );
                }),
              ),
          ],
        ),
      ),
    );
  }
}
