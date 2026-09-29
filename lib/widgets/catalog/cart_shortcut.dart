import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:delycafe/services/cart_service.dart';
import 'package:delycafe/screens/checkout_screens.dart';
import 'package:delycafe/ui/tokens/app_colors.dart';

void openCart(BuildContext context) {
  Navigator.of(context).push(PageRouteBuilder<void>(
    pageBuilder: (_, animation, secondaryAnimation) => const CheckoutScreens(),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.disableAnimationsOf(context)) return child;
      return SlideTransition(
          position: Tween(begin: const Offset(1, 0), end: Offset.zero)
              .chain(CurveTween(curve: Curves.easeOutCubic))
              .animate(animation),
          child: child);
    },
  ));
}

String cartQuantityLabel(int count) {
  final tens = count % 100;
  final units = count % 10;
  final noun = tens >= 11 && tens <= 14
      ? 'товаров'
      : units == 1
          ? 'товар'
          : units >= 2 && units <= 4
              ? 'товара'
              : 'товаров';
  return '$count $noun';
}

class CartShortcut extends StatelessWidget {
  const CartShortcut({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();
    final count = cart.totalItems;
    final label = '${cartQuantityLabel(count)} · ${cart.totalPrice} ₽';
    return Semantics(
      label: 'Открыть корзину: $label',
      button: true,
      excludeSemantics: true,
      child: Material(
        color: compact ? const Color(0xFFEEE9F5) : AppColors.header,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openCart(context),
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: compact ? 14 : 20, vertical: 16),
            child: Row(
              mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
              children: [
                Badge(
                  isLabelVisible: count > 0,
                  label: AnimatedSwitcher(
                      duration: Duration(
                          milliseconds: MediaQuery.disableAnimationsOf(context)
                              ? 0
                              : 200),
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: Text('$count', key: ValueKey(count))),
                  backgroundColor: compact ? AppColors.header : Colors.white,
                  textColor: compact ? Colors.white : AppColors.header,
                  child: Icon(Icons.shopping_cart_outlined,
                      color: compact ? AppColors.header : Colors.white),
                ),
                if (!compact) ...[
                  const SizedBox(width: 20),
                  Expanded(
                      child: Text(label,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700))),
                  const Icon(Icons.arrow_forward, color: Colors.white),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FloatingCartBar extends StatelessWidget {
  const FloatingCartBar({super.key});
  @override
  Widget build(BuildContext context) {
    final visible = context.watch<CartService>().totalItems > 0;
    return AnimatedSwitcher(
      duration: Duration(
          milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
              position: Tween(begin: const Offset(0, .25), end: Offset.zero)
                  .animate(animation),
              child: child)),
      child: visible
          ? const SafeArea(
              key: ValueKey('cart'),
              top: false,
              child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: CartShortcut()))
          : const SizedBox.shrink(key: ValueKey('empty')),
    );
  }
}
