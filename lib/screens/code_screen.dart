import 'dart:async';

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

  Timer? _pollTimer;
  Timer? _retryTimer;

  bool _isVerifying = false;
  bool _isResending = false;
  bool _isCompleting = false;
  bool _showCodeInput = false;
  String? _errorMessage;
  String? _statusMessage;
  int _retryAfter = 0;

  @override
  void initState() {
    super.initState();
    _pollOtpStatus();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _pollOtpStatus();
    });
  }

  String get _enterCode => _controllers.map((c) => c.text).join();

  Future<void> _pollOtpStatus() async {
    if (!mounted || _isVerifying || _isCompleting || _isResending) {
      return;
    }

    final authService = context.read<AuthService>();

    try {
      final status = await authService.fetchOtpStatus(widget.phoneNumber);

      if (!mounted) {
        return;
      }

      if (status.retryAfter != null && status.retryAfter! > _retryAfter) {
        _retryAfter = status.retryAfter!;
        _startRetryCountdown();
      }

      if (status.verified) {
        await _completeVerifiedLogin(status.message);
        return;
      }

      setState(() {
        _showCodeInput = status.showCodeInput;
        _statusMessage = status.message;
        if (status.phase != 'failed') {
          _errorMessage = null;
        } else {
          _errorMessage = status.message;
        }
      });

      if (status.showCodeInput && !_focusNodes.first.hasFocus && !_isVerifying) {
        _focusNodes.first.requestFocus();
      }
    } catch (error) {
      if (!mounted || _isVerifying || _isCompleting) {
        return;
      }

      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _completeVerifiedLogin(String message) async {
    if (_isCompleting) {
      return;
    }

    setState(() {
      _isCompleting = true;
      _statusMessage = message;
      _errorMessage = null;
    });

    final authService = context.read<AuthService>();

    try {
      final completed = await authService.completeVerifiedOtp(
        widget.phoneNumber,
        onProgress: (progress) {
          if (!mounted) {
            return;
          }

          setState(() {
            _statusMessage = progress;
          });
        },
      );

      if (!mounted) {
        return;
      }

      if (completed) {
        await _goToPinSetup();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isCompleting = false;
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _startRetryCountdown() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_retryAfter <= 0) {
        timer.cancel();
        setState(() {});
        return;
      }

      setState(() {
        _retryAfter -= 1;
      });
    });
  }

  void _onDigitChanged(int index, String value) {
    if (_isVerifying || !_showCodeInput) {
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

  Future<void> _resendCode() async {
    if (_isResending || _retryAfter > 0) {
      return;
    }

    setState(() {
      _isResending = true;
      _errorMessage = null;
      _statusMessage = 'Отправляем код...';
      _showCodeInput = false;
    });

    final authService = context.read<AuthService>();

    try {
      await authService.sendCode(widget.phoneNumber);

      if (!mounted) {
        return;
      }

      for (final controller in _controllers) {
        controller.clear();
      }

      setState(() {
        _isResending = false;
        _retryAfter = 30;
      });
      _startRetryCountdown();
      await _pollOtpStatus();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isResending = false;
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _verifyCode() async {
    if (_enterCode.length != 4 || _isVerifying || !_showCodeInput) {
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
    _pollTimer?.cancel();
    _retryTimer?.cancel();
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
    final isBusy = _isVerifying || _isCompleting || _isResending;
    final canResend = !isBusy && _retryAfter <= 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Подтверждение номера')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
              ],
              if (isBusy || !_showCodeInput) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
              ],
              if (_statusMessage != null) ...[
                Text(
                  _statusMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (!_showCodeInput && !isBusy) ...[
                Text(
                  'SIM-PUSH не подставляет код в поля — это проверка у оператора. '
                  'Если она пройдёт, вход выполнится автоматически.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 20),
              ],
              if (_showCodeInput && !_isVerifying && !_isCompleting)
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
                              borderRadius:
                                  BorderRadius.all(Radius.circular(16)),
                            ),
                          ),
                          onChanged: (value) => _onDigitChanged(index, value),
                        ),
                      ),
                    );
                  }),
                ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: canResend ? _resendCode : null,
                child: Text(
                  _retryAfter > 0
                      ? 'Отправить код повторно ($_retryAfter с)'
                      : 'Отправить код повторно',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
