import 'package:delycafe/models/catalog_item.dart';
import 'package:delycafe/services/cart_service.dart';
import 'package:delycafe/ui/components/glass/shader_glass_container.dart';
import 'package:delycafe/ui/tokens/app_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ProductDetailScreen extends StatefulWidget {
  final CatalogItem item;
  final VoidCallback? onAddToCart;

  const ProductDetailScreen({
    super.key,
    required this.item,
    this.onAddToCart,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  ProductVariant? _selectedVariant;

  @override
  void initState() {
    super.initState();

    if (widget.item.variants.isNotEmpty) {
      _selectedVariant = widget.item.variants.first;
    }
  }

  int get _currentPrice {
    return _selectedVariant?.price ?? widget.item.price;
  }

  String get _currentWeight {
    return _selectedVariant?.weight ?? widget.item.weight ?? 'за порцию';
  }

  void _addToCart() {
    if (!widget.item.isAvailable) return;

    context.read<CartService>().addToCart(
          widget.item,
          variant: _selectedVariant,
        );

    final variantText =
        _selectedVariant != null ? ' (${_selectedVariant!.title})' : '';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.item.title}$variantText добавлен в корзину'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Scaffold(
      backgroundColor: const Color(0xFFFEF7FF),
      body: Stack(
        children: [
          Column(
            children: [
              _ProductHero(item: item),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _CategoryChip(text: item.category),
                          const SizedBox(width: 8),
                          if (item.isHit)
                            const _StatusChip(
                              text: 'ХИТ',
                              color: Color(0xFFEE101B),
                            ),
                          if (item.isHit && item.isNew)
                            const SizedBox(width: 8),
                          if (item.isNew)
                            const _StatusChip(
                              text: 'New',
                              color: Color(0xFF7BEE10),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$_currentPrice ₽',
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: AppColors.header,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _currentWeight,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                      if (item.variants.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        _InfoBlock(
                          title: 'Выберите размер',
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final isSmallPhone = constraints.maxWidth < 330;

                              final double gap = isSmallPhone ? 6 : 8;
                              final double horizontalPadding =
                                  isSmallPhone ? 6 : 10;
                              final double verticalPadding =
                                  isSmallPhone ? 12 : 16;
                              final double titleFontSize =
                                  isSmallPhone ? 14 : 16;
                              final double infoFontSize =
                                  isSmallPhone ? 12 : 14;

                              return Row(
                                children: List.generate(item.variants.length,
                                    (index) {
                                  final variant = item.variants[index];
                                  final selected =
                                      _selectedVariant?.id == variant.id;

                                  return Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        right: index == item.variants.length - 1
                                            ? 0
                                            : gap,
                                      ),
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedVariant = variant;
                                          });
                                        },
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 160),
                                          padding: EdgeInsets.symmetric(
                                            horizontal: horizontalPadding,
                                            vertical: verticalPadding,
                                          ),
                                          decoration: BoxDecoration(
                                            color: selected
                                                ? AppColors.header
                                                : Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            border: Border.all(
                                              color: selected
                                                  ? AppColors.header
                                                  : Colors.black
                                                      .withValues(alpha: 0.12),
                                            ),
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  variant.title,
                                                  maxLines: 1,
                                                  style: TextStyle(
                                                    color: selected
                                                        ? Colors.white
                                                        : Colors.black87,
                                                    fontSize: titleFontSize,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  '${variant.weight} · ${variant.price} ₽',
                                                  maxLines: 1,
                                                  style: TextStyle(
                                                    color: selected
                                                        ? Colors.white
                                                            .withValues(
                                                                alpha: 0.85)
                                                        : Colors.black54,
                                                    fontSize: infoFontSize,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              );
                            },
                          ),
                        ),
                      ],
                      if (item.shortDescription != null &&
                          item.shortDescription!.trim().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.header.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Коротко о товаре',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.header,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item.shortDescription!,
                                style: TextStyle(
                                  fontSize: 15.5,
                                  height: 1.55,
                                  color: Colors.black.withValues(alpha: 0.82),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      _InfoBlock(
                        title: 'Описание',
                        child: Text(
                          item.description,
                          style: TextStyle(
                            fontSize: 15.5,
                            height: 1.6,
                            color: Colors.black.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _InfoBlock(
                        title: 'Почему стоит попробовать',
                        child: Text(
                          _buildExtendedDescription(item),
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.65,
                            color: Colors.black.withValues(alpha: 0.78),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const _InfoBlock(
                        title: 'Что важно знать',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _BuildText(
                              text:
                                  'Состав и внешний вид могут немного отличаться в зависимости от партии ингредиентов.',
                            ),
                            SizedBox(height: 8),
                            _BuildText(
                              text: 'Блюдо готовится после оформления заказа.',
                            ),
                            SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ShaderGlassContainer(
                borderRadius: 30,
                onPressed: () => Navigator.pop(context),
                padding: const EdgeInsets.all(8),
                child: const Icon(
                  CupertinoIcons.chevron_left_2,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            height: 76,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        '$_currentPrice ₽',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.header,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 170,
                    height: double.infinity,
                    child: GestureDetector(
                      onTap: _addToCart,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color:
                              item.isAvailable ? AppColors.header : Colors.grey,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          item.isAvailable ? 'В корзину' : 'Недоступно',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _buildExtendedDescription(CatalogItem item) {
    switch (item.category) {
      case 'Пицца':
        return 'Это отличный вариант для тех, кто любит насыщенный вкус, тянущийся сыр и сытную подачу. '
            'Подходит как для одного плотного приёма пищи, так и для компании. '
            'Хорошо сочетается с холодными напитками и соусами.';
      case 'Закуски':
        return 'Хороший выбор, если хочется добавить к заказу что-то хрустящее, горячее и удобное для компании. '
            'Отлично дополняет основное блюдо и делает заказ более насыщенным.';
      case 'Напитки':
        return 'Идеально дополняет заказ и помогает сбалансировать вкус основных блюд. '
            'Подходит как к пицце, так и к закускам.';
      case 'Комбо':
        return 'Удобный вариант, если хочется взять сразу готовое сочетание без долгого выбора. '
            'Хорошо подходит для быстрого заказа на одного или на компанию.';
      default:
        return 'Вкусная позиция из меню, которую можно добавить к основному заказу или взять как самостоятельный вариант.';
    }
  }
}

class _ProductHero extends StatelessWidget {
  final CatalogItem item;
  const _ProductHero({required this.item});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            item.image,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.header.withValues(alpha: 0.95),
                      const Color(0xFF1E3A8A).withValues(alpha: 0.82),
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    _categoryIcon(item.category),
                    size: 84,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              );
            },
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.18),
                  Colors.black.withValues(alpha: 0.45),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 18,
            child: Row(
              children: [
                if (item.isHit)
                  const _StatusChip(
                    text: 'ХИТ',
                    color: Color(0xFFEE101B),
                  ),
                if (item.isHit && item.isNew) const SizedBox(width: 8),
                if (item.isNew)
                  const _StatusChip(
                    text: 'New',
                    color: Color(0xFF7BEE10),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  final String title;
  final Widget child;

  const _InfoBlock({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String text;
  final Color color;

  const _StatusChip({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 52),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String text;

  const _CategoryChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 7,
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.header,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _BuildText extends StatelessWidget {
  final String text;
  const _BuildText({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 7),
          child: Icon(
            Icons.circle,
            size: 6,
            color: AppColors.header,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.55,
              color: Colors.black.withValues(alpha: 0.78),
            ),
          ),
        ),
      ],
    );
  }
}

IconData _categoryIcon(String category) {
  switch (category) {
    case 'Пицца':
      return Icons.local_pizza;
    case 'Шаурма':
      return Icons.lunch_dining;
    case 'Бургеры':
      return Icons.fastfood;
    case 'Напитки':
      return Icons.local_drink;
    default:
      return Icons.restaurant_menu;
  }
}
