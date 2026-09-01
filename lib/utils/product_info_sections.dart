import 'package:delycafe/models/catalog_item.dart';
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
  final grouped = <String, List<ProductInfoBlock>>{};

  for (final block in blocks) {
    final key = block.section.isNotEmpty ? block.section : block.title;
    grouped.putIfAbsent(key, () => []).add(block);
  }

  const sectionOrder = ['why_try', 'important'];
  final sections = <ProductInfoSection>[];

  for (final sectionKey in sectionOrder) {
    final sectionBlocks = grouped[sectionKey];

    if (sectionBlocks == null || sectionBlocks.isEmpty) {
      continue;
    }

    sections.add(
      ProductInfoSection(
        title: sectionBlocks.first.title,
        blocks: sectionBlocks,
      ),
    );
  }

  for (final entry in grouped.entries) {
    if (sectionOrder.contains(entry.key)) {
      continue;
    }

    sections.add(
      ProductInfoSection(
        title: entry.value.first.title,
        blocks: entry.value,
      ),
    );
  }

  return sections;
}

List<ProductInfoSection> legacyProductInfoSections(CatalogItem item) {
  return [
    ProductInfoSection(
      title: 'Почему стоит попробовать',
      blocks: [
        ProductInfoBlock(
          section: 'why_try',
          title: 'Почему стоит попробовать',
          text: _legacyWhyTryText(item.category),
        ),
      ],
    ),
    ProductInfoSection(
      title: 'Что важно знать',
      blocks: [
        ProductInfoBlock(
          section: 'important',
          title: 'Что важно знать',
          text:
              'Состав и внешний вид могут немного отличаться в зависимости от партии ингредиентов.',
        ),
        ProductInfoBlock(
          section: 'important',
          title: 'Что важно знать',
          text: 'Блюдо готовится после оформления заказа.',
        ),
      ],
    ),
  ];
}

String _legacyWhyTryText(String category) {
  switch (category) {
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

List<Widget> buildProductInfoSectionWidgets(
  List<ProductInfoSection> sections, {
  required Widget Function(String text, {bool warning}) lineBuilder,
}) {
  final widgets = <Widget>[];

  for (final section in sections) {
    widgets.add(
      _InfoSectionCard(
        title: section.title,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < section.blocks.length; index++) ...[
              if (index > 0) const SizedBox(height: 8),
              lineBuilder(
                section.blocks[index].text,
                warning: section.blocks[index].isWarning,
              ),
            ],
          ],
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
