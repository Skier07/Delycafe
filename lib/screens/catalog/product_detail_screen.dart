import 'package:delycafe/models/catalog_item.dart';
import 'package:delycafe/models/product_info_block.dart';
import 'package:delycafe/services/cart_service.dart';
import 'package:delycafe/ui/components/glass/shader_glass_container.dart';
import 'package:delycafe/ui/tokens/app_colors.dart';
import 'package:delycafe/utils/haptic_feedback.dart';
import 'package:delycafe/utils/preorder_availability.dart';
import 'package:delycafe/utils/product_info_sections.dart';
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
    if (!catalogItemCanOrderNow(widget.item)) {
      _showCannotOrderMessage();
      return;
    }

    AppHaptics.addToCart();
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

  void _showCannotOrderMessage() {
    final reason = catalogItemCannotOrderReason(widget.item).trim();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          reason.isNotEmpty
              ? reason
              : 'Сейчас этот товар недоступен для заказа.',
        ),
      ),
    );
  }

  List<ProductInfoSection> _infoSections(CatalogItem item) {
    return groupProductInfoBlocks(item.infoBlocks ?? []);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final canOrderNow = catalogItemCanOrderNow(item);

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
                      if (!canOrderNow) ...[
                        const SizedBox(height: 14),
                        Text(
                          catalogItemCannotOrderReason(item).isNotEmpty
                              ? catalogItemCannotOrderReason(item)
                              : 'Сейчас этот товар недоступен для заказа.',
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFD32F2F),
                          ),
                        ),
                      ],
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
                      ...buildProductInfoSectionWidgets(
                        _infoSections(item),
                        lineBuilder: (line, {bool warning = false}) {
                          if (warning) {
                            return Text(
                              line.text,
                              style: const TextStyle(
                                fontSize: 14.5,
                                height: 1.55,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFD32F2F),
                              ),
                            );
                          }

                          return _InfoLineWidget(line: line);
                        },
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
                      onTap: canOrderNow ? _addToCart : _showCannotOrderMessage,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: canOrderNow
                              ? AppColors.header
                              : Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          canOrderNow ? 'В корзину' : 'Недоступно',
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
}

class _ProductHero extends StatefulWidget {
  final CatalogItem item;

  const _ProductHero({
    required this.item,
  });

  @override
  State<_ProductHero> createState() => _ProductHeroState();
}

class _ProductHeroState extends State<_ProductHero> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.item.galleryImages;
    final item = widget.item;

    return SizedBox(
      height: 320,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (images.length <= 1)
            ProductImage(
              image: images.isNotEmpty ? images.first : item.image,
              width: double.infinity,
              height: 320,
              fit: BoxFit.cover,
            )
          else
            PageView.builder(
              controller: _pageController,
              itemCount: images.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                return ProductImage(
                  image: images[index],
                  width: double.infinity,
                  height: 320,
                  fit: BoxFit.cover,
                );
              },
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
          if (images.length > 1)
            Positioned(
              top: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentPage + 1}/${images.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          if (images.length > 1)
            Positioned(
              bottom: 52,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(images.length, (index) {
                  final selected = index == _currentPage;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: selected ? 18 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  );
                }),
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

class _InfoLineWidget extends StatelessWidget {
  final ProductInfoLine line;

  const _InfoLineWidget({
    required this.line,
  });

  double get _fontSize {
    switch (line.fontSize) {
      case 'small':
        return 13;
      case 'large':
        return 16.5;
      case 'normal':
      default:
        return 14.5;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (line.marker != 'none') ...[
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: _MarkerWidget(line: line),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(
            line.text,
            style: TextStyle(
              fontSize: _fontSize,
              height: 1.55,
              fontWeight: line.bold ? FontWeight.w700 : FontWeight.w400,
              fontStyle: line.italic ? FontStyle.italic : FontStyle.normal,
              decoration: line.underline ? TextDecoration.underline : null,
              color: Colors.black.withValues(alpha: 0.78),
            ),
          ),
        ),
      ],
    );
  }
}

class _MarkerWidget extends StatelessWidget {
  final ProductInfoLine line;

  const _MarkerWidget({
    required this.line,
  });

  @override
  Widget build(BuildContext context) {
    switch (line.marker) {
      case 'dash':
        return Text(
          '—',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.header,
          ),
        );
      case 'number':
        return Text(
          '${line.number > 0 ? line.number : 1}.',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.header,
          ),
        );
      case 'bullet':
      default:
        return const Icon(
          Icons.circle,
          size: 6,
          color: AppColors.header,
        );
    }
  }
}
