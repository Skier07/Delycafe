import 'package:delycafe/screens/checkout_screens.dart';
import 'package:delycafe/services/cart_service.dart';
import 'package:delycafe/ui/components/glass/shader_glass_container.dart';
import 'package:delycafe/ui/tokens/app_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
    final content = Row(
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      children: [
        Badge(
          isLabelVisible: count > 0,
          label: AnimatedSwitcher(
            duration: Duration(
                milliseconds:
                    MediaQuery.disableAnimationsOf(context) ? 0 : 200),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Text('$count', key: ValueKey(count)),
          ),
          backgroundColor: AppColors.header,
          textColor: Colors.white,
          child: const Icon(CupertinoIcons.cart, color: AppColors.header),
        ),
        if (!compact) ...[
          const SizedBox(width: 20),
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: AppColors.header,
                      fontSize: 16,
                      fontWeight: FontWeight.w700))),
          const Icon(Icons.arrow_forward, color: AppColors.header),
        ],
      ],
    );
    return CartAddPulse(
        child: Semantics(
      label: 'Открыть корзину: $label',
      button: true,
      excludeSemantics: true,
      child: compact
          ? Material(
              color: const Color(0xFFEEE9F5),
              borderRadius: BorderRadius.circular(22),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                  onTap: () => openCart(context),
                  child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 16),
                      child: content)),
            )
          : DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x200C204D),
                      blurRadius: 14,
                      offset: Offset(0, 4),
                      blurStyle: BlurStyle.outer)
                ],
              ),
              child: ShaderGlassContainer(
                padding: EdgeInsets.zero,
                borderRadius: 22,
                blur: 10,
                liquidBlur: 3,
                liquidThickness: 60,
                liquidRefractiveIndex: 1.4,
                onPressed: () => openCart(context),
                child: DecoratedBox(
                  // A translucent backing keeps the amount readable over food photos.
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(
                          alpha:
                              MediaQuery.highContrastOf(context) ? .92 : .38),
                      borderRadius: BorderRadius.circular(22)),
                  child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      child: content),
                ),
              ),
            ),
    ));
  }
}

/// A single local response to an addition; rebuilding or removing items is quiet.
class CartAddPulse extends StatefulWidget {
  const CartAddPulse({super.key, required this.child});
  final Widget child;
  @override
  State<CartAddPulse> createState() => _CartAddPulseState();
}

class _CartAddPulseState extends State<CartAddPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 360));
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.025)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 35),
    TweenSequenceItem(
        tween: Tween(begin: 1.025, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 65),
  ]).animate(_controller);
  int? _previousCount;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final count = context.watch<CartService>().totalItems;
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced) {
      _controller.reset();
    } else if (_previousCount != null && count > _previousCount!) {
      _controller.forward(from: 0);
    }
    _previousCount = count;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _scale, child: widget.child);
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
