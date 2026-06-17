import 'package:delycafe/models/catalog_item.dart';
import 'package:delycafe/models/category.dart';
import 'package:delycafe/services/catalog_api_service.dart';
import 'package:delycafe/services/catalog_cache_service.dart';

class CatalogRepository {
  final CatalogApiService _apiService;
  final CatalogCacheService _cacheService;

  CatalogRepository({
    CatalogApiService? apiService,
    CatalogCacheService? cacheService,
  })  : _apiService = apiService ?? CatalogApiService(),
        _cacheService = cacheService ?? CatalogCacheService();

  CatalogSnapshot? readCached() => _cacheService.readCached();

  Future<CatalogSnapshot> fetchFromApiAndCache() async {
    final results = await Future.wait([
      _apiService.fetchProducts(),
      _apiService.fetchCategories(),
    ]);

    final products = results[0] as List<CatalogItem>;
    final categories = results[1] as List<Category>;

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
