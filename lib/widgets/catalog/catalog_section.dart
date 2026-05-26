import 'package:delycafe/data/generated_catalog.dart';
import 'package:delycafe/models/catalog_item.dart';
import 'package:delycafe/services/cart_service.dart';
import 'package:delycafe/ui/tokens/app_colors.dart';
import 'package:delycafe/widgets/catalog/catalog_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CatalogSection extends StatefulWidget {
  final Widget? banner;

  const CatalogSection({
    super.key,
    this.banner,
  });

  @override
  State<CatalogSection> createState() => _CatalogSectionState();
}

class _CatalogSectionState extends State<CatalogSection> {
  String? _selectedCategory;

  final List<String> _categoryOrder = const [
    'Пицца',
    'Шаурма',
    'Бургеры',
    'Фастфуд',
    'Картошечка в фольге',
    'Соусы',
    'Напитки',
    'Десерты',
    'Блины',
    'Паста',
    'Пироги',
    'Салаты',
    'Супы',
  ];

  List<String> get _categories {
    final categories =
        generatedCatalog.map((item) => item.category).toSet().toList();

    categories.sort((a, b) {
      final indexA = _categoryOrder.indexOf(a);
      final indexB = _categoryOrder.indexOf(b);

      if (indexA == -1 && indexB == -1) {
        return a.compareTo(b);
      }

      if (indexA == -1) return 1;
      if (indexB == -1) return -1;

      return indexA.compareTo(indexB);
    });

    return categories;
  }

  String get _currentCategory {
    if (_selectedCategory != null && _categories.contains(_selectedCategory)) {
      return _selectedCategory!;
    }

    if (_categories.isEmpty) {
      return '';
    }

    return _categories.first;
  }

  List<CatalogItem> get _filteredItems {
    final currentCategory = _currentCategory;

    final items = generatedCatalog
        .where((item) => item.category == currentCategory)
        .toList();

    items.sort((a, b) {
      final sortCompare = a.sortOrder.compareTo(b.sortOrder);

      if (sortCompare != 0) {
        return sortCompare;
      }

      return a.title.compareTo(b.title);
    });

    return items;
  }

  ProductVariant? _getDefaultVariant(CatalogItem item) {
    if (item.variants.isEmpty) {
      return null;
    }

    for (final variant in item.variants) {
      if (variant.title == 'Средняя') {
        return variant;
      }
    }

    return item.variants.first;
  }

  void _selectCategory(String category) {
    setState(() {
      _selectedCategory = category;
    });
  }

  @override
  Widget build(BuildContext context) {
    final categories = _categories;
    final items = _filteredItems;

    if (categories.isEmpty) {
      return const Center(
        child: Text('Каталог пуст'),
      );
    }

    return CustomScrollView(
      slivers: [
        if (widget.banner != null)
          SliverToBoxAdapter(
            child: SizedBox(
              width: double.infinity,
              child: widget.banner!,
            ),
          ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _CatalogHeaderDelegate(
            categories: categories,
            selectedCategory: _currentCategory,
            onCategorySelected: _selectCategory,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = items[index];

                return CatalogCard(
                  item: item,
                  onAddToCart: () {
                    final variant = _getDefaultVariant(item);

                    context.read<CartService>().addToCart(
                          item,
                          variant: variant,
                        );
                  },
                );
              },
              childCount: items.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.63,
            ),
          ),
        ),
      ],
    );
  }
}

class _CatalogHeaderDelegate extends SliverPersistentHeaderDelegate {
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;

  const _CatalogHeaderDelegate({
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  double get minExtent => 116;

  @override
  double get maxExtent => 116;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: const Color(0xFFFEF7FF),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Меню',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories.map((category) {
                final selected = category == selectedCategory;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      onCategorySelected(category);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.header
                            : Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selected
                              ? AppColors.header
                              : Colors.black.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _CatalogHeaderDelegate oldDelegate) {
    return oldDelegate.categories != categories ||
        oldDelegate.selectedCategory != selectedCategory;
  }
}
