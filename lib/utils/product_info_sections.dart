import 'package:delycafe/models/product_info_block.dart';
import 'package:flutter/material.dart';

class ProductInfoSection {
  final String title;
  final List<ProductInfoBlock> blocks;

  const ProductInfoSection({
    required this.title,
    required this.blocks,
  });
}

List<ProductInfoSection> groupProductInfoBlocks(List<ProductInfoBlock> blocks) {
  final sections = <ProductInfoSection>[];
  final indexBySection = <String, int>{};

  for (final block in blocks) {
    final key = block.section.isNotEmpty ? block.section : block.title;
    final existingIndex = indexBySection[key];

    if (existingIndex == null) {
      indexBySection[key] = sections.length;
      sections.add(
        ProductInfoSection(
          title: block.title,
          blocks: [block],
        ),
      );
      continue;
    }

    final existing = sections[existingIndex];
    sections[existingIndex] = ProductInfoSection(
      title: existing.title,
      blocks: [...existing.blocks, block],
    );
  }

  return sections;
}

List<Widget> buildProductInfoSectionWidgets(
  List<ProductInfoSection> sections, {
  required Widget Function(ProductInfoLine line, {bool warning}) lineBuilder,
}) {
  final widgets = <Widget>[];

  for (final section in sections) {
    final lineWidgets = <Widget>[];

    for (final block in section.blocks) {
      for (final line in block.resolvedLines()) {
        if (lineWidgets.isNotEmpty) {
          lineWidgets.add(const SizedBox(height: 8));
        }

        lineWidgets.add(
          lineBuilder(
            line,
            warning: block.isWarning,
          ),
        );
      }
    }

    if (lineWidgets.isEmpty) {
      continue;
    }

    widgets.add(
      _InfoSectionCard(
        title: section.title,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: lineWidgets,
        ),
      ),
    );
    widgets.add(const SizedBox(height: 14));
  }

  if (widgets.isNotEmpty) {
    widgets.removeLast();
  }

  return widgets;
}

class _InfoSectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _InfoSectionCard({
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
