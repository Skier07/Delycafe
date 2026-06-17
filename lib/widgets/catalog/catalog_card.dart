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
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.item.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: Colors.black.withValues(alpha: 0.55),
                            ),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Text(
                                '${widget.item.price} ₽',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black87,
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _handleAddToCart,
                                child: Opacity(
                                  opacity: _hideCartButton ? 0 : 1,
                                  child: Container(
                                    key: _cartButtonKey,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.header,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Text(
                                      'В корзину',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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
