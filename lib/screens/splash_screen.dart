import 'package:delycafe/root_screen.dart';
import 'package:delycafe/services/auth_service.dart';
import 'package:delycafe/ui/tokens/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _minimumSplashDuration = Duration(milliseconds: 1500);
  static const Duration _sessionReadyTimeout = Duration(seconds: 10);
  static const Duration _totalSplashTimeout = Duration(seconds: 12);

  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.75,
      end: 1.08,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startSplash();
    });
  }

  Future<void> _startSplash() async {
    try {
      await _runStartupTasks().timeout(_totalSplashTimeout);
    } catch (_) {
      // Не блокируем вход: открываем главную даже при медленной сети.
    }

    await _navigateToRoot();
  }

  Future<void> _runStartupTasks() async {
    final auth = context.read<AuthService>();

    await Future.wait([
      _controller.forward(),
      Future.delayed(_minimumSplashDuration),
      auth.waitForSessionReady().timeout(_sessionReadyTimeout),
    ]);
  }

  Future<void> _navigateToRoot() async {
    if (!mounted || _navigated) return;

    _navigated = true;

    await Navigator.pushReplacement(
      context,
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) {
          return const RootScreen();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.splashBackground,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Image.asset(
              'assets/icon.png',
              width: 300,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
