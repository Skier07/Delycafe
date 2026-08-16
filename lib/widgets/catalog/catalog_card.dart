import 'package:delycafe/models/catalog_item.dart';
import 'package:delycafe/screens/catalog/product_detail_screen.dart';
import 'package:delycafe/ui/animations/add_to_cart_droplet_animation.dart';
import 'package:delycafe/ui/tokens/app_colors.dart';
import 'package:delycafe/widgets/catalog/product_image.dart';
import 'package:flutter/material.dart';

typedef CatalogAddToCartCallback = void Function({
  AddToCartDropletOrigin? origin,
});

class CatalogCard extends StatefulWidget {
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
  final GlobalKey _cartButtonKey = GlobalKey();
  bool _hideCartButton = false;

  void _openProductDetail() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          item: widget.item,
          onAddToCart: widget.onAddToCart == null
              ? null
              : () => widget.onAddToCart!.call(),
        ),
      ),
    );
  }

  void _handleAddToCart() {
    if (widget.onAddToCart == null) {
      return;
    }

    final renderBox =
        _cartButtonKey.currentContext?.findRenderObject() as RenderBox?;

    AddToCartDropletOrigin? origin;

    if (renderBox != null && renderBox.hasSize) {
      final topLeft = renderBox.localToGlobal(Offset.zero);

      origin = AddToCartDropletOrigin(
        globalCenter: topLeft + renderBox.size.center(Offset.zero),
        buttonSize: renderBox.size,
        color: AppColors.header,
        borderRadius: 14,
      );
    }

    setState(() => _hideCartButton = true);
    widget.onAddToCart!(origin: origin);

    Future<void>.delayed(AddToCartDropletAnimation.duration, () {
      if (mounted) {
        setState(() => _hideCartButton = false);
      }
    });
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

                        Widget cartButton({required bool expanded}) {
                          final button = Opacity(
                            opacity: _hideCartButton ? 0 : 1,
                            child: Container(
                              key: _cartButtonKey,
                              width: expanded ? double.infinity : null,
                              alignment: Alignment.center,
                              padding: EdgeInsets.symmetric(
                                horizontal: buttonPadH,
                                vertical: buttonPadV,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.header,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'В корзину',
                                  maxLines: 1,
                                  softWrap: false,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: buttonFont,
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

                        return Padding(
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
                                Text(
                                  '${widget.item.price} ₽',
                                  style: TextStyle(
                                    fontSize: priceSize,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black87,
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
                                        child: cartButton(expanded: false),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
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
