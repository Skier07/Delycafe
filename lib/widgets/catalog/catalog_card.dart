import 'package:delycafe/models/catalog_item.dart';
import 'package:delycafe/screens/catalog/product_detail_screen.dart';
import 'package:delycafe/utils/product_size_feedback.dart';
import 'package:delycafe/widgets/catalog/product_size_picker.dart';
import 'package:delycafe/ui/tokens/app_colors.dart';
import 'package:delycafe/utils/haptic_feedback.dart';
import 'package:delycafe/utils/preorder_availability.dart';
import 'package:delycafe/widgets/catalog/product_image.dart';
import 'package:flutter/material.dart';

typedef CatalogAddToCartCallback = void Function({
  ProductVariant? variant,
});

class CatalogCard extends StatefulWidget {
  /// Reserve space for every text row, including enlarged system fonts.
  static double gridHeight(double width, TextScaler textScaler) {
    final narrow = width < 168;
    double lineHeight(double size, double height, FontWeight weight) {
      final painter = TextPainter(
        text: TextSpan(
          text: 'Ару',
          style: TextStyle(fontSize: size, height: height, fontWeight: weight),
        ),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout();
      final result = painter.height;
      painter.dispose();
      return result;
    }

    final title = lineHeight(narrow ? 14 : 16, 1.2, FontWeight.w700);
    final description = lineHeight(narrow ? 12 : 13, 1.35, FontWeight.normal);
    final price = lineHeight(narrow ? 14 : 16, 1.2, FontWeight.w800);
    final button =
        textScaler.scale(narrow ? 11 : 12) * 1.2 + (narrow ? 14 : 16);
    final footer =
        narrow ? price + 8 + button : (price > button ? price : button);
    return width / 1.2 +
        (narrow ? 18 : 22) +
        title * (narrow ? 2 : 1) +
        (narrow ? 4 : 6) +
        description * (narrow ? 1 : 2) +
        12 +
        footer +
        4;
  }

  final CatalogItem item;
  final CatalogAddToCartCallback? onAddToCart;

  const CatalogCard({
    super.key,
    required this.item,
    this.onAddToCart,
  });

  @override
  State<CatalogCard> createState() => _CatalogCardState();
}

class _CatalogCardState extends State<CatalogCard> {
  bool _choosingSize = false;

  void _openProductDetail() {
    AppHaptics.openProduct();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          item: widget.item,
        ),
      ),
    );
  }

  Future<void> _handleAddToCart() async {
    if (_choosingSize) return;
    if (widget.onAddToCart == null) {
      return;
    }

    if (!catalogItemCanOrderNow(widget.item)) {
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
      return;
    }

    ProductVariant? variant;
    final requestedItem = widget.item;
    if (widget.item.variants.length > 1) {
      _choosingSize = true;
      try {
        variant = await showProductSizePicker(context, widget.item);
      } finally {
        _choosingSize = false;
      }
      if (!mounted || variant == null) return;
      // Catalog refresh can replace this card while the sheet is open.
      if (widget.item.id != requestedItem.id || widget.onAddToCart == null) {
        return;
      }
      final matches = widget.item.variants.where((v) => v.id == variant!.id);
      if (!catalogItemCanOrderNow(widget.item) ||
          matches.isEmpty ||
          matches.first.price != variant.price) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Товар изменился. Пожалуйста, выберите размер ещё раз.')));
        return;
      }
      variant = matches.first;
    } else if (widget.item.variants.isNotEmpty) {
      variant = widget.item.variants.first;
    }
    AppHaptics.productSize(ProductSizeFeedback.fromTitle(variant?.title));
    widget.onAddToCart!(variant: variant);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openProductDetail,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white60,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 2,
                  offset: const Offset(0, 2),
                  // Draw the shadow outside the card.
                  blurStyle: BlurStyle.outer,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 1.2,
                        child: ProductImage(
                          image: widget.item.image,
                          variants:
                              widget.item.imageVariants[widget.item.image] ??
                                  const [],
                          fit: BoxFit.contain,
                        ),
                      ),
                      if (widget.item.isHit || widget.item.isNew)
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.item.isHit)
                                const _StatusBadge(
                                  text: 'HOT',
                                  color: Color(0xFFEE101B),
                                ),
                              if (widget.item.isHit && widget.item.isNew)
                                const SizedBox(height: 8),
                              if (widget.item.isNew)
                                const _StatusBadge(
                                  text: 'New',
                                  color: Color(0xFF7BEE10),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 168;
                        final titleSize = narrow ? 14.0 : 16.0;
                        final priceSize = narrow ? 14.0 : 16.0;
                        final buttonPadH = narrow ? 8.0 : 12.0;
                        final buttonPadV = narrow ? 7.0 : 8.0;
                        final buttonFont = narrow ? 11.0 : 12.0;

                        final canOrderNow = catalogItemCanOrderNow(widget.item);

                        Widget cartButton({required bool expanded}) {
                          final button = Opacity(
                            opacity: 1,
                            child: Container(
                              width: expanded ? double.infinity : null,
                              height: MediaQuery.textScalerOf(context)
                                          .scale(buttonFont) *
                                      1.2 +
                                  buttonPadV * 2,
                              alignment: Alignment.center,
                              padding: EdgeInsets.symmetric(
                                horizontal: buttonPadH,
                                vertical: buttonPadV,
                              ),
                              decoration: BoxDecoration(
                                color: canOrderNow
                                    ? AppColors.header
                                    : Colors.grey.shade400,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  canOrderNow
                                      ? (widget.item.variants.length > 1
                                          ? 'Выбрать'
                                          : 'В корзину')
                                      : 'Недоступно',
                                  maxLines: 1,
                                  softWrap: false,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: buttonFont,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ),
                          );

                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _handleAddToCart,
                            child: button,
                          );
                        }

                        return ColoredBox(
                          color: Colors.white.withValues(alpha: 0.96),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              narrow ? 10 : 12,
                              narrow ? 10 : 12,
                              narrow ? 10 : 12,
                              narrow ? 8 : 10,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.item.title,
                                  maxLines: narrow ? 2 : 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: titleSize,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                    height: 1.2,
                                  ),
                                ),
                                SizedBox(height: narrow ? 4 : 6),
                                Text(
                                  widget.item.description,
                                  maxLines: narrow ? 1 : 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: narrow ? 12 : 13,
                                    height: 1.35,
                                    color: Colors.black.withValues(alpha: 0.55),
                                  ),
                                ),
                                const Spacer(),
                                if (narrow) ...[
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '${widget.item.price} ₽',
                                      maxLines: 1,
                                      softWrap: false,
                                      style: TextStyle(
                                        fontSize: priceSize,
                                        height: 1.2,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  cartButton(expanded: true),
                                ] else
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${widget.item.price} ₽',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: priceSize,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          heightFactor: 1,
                                          child: cartButton(expanded: false),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.90),
                    width: 0.8,
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.all(1),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(19),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.035),
                      width: 0.6,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _StatusBadge({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 45),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
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
