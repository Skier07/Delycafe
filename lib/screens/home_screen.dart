import 'package:delycafe/features/auth/auth_screen.dart';
import 'package:delycafe/screens/about_screen.dart';
import 'package:delycafe/screens/addresses_screen.dart';
import 'package:delycafe/screens/bonuses_screen.dart';
import 'package:delycafe/screens/checkout_screens.dart';
import 'package:delycafe/screens/contacts_screen.dart';
import 'package:delycafe/screens/delivery_screen.dart';
import 'package:delycafe/screens/news_promos/news_and_promo_screen.dart';
import 'package:delycafe/screens/orders_screen.dart';
import 'package:delycafe/screens/profile_screen.dart';
import 'package:delycafe/services/auth_service.dart';
import 'package:delycafe/services/cart_service.dart';
import 'package:delycafe/services/update_service.dart';
import 'package:delycafe/ui/components/glass/dark_glass_sheet.dart';
import 'package:delycafe/ui/components/glass/shader_glass_container.dart';
import 'package:delycafe/ui/tokens/app_colors.dart';
import 'package:delycafe/ui/tokens/app_radius.dart';
import 'package:delycafe/ui/tokens/app_sizes.dart';
import 'package:delycafe/widgets/catalog/catalog_section.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum HomeOverlayType {
  none,
  menu,
  account,
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeOverlayType _activeOverlay = HomeOverlayType.none;
  final GlobalKey _cartIconKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.checkForUpdates(context);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/images/banner.png'), context);
  }

  void _openOverlay(HomeOverlayType type) {
    setState(() {
      _activeOverlay = type;
    });
  }

  void _closeOverlay() {
    if (_activeOverlay == HomeOverlayType.none) return;
    setState(() {
      _activeOverlay = HomeOverlayType.none;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Scaffold(
      body: Stack(
        children: [
          CatalogSection(
            cartIconKey: _cartIconKey,
            banner: HomeBanner(
              screenHeight: screenHeight,
              cartIconKey: _cartIconKey,
              onMenuPressed: () => _openOverlay(HomeOverlayType.menu),
              onAccountPressed: () => _openOverlay(HomeOverlayType.account),
            ),
          ),
          IgnorePointer(
            ignoring: _activeOverlay == HomeOverlayType.none,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 50),
              curve: Curves.easeOut,
              opacity: _activeOverlay == HomeOverlayType.none ? 0 : 1,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOutCubic,
                offset: _activeOverlay == HomeOverlayType.none
                    ? const Offset(1, 0)
                    : Offset.zero,
                child: _buildOverlay(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    switch (_activeOverlay) {
      case HomeOverlayType.menu:
        return DarkGlassSheet(
          onClose: _closeOverlay,
          children: [
            DarkGlassSheetItem(
              title: 'Каталог',
              onTap: _closeOverlay,
            ),
            const DarkGlassSheetDivider(),
            DarkGlassSheetItem(
              title: 'Новости и акции',
              onTap: () {
                _closeOverlay();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NewsAndPromoScreen(),
                  ),
                );
              },
            ),
            const DarkGlassSheetDivider(),
            DarkGlassSheetItem(
              title: 'Доставка и оплата',
              onTap: () {
                _closeOverlay();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DeliveryScreen(),
                  ),
                );
              },
            ),
            const DarkGlassSheetDivider(),
            DarkGlassSheetItem(
              title: 'О компании',
              onTap: () {
                _closeOverlay();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AboutScreen(),
                  ),
                );
              },
            ),
            const DarkGlassSheetDivider(),
            DarkGlassSheetItem(
              title: 'Контакты',
              onTap: () {
                _closeOverlay();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ContactsScreen(),
                  ),
                );
              },
            ),
          ],
        );

      case HomeOverlayType.account:
        return DarkGlassSheet(
          onClose: _closeOverlay,
          children: [
            DarkGlassSheetItem(
              title: 'Мой профиль',
              onTap: () {
                _closeOverlay();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProfileScreen(),
                  ),
                );
              },
            ),
            const DarkGlassSheetDivider(),
            DarkGlassSheetItem(
              title: 'История заказов',
              onTap: () {
                _closeOverlay();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const OrdersScreen(),
                  ),
                );
              },
            ),
            const DarkGlassSheetDivider(),
            DarkGlassSheetItem(
              title: 'Бонусы',
              onTap: () {
                _closeOverlay();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BonusesScreen(),
                  ),
                );
              },
            ),
            const DarkGlassSheetDivider(),
            DarkGlassSheetItem(
              title: 'Адреса доставки',
              onTap: () {
                _closeOverlay();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddressesScreen(),
                  ),
                );
              },
            ),
            const DarkGlassSheetDivider(),
            DarkGlassSheetItem(
              title: 'Выйти',
              isDanger: true,
              onTap: () {
                context.read<AuthService>().logout();
                _closeOverlay();
              },
            ),
          ],
        );

      case HomeOverlayType.none:
        return const SizedBox.shrink();
    }
  }
}

