import 'package:delycafe/features/auth/auth_screen.dart';
import 'package:delycafe/screens/home_screen.dart';
import 'package:delycafe/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class RootScreen extends StatelessWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (auth.isLoggedIn) {
      return const HomeScreen();
    }
    return const AuthScreen();
  }
}
