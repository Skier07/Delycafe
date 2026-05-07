import 'package:delycafe/features/auth/auth_screen.dart';
import 'package:delycafe/ui/tokens/app_radius.dart';
import 'package:flutter/material.dart';

class AuthBanner extends StatelessWidget {
  const AuthBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AuthScreen(),
          ),
        );
      },
      child: Container(
        height: screenHeight * 0.25,
        width: double.infinity,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        child: const Center(
          child: Text(
            'Войти',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
