import 'package:delycafe/services/catalog_cache_service.dart';
import 'package:delycafe/services/catalog_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_catalog_repository.dart';
import '../test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initTestEnvironment();
  });

  test('second launch reads hive cache with info blocks', () async {
    final cache = CatalogCacheService();

    await cache.save(
      products: [testCatalogProduct(title: 'Пирог из кэша')],
      categories: [testCategory()],
    );

    final repository = CatalogRepository(cacheService: cache);
    final snapshot = repository.readCached();

    expect(snapshot, isNotNull);
    expect(snapshot!.products.single.title, 'Пирог из кэша');
    expect(
      snapshot.products.single.infoBlocks?.single.resolvedLines().single.text,
      '48 часов',
    );
  });
}
