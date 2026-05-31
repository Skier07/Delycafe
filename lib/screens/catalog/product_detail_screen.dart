import 'package:delycafe/models/catalog_item.dart';
import 'package:delycafe/services/cart_service.dart';
import 'package:delycafe/ui/components/glass/shader_glass_container.dart';
import 'package:delycafe/ui/tokens/app_colors.dart';
import 'package:delycafe/widgets/catalog/product_image.dart';
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
    _selectedVariant = _getInitialVariant();
  }

  ProductVariant? _getInitialVariant() {
    if (widget.item.variants.isEmpty) {
      return null;
    }

    for (final variant in widget.item.variants) {
      if (variant.title == 'Средняя') {
        return variant;
      }
    }

    return widget.item.variants.first;
  }

  int get _currentPrice {
    return _selectedVariant?.price ?? widget.item.price;
  }

  String get _currentWeight {
    final variantWeight = _selectedVariant?.weight.trim() ?? '';
    final itemWeight = widget.item.weight?.trim() ?? '';

    if (variantWeight.isNotEmpty) {
      return variantWeight;
    }

    if (itemWeight.isNotEmpty) {
      return itemWeight;
    }

    return 'за порцию';
  }

  void _addToCart() {
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
                              text: 'HOT',
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
                                children: List.generate(
                                  item.variants.length,
                                  (index) {
                                    final variant = item.variants[index];
                                    final selected =
                                        _selectedVariant?.id == variant.id;

                                    final variantWeight = variant.weight.trim();

                                    final variantInfo = variantWeight.isNotEmpty
                                        ? '$variantWeight · ${variant.price} ₽'
                                        : '${variant.price} ₽';

                                    return Expanded(
                                      child: Padding(
                                        padding: EdgeInsets.only(
                                          right:
                                              index == item.variants.length - 1
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
                                            duration: const Duration(
                                              milliseconds: 160,
                                            ),
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
                                                    : Colors.black.withValues(
                                                        alpha: 0.12,
                                                      ),
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
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: Text(
                                                    variantInfo,
                                                    maxLines: 1,
                                                    style: TextStyle(
                                                      color: selected
                                                          ? Colors.white
                                                              .withValues(
                                                              alpha: 0.85,
                                                            )
                                                          : Colors.black54,
                                                      fontSize: infoFontSize,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      _InfoBlock(
                        title: 'Описание',
                        child: Text(
                          item.description.trim().isNotEmpty
                              ? item.description
                              : 'Описание товара скоро появится.',
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
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
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
                          color: AppColors.header,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Text(
                          'В корзину',
                          style: TextStyle(
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
        return 'Отличный вариант для тех, кто любит насыщенный вкус, тянущийся сыр и сытную подачу. Подходит как для одного плотного приёма пищи, так и для компании.';
      case 'Шаурма':
        return 'Сытный вариант для быстрого перекуса. Хорошо подойдёт, когда хочется горячее блюдо без долгого ожидания.';
      case 'Бургеры':
        return 'Хороший выбор для любителей сочной начинки, мягкой булочки и насыщенного вкуса.';
      case 'Фастфуд':
        return 'Удобная позиция к основному заказу или как самостоятельный перекус. Особенно хорошо подходит для компании.';
      case 'Картошечка в фольге':
        return 'Сытная горячая позиция, которую можно взять отдельно или дополнить начинкой по вкусу.';
      case 'Соусы':
        return 'Подходит как дополнение к картошке, шаурме, бургерам, закускам и другим позициям меню.';
      case 'Напитки':
        return 'Хорошо дополняет заказ и помогает сбалансировать вкус основных блюд.';
      case 'Десерты':
        return 'Подходит в конце заказа, если хочется добавить что-то сладкое и завершить приём пищи.';
      case 'Паста':
        return 'Горячее и сытное блюдо с насыщенным вкусом. Подходит как самостоятельная позиция.';
      case 'Пироги':
        return 'Сытная выпечка для одного или нескольких человек. Хороший вариант к обеду или ужину.';
      case 'Салаты':
        return 'Лёгкое дополнение к основному блюду или самостоятельная позиция для тех, кто хочет что-то свежее.';
      case 'Супы':
        return 'Горячее первое блюдо, которое хорошо подходит для полноценного обеда.';
      default:
        return 'Вкусная позиция из меню, которую можно добавить к основному заказу или взять как самостоятельный вариант.';
    }
  }
}

class _ProductHero extends StatelessWidget {
  final CatalogItem item;

  const _ProductHero({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ProductImage(
            image: item.image,
            width: double.infinity,
            height: 320,
            fit: BoxFit.cover,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.10),
                  Colors.black.withValues(alpha: 0.34),
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
                    text: 'HOT',
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
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
        ),
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

  const _CategoryChip({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: AppColors.header.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.header.withValues(alpha: 0.12),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.header,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _BuildText extends StatelessWidget {
  final String text;

  const _BuildText({
    required this.text,
  });

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
