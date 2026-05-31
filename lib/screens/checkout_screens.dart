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
                  onSubmit: (data) async {
                    final cartService = context.read<CartService>();

                    if (cartService.items.isEmpty) {
                      throw Exception('Корзина пуста');
                    }

                    final orderId = await OrderApiService().createOrder(
                      phone: data.phone,
                      customerName: data.name,
                      deliveryType: data.deliveryType.apiValue,
                      address: data.address,
                      deliveryTimeType: data.urgency.apiValue,
                      deliveryTime: data.deliveryTime ?? '',
                      paymentType: data.paymentMethod.apiValue,
                      comment: data.comment,
                      items: cartService.toOrderApiItems(),
                    );

                    cartService.clearCart();

                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Заказ №$orderId успешно оформлен'),
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

                  // Кнопка -
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
                      child: const Icon(Icons.remove, size: 20),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Количество
                  Text(
                    '${item.quantity}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Кнопка +
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
