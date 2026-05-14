import 'package:delycafe/data/mock_catalog.dart';
import 'package:delycafe/models/catalog_item.dart';
import 'package:delycafe/services/cart_service.dart';
import 'package:delycafe/ui/tokens/app_colors.dart';
import 'package:delycafe/widgets/catalog/catalog_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CatalogSection extends StatefulWidget {
  final Widget banner;

  const CatalogSection({
    super.key,
    required this.banner,
  });

  @override
  State<CatalogSection> createState() => _CatalogSectionState();
}

class _CatalogSectionState extends State<CatalogSection> {
  final List<String> _categories = const [
    'Пицца',
    'Шаурма',
    'Бургеры',
    'Напитки',
  ];

  String _selectedCategory = 'Пицца';

  List<CatalogItem> get _filteredItems {
    return mockCatalog
        .where((item) => item.category == _selectedCategory)
        .toList();
  }

  void _selectCategory(String category) {
    if (_selectedCategory == category) return;

    setState(() {
      _selectedCategory = category;
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredItems;
    final topPadding = MediaQuery.of(context).padding.top;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: widget.banner,
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _CatalogHeaderDelegate(
            topPadding: topPadding,
            categories: _categories,
            selectedCategory: _selectedCategory,
            onCategorySelected: _selectCategory,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = items[index];

                return CatalogCard(
                  item: item,
                  onAddToCart: () {
                    context.read<CartService>().addToCart(item);
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
  final double topPadding;
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;

  const _CatalogHeaderDelegate({
    required this.topPadding,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  double get minExtent => topPadding + 104;

  @override
  double get maxExtent => topPadding + 104;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: const Color(0xFFFEF7FF),
      padding: EdgeInsets.fromLTRB(16, topPadding + 8, 16, 8),
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
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = categories[index];
                final selected = category == selectedCategory;

                return GestureDetector(
                  onTap: () => onCategorySelected(category),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.header
                          : Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected
                            ? AppColors.header
                            : Colors.black.withValues(alpha: 0.08),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      category,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_CatalogHeaderDelegate oldDelegate) {
    return oldDelegate.selectedCategory != selectedCategory ||
        oldDelegate.topPadding != topPadding ||
        oldDelegate.categories != categories;
  }
}
