import 'package:delycafe/features/auth/auth_form.dart';
import 'package:delycafe/screens/code_screen.dart';
import 'package:delycafe/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();

    void _onPhoneSubmit(String phone) {
      // Отправляем код
      authService.senCode(phone);

      // Переходим на экран ввода кода
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CodeScreen(phoneNumber: phone),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'DelyCafe',
          style: TextStyle(color: Color.fromRGBO(31, 31, 28, 1)),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: AuthForm(onSubmit: _onPhoneSubmit),
        ),
      ),
    );
  }
}
