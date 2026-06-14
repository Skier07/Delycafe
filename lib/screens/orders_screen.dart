import 'package:delycafe/models/order.dart';
import 'package:delycafe/services/auth_service.dart';
import 'package:delycafe/services/order_service.dart';
import 'package:delycafe/ui/components/glass/shader_glass_container.dart';
import 'package:delycafe/ui/tokens/app_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrders();
    });
  }

  Future<void> _loadOrders() async {
    final user = context.read<AuthService>().currentUser;

    if (user == null) {
      return;
    }

    await context.read<OrderService>().loadOrders(
          phone: user.phone,
        );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final orderService = context.watch<OrderService>();
    final orders = orderService.orders;

    return Scaffold(
      backgroundColor: const Color(0xFFFEF7FF),
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
              'История заказов',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.header,
        onRefresh: _loadOrders,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (user == null)
              const _OrdersEmptyState(
                title: 'Вы не авторизованы',
                subtitle: 'Войдите по номеру телефона, чтобы увидеть заказы.',
              )
            else if (orderService.isLoading && orders.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 100),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (orderService.errorMessage != null)
              _OrdersEmptyState(
                title: 'Не удалось загрузить заказы',
                subtitle: orderService.errorMessage!,
              )
            else if (orders.isEmpty)
              const _OrdersEmptyState(
                title: 'Пока нет заказов',
                subtitle: 'После оформления заказа он появится здесь.',
              )
            else
              ...orders.map(
                (order) => _OrderCard(order: order),
              ),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;

  const _OrderCard({
    required this.order,
  });

  @override
  Widget build(BuildContext context) {
    final statusText =
        order.statusLabel.isNotEmpty ? order.statusLabel : order.status;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
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
          Row(
            children: [
              Expanded(
                child: Text(
                  'Заказ №${order.id}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _StatusChip(text: statusText),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            order.formattedDate,
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.55),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          if (order.items.isEmpty)
            const Text(
              'Состав заказа не указан',
              style: TextStyle(
                color: Colors.black54,
              ),
            )
          else
            ...order.items.map(
              (item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.titleWithQuantity,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${item.totalPrice} ₽',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          const Divider(height: 24),
          _PriceRow(
            title: 'Товары',
            value: order.productsTotal,
          ),
          if (order.deliveryPrice > 0)
            _PriceRow(
              title: 'Доставка',
              value: order.deliveryPrice,
            ),
          if (order.discountAmount > 0)
            _PriceRow(
              title: 'Скидка',
              value: -order.discountAmount,
            ),
          if (order.bonusSpent > 0)
            _PriceRow(
              title: 'Списано бонусов',
              value: -order.bonusSpent,
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Итого',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${order.totalPrice} ₽',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: AppColors.header,
                ),
              ),
            ],
          ),
          if (order.bonusEarned > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Начислено бонусов: ${order.bonusEarned}',
              style: const TextStyle(
                color: AppColors.header,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (order.address.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              order.address,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.65),
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String text;

  const _StatusChip({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final label = text.isEmpty ? 'Новый' : text;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: AppColors.header.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.header,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String title;
  final int value;

  const _PriceRow({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final prefix = value < 0 ? '- ' : '';
    final cleanValue = value.abs();

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.60),
              ),
            ),
          ),
          Text(
            '$prefix$cleanValue ₽',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrdersEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _OrdersEmptyState({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 100),
      child: Column(
        children: [
          const Icon(
            CupertinoIcons.cart,
            size: 58,
            color: AppColors.header,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.58),
            ),
          ),
        ],
      ),
    );
  }
}
