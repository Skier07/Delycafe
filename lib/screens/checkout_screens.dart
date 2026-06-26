import 'package:delycafe/screens/order_payment_screen.dart';
import 'package:delycafe/services/auth_service.dart';
import 'package:delycafe/services/cart_service.dart';
import 'package:delycafe/services/order_api_service.dart';
import 'package:delycafe/ui/components/glass/shader_glass_container.dart';
import 'package:delycafe/ui/tokens/app_colors.dart';
import 'package:delycafe/widgets/checkout/guest_checkout_form.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CheckoutScreens extends StatelessWidget {
  const CheckoutScreens({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFFEF7FF),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.header,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 64,
        titleSpacing: 16,
        title: Row(
          children: [
            ShaderGlassContainer(
              borderRadius: 30,
              onPressed: () => Navigator.pop(context),
              padding: const EdgeInsets.all(8),
              child: const Icon(
                CupertinoIcons.chevron_left_2,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Оформление заказа',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
              ),
            ),
          ],
        ),
      ),
      body: cart.items.isEmpty
          ? const Center(
              child: Text(
                'Корзина пуста',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _CartSummaryCard(cart: cart),
                const SizedBox(height: 24),
                GuestCheckoutForm(
                  cartTotal: cart.totalPrice,
                  initialName: user?.name,
                  initialAddress: user?.checkoutAddress,
                  initialPhone: user?.phone,
                  availableBonuses: user?.bonusBalance ?? 0,
                  firstOrderDiscountAvailable:
                      user?.firstOrderDiscountAvailable ?? false,
                  onSubmit: (data) async {
                    final cartService = context.read<CartService>();

                    if (cartService.items.isEmpty) {
                      throw Exception('Корзина пуста');
                    }

                    final order = await OrderApiService().createOrder(
                      phone: data.phone,
                      customerName: data.name,
                      deliveryType: data.deliveryType.apiValue,
                      address: data.address,
                      addressLocality: data.addressLocality,
                      addressEntrance: data.addressEntrance,
                      addressFloor: data.addressFloor,
                      addressApartment: data.addressApartment,
                      deliveryTimeType: data.urgency.apiValue,
                      deliveryTime: data.deliveryTime ?? '',
                      paymentType: data.paymentMethod.apiValue,
                      comment: data.comment,
                      items: cartService.toOrderApiItems(),
                      bonusSpent: data.bonusSpent,
                    );

                    if (!context.mounted) return;

                    try {
                      await context.read<AuthService>().signInWithPhone(
                            data.phone,
                          );
                    } catch (error) {
                      debugPrint(
                        'Не удалось войти после оформления заказа: $error',
                      );
                    }

                    if (!context.mounted) return;

                    final paymentUrl = order.paymentUrl.trim();

                    if (paymentUrl.isNotEmpty) {
                      final paid = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrderPaymentScreen(
                            orderId: order.id,
                            paymentUrl: paymentUrl,
                            paymentAmount: order.paymentAmount,
                          ),
                        ),
                      );

                      if (!context.mounted) return;

                      if (paid != true) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Заказ №${order.id} создан, но оплата не завершена. '
                              'Его можно оплатить позже из истории заказов.',
                            ),
                          ),
                        );
                        Navigator.pop(context);
                        return;
                      }
                    }

                    cartService.clearCart();

                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          paymentUrl.isNotEmpty
                              ? 'Заказ №${order.id} оплачен и принят в работу'
                              : 'Заказ №${order.id} оформлен. '
                                  'К оплате: ${order.paymentAmount} ₽',
                        ),
                      ),
                    );

                    Navigator.pop(context);
                  },
                ),
              ],
            ),
    );
  }
}

class _CartSummaryCard extends StatelessWidget {
  final CartService cart;

  const _CartSummaryCard({
    required this.cart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ваш заказ',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ...cart.items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.displayTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                        if (item.displayWeight.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            item.displayWeight,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          '${item.unitPrice} ₽ за шт.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.black.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      context.read<CartService>().decreaseCartItem(item);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.remove,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${item.quantity}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      context.read<CartService>().increaseCartItem(item);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.header,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.add,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 70,
                    child: Text(
                      '${item.totalPrice} ₽',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.header,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const Divider(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Товары',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${cart.totalPrice} ₽',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.header,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
