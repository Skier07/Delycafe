import 'package:delycafe/data/mock_catalog.dart';
import 'package:delycafe/models/catalog_item.dart';
import 'package:delycafe/services/cart_service.dart';
import 'package:delycafe/ui/tokens/app_colors.dart';
import 'package:delycafe/widgets/catalog/catalog_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CatalogSection extends StatefulWidget {
  const CatalogSection({super.key});

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

  @override
  Widget build(BuildContext context) {
    final items = _filteredItems;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
              children: _categories.map((category) {
                final selected = category == _selectedCategory;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategory = category;
                      });
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
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.63,
            ),
            itemBuilder: (context, index) {
              final item = items[index];

              return CatalogCard(
                item: item,
                onAddToCart: () {
                  context.read<CartService>().addToCart(item);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
