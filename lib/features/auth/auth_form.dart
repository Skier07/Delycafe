import 'package:delycafe/ui/components/buttons/auth_button.dart';
import 'package:delycafe/ui/components/inputs/phone_input.dart';
import 'package:delycafe/widgets/auth/auth_header.dart';
import 'package:flutter/material.dart';

class AuthForm extends StatefulWidget {
  final void Function(String phone) onSubmit;
  final bool isLoading;

  const AuthForm({
    super.key,
    required this.onSubmit,
    this.isLoading = false,
  });

  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  bool get _isPhoneValid {
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    return digits.length == 10;
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
    if (widget.isLoading) {
      return;
    }

    if (_formKey.currentState!.validate()) {
      var digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');

      if (digits.length == 11 && digits.startsWith('7')) {
        digits = digits.substring(1);
      }

      final phone = '+7$digits';
      widget.onSubmit(phone);
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
            text: widget.isLoading ? 'Отправляем...' : 'Продолжить',
            onPressed: _isPhoneValid && !widget.isLoading ? _submit : null,
          ),
        ],
      ),
    );
  }
}
