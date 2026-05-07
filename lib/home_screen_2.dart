// import 'package:delycafe/features/auth/auth_screen.dart';
// import 'package:delycafe/screens/about_screen.dart';
// import 'package:delycafe/screens/contacts_screen.dart';
// import 'package:delycafe/screens/delivery_screen.dart';
// import 'package:delycafe/screens/news_promos/news_and_promo_screen.dart';
// import 'package:delycafe/services/auth_service.dart';
// import 'package:delycafe/ui/components/glass/dark_glass_sheet.dart';
// import 'package:delycafe/ui/components/glass/shader_glass_container.dart';
// import 'package:delycafe/ui/tokens/app_colors.dart';
// import 'package:delycafe/ui/tokens/app_radius.dart';
// import 'package:delycafe/ui/tokens/app_sizes.dart';
// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';

// enum HomeOverlayType {
//   none,
//   menu,
//   account,
// }

// class HomeScreen extends StatefulWidget {
//   const HomeScreen({super.key});

//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }

// class _HomeScreenState extends State<HomeScreen> {
//   HomeOverlayType _activeOverlay = HomeOverlayType.none;

//   @override
//   void didChangeDependencies() {
//     super.didChangeDependencies();
//     precacheImage(const AssetImage('assets/images/banner.png'), context);
//   }

//   void _openOverlay(HomeOverlayType type) {
//     setState(() {
//       _activeOverlay = type;
//     });
//   }

//   void _closeOverlay() {
//     if (_activeOverlay == HomeOverlayType.none) return;
//     setState(() {
//       _activeOverlay = HomeOverlayType.none;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     final screenHeight = MediaQuery.sizeOf(context).height;

//     return Scaffold(
//       body: Stack(
//         children: [
//           Column(
//             children: [
//               HomeBanner(
//                 screenHeight: screenHeight,
//                 onMenuPressed: () => _openOverlay(HomeOverlayType.menu),
//                 onAccountPressed: () => _openOverlay(HomeOverlayType.account),
//               ),
//               const Expanded(
//                 child: Center(
//                   child: Text(
//                     'Каталог еды будет здесь',
//                     style: TextStyle(fontSize: 18),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           IgnorePointer(
//             ignoring: _activeOverlay == HomeOverlayType.none,
//             child: AnimatedOpacity(
//               duration: const Duration(milliseconds: 220),
//               curve: Curves.easeOut,
//               opacity: _activeOverlay == HomeOverlayType.none ? 0 : 1,
//               child: AnimatedSlide(
//                 duration: const Duration(milliseconds: 260),
//                 curve: Curves.easeOutCubic,
//                 offset: _activeOverlay == HomeOverlayType.none
//                     ? const Offset(1, 0)
//                     : Offset.zero,
//                 child: _buildOverlay(context),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildOverlay(BuildContext context) {
//     switch (_activeOverlay) {
//       case HomeOverlayType.menu:
//         return DarkGlassSheet(
//           onClose: _closeOverlay,
//           children: [
//             DarkGlassSheetItem(
//               title: 'Каталог',
//               onTap: _closeOverlay,
//             ),
//             const DarkGlassSheetDivider(),
//             DarkGlassSheetItem(
//               title: 'Новости и акции',
//               onTap: () {
//                 _closeOverlay();
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (_) => const NewsAndPromoScreen(),
//                   ),
//                 );
//               },
//             ),
//             const DarkGlassSheetDivider(),
//             DarkGlassSheetItem(
//               title: 'Доставка и оплата',
//               onTap: () {
//                 _closeOverlay();
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (_) => const DeliveryScreen(),
//                   ),
//                 );
//               },
//             ),
//             const DarkGlassSheetDivider(),
//             DarkGlassSheetItem(
//               title: 'О компании',
//               onTap: () {
//                 _closeOverlay();
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (_) => const AboutScreen(),
//                   ),
//                 );
//               },
//             ),
//             const DarkGlassSheetDivider(),
//             DarkGlassSheetItem(
//               title: 'Контакты',
//               onTap: () {
//                 _closeOverlay();
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (_) => const ContactsScreen(),
//                   ),
//                 );
//               },
//             ),
//           ],
//         );

//       case HomeOverlayType.account:
//         return DarkGlassSheet(
//           onClose: _closeOverlay,
//           children: [
//             DarkGlassSheetItem(
//               title: 'Мой профиль',
//               onTap: _closeOverlay,
//             ),
//             const DarkGlassSheetDivider(),
//             DarkGlassSheetItem(
//               title: 'История заказов',
//               onTap: _closeOverlay,
//             ),
//             const DarkGlassSheetDivider(),
//             DarkGlassSheetItem(
//               title: 'Бонусы',
//               onTap: _closeOverlay,
//             ),
//             const DarkGlassSheetDivider(),
//             DarkGlassSheetItem(
//               title: 'Адреса доставки',
//               onTap: _closeOverlay,
//             ),
//             const DarkGlassSheetDivider(),
//             DarkGlassSheetItem(
//               title: 'Выйти',
//               isDanger: true,
//               onTap: () {
//                 context.read<AuthService>().logout();
//                 _closeOverlay();
//               },
//             ),
//           ],
//         );

