import 'package:delycafe/ui/components/buttons/auth_button.dart';
import 'package:delycafe/ui/components/inputs/phone_input.dart';
import 'package:delycafe/widgets/auth/auth_header.dart';
import 'package:flutter/material.dart';

class AuthForm extends StatefulWidget {
  final void Function(String phone) onSubmit;
  const AuthForm({super.key, required this.onSubmit});

  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  final TextEditingController phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  bool get _isPhoneValid {
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    return digits.length == 10; // +7 + 10 цифр
  }

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      var digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');

      // если вдруг пользователь вставил 11 цифр (с 7 в начале)
      if (digits.length == 11 && digits.startsWith('7')) {
        digits = digits.substring(1);
      }
      final phone = '+7$digits';
      widget.onSubmit(phone);
      // widget.onSubmit(_phoneController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthHeader(),
          // Передаём validator внутрь
          PhoneInput(
            controller: _phoneController,
            validator: (value) {
              final digits = value?.replaceAll(RegExp(r'\D'), '') ?? '';
              if (digits.length != 10) {
                return 'Введите номер полностью';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          AuthButton(
            text: 'Продолжить',
            // кнопка активна только при 11 цифрах
            onPressed: _isPhoneValid ? _submit : null,
          ),
        ],
      ),
    );
  }
}
