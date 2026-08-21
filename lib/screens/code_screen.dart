import 'dart:async';

import 'package:delycafe/root_screen.dart';
import 'package:delycafe/services/auth_service.dart';
import 'package:delycafe/utils/haptic_feedback.dart';
import 'package:delycafe/utils/user_facing_error.dart';
import 'package:delycafe/widgets/auth/pin_code_input.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CodeScreen extends StatefulWidget {
  final String phoneNumber;
  const CodeScreen({super.key, required this.phoneNumber});

  @override
  State<CodeScreen> createState() => _CodeScreenState();
}

class _CodeScreenState extends State<CodeScreen> {
  final GlobalKey<PinCodeInputState> _codeInputKey =
      GlobalKey<PinCodeInputState>();

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
    } catch (error) {
      if (!mounted || _isVerifying || _isCompleting) {
        return;
      }

      setState(() {
        _errorMessage = userFacingError(error);
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
        await _goToApp();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isCompleting = false;
        _errorMessage = userFacingError(error);
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

  Future<void> _goToApp() async {
    await Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const RootScreen(),
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

      _codeInputKey.currentState?.clear();

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
        _errorMessage = userFacingError(error);
      });
    }
  }

  Future<void> _verifyCode(String code) async {
    if (code.length != 4 || _isVerifying || !_showCodeInput) {
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
        code,
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
        await _goToApp();
        return;
      }

      AppHaptics.error();
      setState(() {
        _isVerifying = false;
        _statusMessage = null;
        _errorMessage = 'Неверный код. Попробуйте ещё раз.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      AppHaptics.error();
      setState(() {
        _isVerifying = false;
        _statusMessage = null;
        _errorMessage = userFacingError(error);
      });
    }

    _codeInputKey.currentState?.clear();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isVerifying || _isCompleting || _isResending;
    final canResend = !isBusy && _retryAfter <= 0;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
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
                  PinCodeInput(
                    key: _codeInputKey,
                    length: 4,
                    obscureText: false,
                    enableSmsAutofill: true,
                    enabled: !isBusy,
                    onCompleted: _verifyCode,
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
      ),
    );
  }
}
