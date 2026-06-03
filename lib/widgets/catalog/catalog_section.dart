import 'package:delycafe/models/catalog_item.dart';
import 'package:delycafe/services/cart_service.dart';
import 'package:delycafe/services/catalog_api_service.dart';
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
  final CatalogApiService _catalogApiService = CatalogApiService();

  late Future<List<CatalogItem>> _catalogFuture;

  String? _selectedCategory;

  List<String> _getCategories(List<CatalogItem> catalog) {
    final categories = catalog.map((item) => item.category).toSet().toList();

    categories.sort((a, b) {
      final sortA = _getCategorySortOrder(a, catalog);
      final sortB = _getCategorySortOrder(b, catalog);

      final sortCompare = sortA.compareTo(sortB);

      if (sortCompare != 0) {
        return sortCompare;
      }

      return a.compareTo(b);
    });

    return categories;
  }

  int _getCategorySortOrder(
    String category,
    List<CatalogItem> catalog,
  ) {
    final categoryItems = catalog.where(
      (item) => item.category == category,
    );

    if (categoryItems.isEmpty) {
      return 500;
    }

    final sortOrders =
        categoryItems.map((item) => item.categorySortOrder).toList()..sort();

    return sortOrders.first;
  }

  @override
  void initState() {
    super.initState();
    _catalogFuture = _catalogApiService.fetchProducts();
  }

  Future<void> _reloadCatalog() async {
    setState(() {
      _catalogFuture = _catalogApiService.fetchProducts();
    });

    await _catalogFuture;
  }

  String _getCurrentCategory(List<String> categories) {
    if (_selectedCategory != null && categories.contains(_selectedCategory)) {
      return _selectedCategory!;
    }

    if (categories.isEmpty) {
      return '';
    }

    return categories.first;
  }

  int _getProductPriority(CatalogItem item) {
    if (item.isNew && item.isHit) {
      return 0;
    }
    if (item.isNew) {
      return 1;
    }

    if (item.isHit) {
      return 2;
    }
    return 3;
  }

  int _compareCatalogItems(CatalogItem a, CatalogItem b) {
    final priorityCompare = _getProductPriority(a).compareTo(
      _getProductPriority(b),
    );
    if (priorityCompare != 0) {
      return priorityCompare;
    }
    final sortCompare = a.sortOrder.compareTo(b.sortOrder);
    if (sortCompare != 0) {
      return sortCompare;
    }
    return a.title.compareTo(b.title);
  }

  List<CatalogItem> _getFilteredItems(
    List<CatalogItem> catalog,
    String currentCategory,
  ) {
    final items =
        catalog.where((item) => item.category == currentCategory).toList();

    items.sort(_compareCatalogItems);

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
    return FutureBuilder<List<CatalogItem>>(
      future: _catalogFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _CatalogLoadingView();
        }

        if (snapshot.hasError) {
          return _CatalogErrorView(
            error: snapshot.error.toString(),
            onRetry: _reloadCatalog,
          );
        }

        final catalog = snapshot.data ?? [];
        final categories = _getCategories(catalog);

        if (categories.isEmpty) {
          return const _EmptyCatalogView();
        }

        final currentCategory = _getCurrentCategory(categories);
        final items = _getFilteredItems(catalog, currentCategory);

        return RefreshIndicator(
          onRefresh: _reloadCatalog,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                  selectedCategory: currentCategory,
                  onCategorySelected: _selectCategory,
                ),
              ),
              if (items.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'В этой категории пока нет товаров',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              else
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
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.63,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
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

class _CatalogLoadingView extends StatelessWidget {
  const _CatalogLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.header,
      ),
    );
  }
}

class _CatalogErrorView extends StatelessWidget {
  final String error;
  final Future<void> Function() onRetry;

  const _CatalogErrorView({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 52,
              color: AppColors.header,
            ),
            const SizedBox(height: 14),
            const Text(
              'Не удалось загрузить каталог',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: Colors.black.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.header,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Повторить',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCatalogView extends StatelessWidget {
  const _EmptyCatalogView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Каталог пуст',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
