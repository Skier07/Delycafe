import 'package:delycafe/root_screen.dart';
import 'package:delycafe/services/auth_service.dart';
import 'package:delycafe/services/catalog_repository.dart';
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
  static const Duration _catalogRefreshTimeout = Duration(seconds: 8);

  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

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
    final auth = context.read<AuthService>();

    await Future.wait([
      _controller.forward(),
      Future.delayed(_minimumSplashDuration),
      auth.waitForSessionReady(),
      _warmCatalogCache(),
    ]);

    if (!mounted) return;

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

  Future<void> _warmCatalogCache() async {
    final repository = CatalogRepository();
    repository.readCached();

    try {
      await repository.fetchFromApiAndCache().timeout(_catalogRefreshTimeout);
    } catch (_) {
      // Оффлайн или медленная сеть: остаёмся на кэше каталога.
    }
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
