import 'package:delycafe/models/catalog_item.dart';
import 'package:delycafe/models/category.dart';
import 'package:delycafe/models/product_info_block.dart';
import 'package:delycafe/services/catalog_cache_service.dart';
import 'package:delycafe/services/catalog_repository.dart';

/// Репозиторий для тестов: имитирует медленный API без сети.
class FakeCatalogRepository extends CatalogRepository {
  FakeCatalogRepository._({
    required CatalogCacheService cacheService,
    required this.delay,
    required this.products,
    required this.categories,
    required this.shouldFail,
  })  : _cacheService = cacheService,
        super(cacheService: cacheService);

  factory FakeCatalogRepository({
    CatalogCacheService? cacheService,
    Duration delay = const Duration(milliseconds: 80),
    List<CatalogItem> products = const [],
    List<Category> categories = const [],
    bool shouldFail = false,
  }) {
    final resolvedCache = cacheService ?? CatalogCacheService();

    return FakeCatalogRepository._(
      cacheService: resolvedCache,
      delay: delay,
      products: products,
      categories: categories,
      shouldFail: shouldFail,
    );
  }

  final CatalogCacheService _cacheService;
  final Duration delay;
  final List<CatalogItem> products;
  final List<Category> categories;
  final bool shouldFail;

  int fetchCallCount = 0;

  @override
  Future<CatalogSnapshot> fetchFromApiAndCache() async {
    fetchCallCount++;
    await Future<void>.delayed(delay);

    if (shouldFail) {
      throw Exception('network error');
    }

    await _cacheService.save(
      products: products,
      categories: categories,
    );

    return CatalogSnapshot(
      products: products,
      categories: categories,
      updatedAt: DateTime.now(),
    );
  }
}

CatalogItem testCatalogProduct({
  String id = 'pie-1',
  String title = 'Пирог тестовый',
}) {
  return CatalogItem(
    id: id,
    title: title,
    category: 'Пироги',
    price: 500,
    image: 'https://api.delycafe.ru/media/test.jpg',
    description: 'Описание',
    infoBlocks: [
      ProductInfoBlock(
        section: 'shelf_life',
        title: 'Срок годности',
        text: '',
        lines: [
          ProductInfoLine(text: '48 часов', marker: 'bullet'),
        ],
      ),
    ],
  );
}

Category testCategory({String title = 'Пироги'}) {
  return Category(
    id: 1,
    title: title,
    slug: 'pirogi',
    sortOrder: 100,
  );
}