class HomeBanner extends StatelessWidget {
  final double screenHeight;
  final GlobalKey cartIconKey;
  final VoidCallback onMenuPressed;
  final VoidCallback onAccountPressed;

  const HomeBanner({
    super.key,
    required this.screenHeight,
    required this.cartIconKey,
    required this.onMenuPressed,
    required this.onAccountPressed,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;
    final cart = context.watch<CartService>();

    if (user == null) {
      return Container(
        height: screenHeight * 0.25,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.button),
          image: const DecorationImage(
            image: AssetImage('assets/images/banner.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.button),
            gradient: LinearGradient(
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
              colors: [
                Colors.black.withValues(alpha: 0.35),
                Colors.transparent,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Stack(
              children: [
                const Positioned(
                  left: 24,
                  top: 58,
                  child: _LoginBannerContent(),
                ),
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: EdgeInsets.only(top: topPadding + 1),
                    child: ShaderGlassContainer(
                      onPressed: onMenuPressed,
                      padding: const EdgeInsets.all(8),
                      borderRadius: 30,
                      child: const Icon(
                        CupertinoIcons.text_justify,
                        color: AppColors.buttonText,
                        size: AppSizes.buttonSize,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ShaderGlassContainer(
                        key: cartIconKey,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CheckoutScreens(),
                            ),
                          );
                        },
                        padding: const EdgeInsets.all(8),
                        borderRadius: 30,
                        child: const Icon(
                          CupertinoIcons.cart,
                          color: AppColors.buttonText,
                          size: AppSizes.buttonSize,
                        ),
                      ),
                      if (cart.totalItems > 0)
                        Positioned(
                          top: 25,
                          right: 40,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${cart.totalItems}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      height: screenHeight * 0.25,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.button),
        image: const DecorationImage(
          image: AssetImage('assets/images/banner.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: EdgeInsets.only(top: topPadding + 1),
                child: ShaderGlassContainer(
                  padding: const EdgeInsets.all(8),
                  borderRadius: 30,
                  onPressed: onAccountPressed,
                  child: const Icon(
                    CupertinoIcons.person,
                    color: AppColors.buttonText,
                    size: AppSizes.buttonSize,
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.only(top: topPadding + 1),
                child: ShaderGlassContainer(
                  onPressed: onMenuPressed,
                  padding: const EdgeInsets.all(8),
                  borderRadius: 30,
                  child: const Icon(
                    CupertinoIcons.text_justify,
                    color: AppColors.buttonText,
                    size: AppSizes.buttonSize,
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: ShaderGlassContainer(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BonusesScreen(),
                    ),
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${user.points}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.buttonText,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      CupertinoIcons.tickets,
                      color: AppColors.buttonText,
                      size: AppSizes.buttonSize,
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ShaderGlassContainer(
                    key: cartIconKey,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CheckoutScreens(),
                        ),
                      );
                    },
                    padding: const EdgeInsets.all(8),
                    borderRadius: 30,
                    child: const Icon(
                      CupertinoIcons.cart,
                      color: AppColors.buttonText,
                      size: AppSizes.buttonSize,
                    ),
                  ),
                  if (cart.totalItems > 0)
                    Positioned(
                      top: 25,
                      right: 40,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${cart.totalItems}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginBannerContent extends StatefulWidget {
  const _LoginBannerContent();

  @override
  State<_LoginBannerContent> createState() => __LoginBannerContentState();
}

class __LoginBannerContentState extends State<_LoginBannerContent> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AuthScreen()),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()
          ..translateByDouble(0.0, _pressed ? 1.5 : 0.0, 0.0, 1.0)
          ..scaleByDouble(
            _pressed ? 0.96 : 1.0,
            _pressed ? 0.94 : 1.0,
            1.0,
            1.0,
          ),
        child: Stack(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scaleY: 1.3,
                  alignment: Alignment.centerLeft,
                  child: ShaderMask(
                    blendMode: BlendMode.srcATop,
                    shaderCallback: (bounds) {
                      return LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.7),
                          Colors.white.withValues(alpha: 0.2),
                        ],
                      ).createShader(bounds);
                    },
                    child: Text(
                      'ВОЙТИ',
                      style: TextStyle(
                        fontSize: 50,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -1.0,
                        color: Colors.white.withValues(alpha: 0.85),
                        shadows: [
                          Shadow(
                            blurRadius: 18,
                            color: Colors.black.withValues(alpha: 0.45),
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  CupertinoIcons.chevron_right_2,
                  size: 40,
                  color: AppColors.buttonText,
                  shadows: [
                    Shadow(
                      blurRadius: 14,
                      color: AppColors.bannerOverlay,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
              ],
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 120),
                  opacity: _pressed ? 0.10 : 0.0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