//       case HomeOverlayType.none:
//         return const SizedBox.shrink();
//     }
//   }
// }

// class HomeBanner extends StatelessWidget {
//   final double screenHeight;
//   final VoidCallback onMenuPressed;
//   final VoidCallback onAccountPressed;

//   const HomeBanner({
//     super.key,
//     required this.screenHeight,
//     required this.onMenuPressed,
//     required this.onAccountPressed,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final topPadding = MediaQuery.of(context).padding.top;
//     final auth = context.watch<AuthService>();
//     final user = auth.currentUser;

//     /// =========================
//     /// НЕ ЗАЛОГИНЕН
//     /// =========================
//     if (user == null) {
//       return Container(
//         height: screenHeight * 0.25,
//         width: double.infinity,
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(AppRadius.button),
//           image: const DecorationImage(
//             image: AssetImage('assets/images/banner.png'),
//             fit: BoxFit.cover,
//           ),
//         ),
//         child: Container(
//           decoration: BoxDecoration(
//             borderRadius: BorderRadius.circular(AppRadius.button),
//             gradient: LinearGradient(
//               begin: Alignment.bottomLeft,
//               end: Alignment.topRight,
//               colors: [
//                 Colors.black.withValues(alpha: 0.35),
//                 Colors.transparent,
//               ],
//             ),
//           ),
//           child: Padding(
//             padding: const EdgeInsets.all(12),
//             child: Stack(
//               children: [
//                 /// ВОЙТИ (фиксированная позиция)
//                 Positioned(
//                   left: 24,
//                   top: 58,
//                   child: GestureDetector(
//                     onTap: () {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (_) => const AuthScreen(),
//                         ),
//                       );
//                     },
//                     child: const _LoginBannerContent(),
//                   ),
//                 ),

//                 /// МЕНЮ (справа сверху)
//                 Align(
//                   alignment: Alignment.topRight,
//                   child: Padding(
//                     padding: EdgeInsets.only(top: topPadding + 1),
//                     child: ShaderGlassContainer(
//                       onPressed: onMenuPressed,
//                       padding: const EdgeInsets.all(8),
//                       borderRadius: 30,
//                       child: const Icon(
//                         CupertinoIcons.text_justify,
//                         color: AppColors.buttonText,
//                         size: AppSizes.buttonSize,
//                       ),
//                     ),
//                   ),
//                 ),

//                 /// КОРЗИНА (справа снизу)
//                 Align(
//                   alignment: Alignment.bottomRight,
//                   child: ShaderGlassContainer(
//                     onPressed: () {
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         const SnackBar(content: Text('Корзина (позже)')),
//                       );
//                     },
//                     padding: const EdgeInsets.all(8),
//                     borderRadius: 30,
//                     child: const Icon(
//                       CupertinoIcons.delete_simple,
//                       color: AppColors.buttonText,
//                       size: AppSizes.buttonSize,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       );
//     }

//     /// =========================
//     /// ЗАЛОГИНЕН
//     /// =========================
//     return Container(
//       height: screenHeight * 0.25,
//       width: double.infinity,
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(AppRadius.button),
//         image: const DecorationImage(
//           image: AssetImage('assets/images/banner.png'),
//           fit: BoxFit.cover,
//         ),
//       ),
//       child: Padding(
//         padding: const EdgeInsets.all(12),
//         child: Stack(
//           children: [
//             /// АККАУНТ (слева сверху)
//             Align(
//               alignment: Alignment.topLeft,
//               child: Padding(
//                 padding: EdgeInsets.only(top: topPadding + 1),
//                 child: ShaderGlassContainer(
//                   padding: const EdgeInsets.all(8),
//                   borderRadius: 30,
//                   onPressed: onAccountPressed,
//                   child: const Icon(
//                     CupertinoIcons.person,
//                     color: AppColors.buttonText,
//                     size: AppSizes.buttonSize,
//                   ),
//                 ),
//               ),
//             ),

