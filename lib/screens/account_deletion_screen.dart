import 'package:delycafe/config/api_config.dart';
import 'package:delycafe/root_screen.dart';
import 'package:delycafe/screens/legal_document_screen.dart';
import 'package:delycafe/services/auth_service.dart';
import 'package:delycafe/services/legal_consent_service.dart';
import 'package:delycafe/ui/components/buttons/auth_button.dart';
import 'package:delycafe/ui/tokens/app_colors.dart';
import 'package:delycafe/utils/user_facing_error.dart';
import 'package:delycafe/widgets/auth/pin_code_input.dart';
import 'package:flutter/material.dart';
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
  final GlobalKey<PinCodeInputState> _codeInputKey =
      GlobalKey<PinCodeInputState>();

  bool _codeSent = false;
  bool _isSendingCode = false;
  bool _isDeleting = false;
  String? _errorMessage;

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

      _codeInputKey.currentState?.clear();

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
        _errorMessage = userFacingError(error);
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

  Future<void> _deleteAccount(String code) async {
    if (code.length != 4 || _isDeleting) {
      return;
    }

    final confirmed = await _confirmDeletion();

    if (!confirmed || !mounted) {
      _codeInputKey.currentState?.clear();
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
        code: code,
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
        _errorMessage = userFacingError(error);
      });

      _codeInputKey.currentState?.clear();
    }
  }

  void _openDeletionPolicy() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LegalDocumentScreen(
          title: 'Порядок удаления аккаунта',
          url: ApiConfig.uri('/api/legal/documents/account-deletion/')
              .toString(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
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
                text: _isSendingCode
                    ? 'Отправляем код...'
                    : 'Отправить код подтверждения',
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
                PinCodeInput(
                  key: _codeInputKey,
                  length: 4,
                  obscureText: false,
                  enableSmsAutofill: true,
                  enabled: !_isDeleting,
                  onCompleted: _deleteAccount,
                ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _isDeleting || _isSendingCode ? null : _sendCode,
                child: Text(
                  _isSendingCode ? 'Отправляем...' : 'Отправить код повторно',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
