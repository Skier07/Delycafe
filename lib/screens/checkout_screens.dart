import 'package:delycafe/models/order.dart';
import 'package:delycafe/screens/addresses_screen.dart';
import 'package:delycafe/services/address_service.dart';
import 'package:delycafe/services/cart_service.dart';
import 'package:delycafe/services/order_service.dart';
import 'package:delycafe/ui/components/buttons/auth_button.dart';
import 'package:delycafe/ui/components/glass/shader_glass_container.dart';
import 'package:delycafe/ui/tokens/app_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CheckoutScreens extends StatefulWidget {
  const CheckoutScreens({super.key});

  @override
  State<CheckoutScreens> createState() => _CheckoutScreensState();
}

class _CheckoutScreensState extends State<CheckoutScreens> {
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final addressService = context.read<AddressService>();

    if (addressService.selectedAddress != null) {
      _addressController.text = addressService.selectedAddress!.address;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final addressService = context.read<AddressService>();

    if (addressService.selectedAddress != null &&
        _addressController.text.isEmpty) {
      _addressController.text = addressService.selectedAddress!.address;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();
    final addressService = context.watch<AddressService>();
    final selected = addressService.selectedAddress;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.header,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
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
              child: Text('Корзина пуста'),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Товары
                  Column(
                    children: cart.items.map((item) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            // Название
                            Expanded(
                              child: Text(
                                item.product.title,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ),

                            // Кнопка -
                            GestureDetector(
                              onTap: () {
                                context
                                    .read<CartService>()
                                    .decreaseQuantity(item.product.id);
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
                                context
                                    .read<CartService>()
                                    .increaseQuantity(item.product.id);
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

                            // Цена
                            Text(
                              '${item.product.price * item.quantity} ₽',
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Итог
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Итого:',
                        style: TextStyle(fontSize: 20),
                      ),
                      Text(
                        '${cart.totalPrice} ₽',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Телефон
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Телефон',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Адрес
                  if (selected != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.header.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selected.address,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  TextField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      labelText: 'Адрес доставки',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddressesScreen(),
                        ),
                      );

                      final addressService = context.read<AddressService>();

                      if (addressService.selectedAddress != null) {
                        setState(() {
                          _addressController.text =
                              addressService.selectedAddress!.address;
                        });
                      }
                    },
                    child: const Text('Выбрать из сохранённых'),
                  ),

                  const SizedBox(height: 16),

                  // Комментарий
                  TextField(
                    controller: _commentController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Комментарий',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Кнопка
                  SizedBox(
                    child: AuthButton(
                      onPressed: () {
                        _submitOrder(context);
                      },
                      text: 'Оформить заказ',
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _submitOrder(BuildContext context) {
    final cart = context.read<CartService>();
    final orderService = context.read<OrderService>();

    if (_phoneController.text.isEmpty || _addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполни телефон и адрес')),
      );
      return;
    }

    final order = Order(
      items:
          cart.items.map((e) => '${e.product.title} x${e.quantity}').toList(),
      totalPrice: cart.totalPrice,
      date: DateTime.now(),
    );
    orderService.addOrder(order);

    cart.clearCart();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Заказ оформлен (mock)')),
    );
    // context.read<CartService>().clearCart();
    Navigator.pop(context);
  }
}
