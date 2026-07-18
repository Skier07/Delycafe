import 'package:delycafe/config/api_config.dart';
import 'package:delycafe/root_screen.dart';
import 'package:delycafe/screens/legal_document_screen.dart';
import 'package:delycafe/services/auth_service.dart';
import 'package:delycafe/services/legal_consent_service.dart';
import 'package:delycafe/ui/components/buttons/auth_button.dart';
import 'package:delycafe/ui/tokens/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class AccountDeletionScreen extends StatefulWidget {
  final String phone;

  const AccountDeletionScreen({
    super.key,
    required this.phone,
  });

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  final List<TextEditingController> _controllers =
      List.generate(4, (_) => TextEditingController());

  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  bool _codeSent = false;
  bool _isSendingCode = false;
  bool _isDeleting = false;
  String? _errorMessage;

  String get _enterCode => _controllers.map((controller) => controller.text).join();

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }

    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }

    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_isSendingCode || _isDeleting) {
      return;
    }

    setState(() {
      _isSendingCode = true;
      _errorMessage = null;
    });

    try {
      await context.read<AuthService>().sendAccountDeletionCode(widget.phone);

      if (!mounted) {
        return;
      }

      setState(() {
        _codeSent = true;
        _isSendingCode = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSendingCode = false;
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<bool> _confirmDeletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Удалить аккаунт?'),
          content: const Text(
            'Это действие необратимо. Вы потеряете доступ к бонусам, '
            'сохранённым адресам и истории заказов в приложении.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Удалить',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    return confirmed ?? false;
  }

  Future<void> _deleteAccount() async {
    if (_enterCode.length != 4 || _isDeleting) {
      return;
    }

    final confirmed = await _confirmDeletion();

    if (!confirmed || !mounted) {
      return;
    }

    setState(() {
      _isDeleting = true;
      _errorMessage = null;
    });

    final auth = context.read<AuthService>();
    final legalConsent = context.read<LegalConsentService>();

    try {
      await auth.deleteAccount(
        phone: widget.phone,
        code: _enterCode,
      );
      await legalConsent.clearAll();

      if (!mounted) {
        return;
      }

      await Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RootScreen()),
        (route) => false,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Аккаунт удалён'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isDeleting = false;
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });

      for (final controller in _controllers) {
        controller.clear();
      }

      _focusNodes.first.requestFocus();
    }
  }

  void _onDigitChanged(int index, String value) {
    if (_isDeleting) {
      return;
    }

    if (value.isNotEmpty) {
      if (index < 3) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _deleteAccount();
      }
    } else if (index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  KeyEventResult _onDigitKeyEvent(int index, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _openDeletionPolicy() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LegalDocumentScreen(
          title: 'Порядок удаления аккаунта',
          url: ApiConfig.uri('/api/legal/documents/account-deletion/').toString(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEF7FF),
      appBar: AppBar(
        backgroundColor: AppColors.header,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Удаление аккаунта',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.red.withValues(alpha: 0.25),
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Внимание',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.red,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'После удаления аккаунта вы потеряете доступ к бонусному '
                  'счёту, сохранённым адресам и данным профиля. '
                  'Восстановление аккаунта не гарантируется.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _openDeletionPolicy,
            child: const Text('Порядок удаления аккаунта'),
          ),
          const SizedBox(height: 8),
          if (_errorMessage != null) ...[
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 12),
          ],
          if (!_codeSent) ...[
            AuthButton(
              text: _isSendingCode ? 'Отправляем код...' : 'Отправить код подтверждения',
              onPressed: _isSendingCode ? null : _sendCode,
            ),
          ] else ...[
            const Text(
              'Введите код из SMS для подтверждения удаления аккаунта',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            if (_isDeleting)
              const Center(child: CircularProgressIndicator())
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  return Container(
                    width: 56,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
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
                            borderRadius: BorderRadius.all(Radius.circular(14)),
                          ),
                        ),
                        onChanged: (value) => _onDigitChanged(index, value),
                      ),
                    ),
                  );
                }),
              ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _isDeleting || _isSendingCode ? null : _sendCode,
              child: Text(_isSendingCode ? 'Отправляем...' : 'Отправить код повторно'),
            ),
          ],
        ],
      ),
    );
  }
}
