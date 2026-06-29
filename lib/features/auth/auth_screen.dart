import 'package:delycafe/features/auth/auth_form.dart';
import 'package:delycafe/screens/code_screen.dart';
import 'package:delycafe/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isSending = false;
  String? _errorMessage;

  Future<void> _onPhoneSubmit(String phone) async {
    if (_isSending) {
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    final authService = context.read<AuthService>();

    try {
      await authService.sendCode(phone);

      if (!mounted) {
        return;
      }

      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CodeScreen(phoneNumber: phone),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 12),
              ],
              AuthForm(
                onSubmit: _onPhoneSubmit,
                isLoading: _isSending,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
