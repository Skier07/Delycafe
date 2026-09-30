import 'package:flutter/material.dart';
import 'package:delycafe/models/catalog_item.dart';
import 'package:delycafe/ui/tokens/app_colors.dart';
import 'package:delycafe/utils/haptic_feedback.dart';
import 'package:delycafe/utils/product_size_feedback.dart';
import 'package:delycafe/widgets/catalog/product_image.dart';

class SizePreview extends StatelessWidget {
  const SizePreview({super.key, required this.title, required this.child});
  final String? title;
  final Widget child;
  @override
  Widget build(BuildContext context) => AnimatedScale(
        scale: ProductSizeFeedback.fromTitle(title).imageScale,
        duration: Duration(
            milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 260),
        curve: Curves.easeOutCubic,
        child: child,
      );
}

class SizePrice extends StatelessWidget {
  const SizePrice({super.key, required this.price, required this.style});
  final int price;
  final TextStyle style;
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: Duration(
            milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 180),
        child: Text('$price ₽', key: ValueKey(price), style: style),
      );
}

Future<ProductVariant?> showProductSizePicker(
        BuildContext context, CatalogItem item) =>
    showModalBottomSheet<ProductVariant>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      backgroundColor: const Color(0xFFFEF7FF),
      builder: (_) => _ProductSizePicker(item: item),
    );

class _ProductSizePicker extends StatefulWidget {
  const _ProductSizePicker({required this.item});
  final CatalogItem item;
  @override
  State<_ProductSizePicker> createState() => _ProductSizePickerState();
}

class _ProductSizePickerState extends State<_ProductSizePicker> {
  bool _submitted = false;
  late ProductVariant selected = widget.item.variants.firstWhere(
    (v) => ProductSizeFeedback.fromTitle(v.title) == ProductSizeFeedback.medium,
    orElse: () => widget.item.variants.first,
  );
  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(item.title,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          SizedBox(
              height: 190,
              child: SizePreview(
                  title: selected.title,
                  child: ProductImage(
                      image: item.image,
                      variants: item.imageVariants[item.image] ?? const [],
                      fit: BoxFit.contain))),
          const Text('Выберите размер'),
          const SizedBox(height: 12),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              children: item.variants
                  .map((variant) => ChoiceChip(
                        label: Text(
                            '${variant.title}\n${variant.weight.isEmpty ? '' : '${variant.weight} · '}${variant.price} ₽',
                            textAlign: TextAlign.center),
                        selected: selected.id == variant.id,
                        onSelected: (_) {
                          if (selected.id == variant.id) return;
                          AppHaptics.productSize(
                              ProductSizeFeedback.fromTitle(variant.title));
                          setState(() => selected = variant);
                        },
                      ))
                  .toList()),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
                child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizePrice(
                        price: selected.price,
                        style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.header)))),
            FilledButton(
                onPressed: _submitted
                    ? null
                    : () {
                        if (_submitted) return;
                        setState(() => _submitted = true);
                        Navigator.pop(context, selected);
                      },
                style: FilledButton.styleFrom(
                    enableFeedback: false,
                    backgroundColor: AppColors.header,
                    minimumSize: const Size(140, 52)),
                child: const Text('Добавить')),
          ]),
        ]),
      ),
    );
  }
}