//             /// МЕНЮ (справа сверху)
//             Align(
//               alignment: Alignment.topRight,
//               child: Padding(
//                 padding: EdgeInsets.only(top: topPadding + 1),
//                 child: ShaderGlassContainer(
//                   onPressed: onMenuPressed,
//                   padding: const EdgeInsets.all(8),
//                   borderRadius: 30,
//                   child: const Icon(
//                     CupertinoIcons.text_justify,
//                     color: AppColors.buttonText,
//                     size: AppSizes.buttonSize,
//                   ),
//                 ),
//               ),
//             ),

//             /// БОНУСЫ (слева снизу)
//             Align(
//               alignment: Alignment.bottomLeft,
//               child: ShaderGlassContainer(
//                 onPressed: () {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(content: Text('Бонусы (позже)')),
//                   );
//                 },
//                 child: Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Text(
//                       '${user.points}',
//                       style: const TextStyle(
//                         fontSize: 24,
//                         fontWeight: FontWeight.w700,
//                         color: AppColors.buttonText,
//                       ),
//                     ),
//                     const SizedBox(width: 8),
//                     const Icon(
//                       CupertinoIcons.tickets,
//                       color: AppColors.buttonText,
//                       size: AppSizes.buttonSize,
//                     ),
//                   ],
//                 ),
//               ),
//             ),

//             /// КОРЗИНА (справа снизу)
//             Align(
//               alignment: Alignment.bottomRight,
//               child: ShaderGlassContainer(
//                 onPressed: () {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(content: Text('Корзина (позже)')),
//                   );
//                 },
//                 padding: const EdgeInsets.all(8),
//                 borderRadius: 30,
//                 child: const Icon(
//                   CupertinoIcons.delete_simple,
//                   color: AppColors.buttonText,
//                   size: AppSizes.buttonSize,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _LoginBannerContent extends StatefulWidget {
//   const _LoginBannerContent();

//   @override
//   State<_LoginBannerContent> createState() => __LoginBannerContentState();
// }

// class __LoginBannerContentState extends State<_LoginBannerContent> {
//   bool _pressed = false;

//   void _setpressed(bool value) {
//     if (_pressed == value) return;
//     setState(() => _pressed = value);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTapDown: (_) => _setpressed(true),
//       onTapUp: (_) => _setpressed(false),
//       onTapCancel: () => _setpressed(false),
//       onTap: () {
//         Navigator.push(
//           context,
//           MaterialPageRoute(builder: (_) => const AuthScreen()),
//         );
//       },
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 180),
//         curve: Curves.easeOutCubic,
//         transform: Matrix4.identity()
//           ..translateByDouble(
//               0.0, _pressed ? 1.5 : 0.0, 0.0, 1.0) // вдавливание
//           ..scaleByDouble(
//             _pressed ? 0.96 : 1.0,
//             _pressed ? 0.94 : 1.0,
//             1.0,
//             1.0,
//           ),
//         child: Stack(
//           children: [
//             Row(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Transform.scale(
//                   scaleY: 1.3,
//                   alignment: Alignment.centerLeft,
//                   child: ShaderMask(
//                     blendMode: BlendMode.srcATop,
//                     shaderCallback: (bounds) {
//                       return LinearGradient(
//                         begin: Alignment.topLeft,
//                         end: Alignment.bottomRight,
//                         colors: [
//                           Colors.white.withValues(alpha: 0.7),
//                           Colors.white.withValues(alpha: 0.2),
//                         ],
//                       ).createShader(bounds);
//                     },
//                     child: Text(
//                       'ВОЙТИ',
//                       style: TextStyle(
//                         fontSize: 50,
//                         fontWeight: FontWeight.bold,
//                         // color: AppColors.buttonText,
//                         letterSpacing: -1.0,
//                         color: Colors.white.withValues(alpha: 0.85),
//                         shadows: [
//                           Shadow(
//                             blurRadius: 18,
//                             color: Colors.black.withValues(alpha: 0.45),
//                             // color: AppColors.bannerOverlay,
//                             offset: const Offset(0, 6),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 4),
//                 const Icon(
//                   CupertinoIcons.chevron_right_2,
//                   size: 40,
//                   color: AppColors.buttonText,
//                   shadows: [
//                     Shadow(
//                       blurRadius: 14,
//                       color: AppColors.bannerOverlay,
//                       offset: Offset(0, 5),
//                     ),
//                   ],
//                 ),
//               ],
//             ),

//             /// Блик
//             Positioned.fill(
//               child: IgnorePointer(
//                 child: AnimatedOpacity(
//                   duration: const Duration(milliseconds: 120),
//                   opacity: _pressed ? 0.10 : 0.0,
//                   child: Container(
//                     decoration: BoxDecoration(
//                       gradient: LinearGradient(
//                         begin: Alignment.topLeft,
//                         end: Alignment.bottomRight,
//                         colors: [
//                           Colors.white.withValues(alpha: 0.35),
//                           Colors.transparent,
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
