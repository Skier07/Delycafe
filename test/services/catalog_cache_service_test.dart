import 'package:delycafe/data/hive/hive_boxes.dart';
import 'package:delycafe/services/catalog_cache_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'fake_catalog_repository.dart';
import '../test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initTestEnvironment();
  });

  test('hive roundtrip preserves info blocks for second launch', () async {
    final cache = CatalogCacheService();
    final product = testCatalogProduct();

    await cache.save(
      products: [product],
      categories: [testCategory()],
    );

    final snapshot = cache.readCached();

    expect(snapshot, isNotNull);
    expect(snapshot!.products.single.title, 'Пирог тестовый');
    expect(
      snapshot.products.single.infoBlocks?.single.resolvedLines().single.text,
      '48 часов',
    );
  });

  test('readCached survives corrupt product entry', () async {
    final cache = CatalogCacheService();

    await cache.save(
      products: [testCatalogProduct(id: 'good')],
      categories: [testCategory()],
    );

    final hiveBox = Hive.box<Map>(HiveBoxes.catalog);
    await hiveBox.put('bad', {'id': 'bad', 'variants': 'not-a-list'});

    final snapshot = cache.readCached();

    expect(snapshot, isNotNull);
    expect(snapshot!.products.any((product) => product.id == 'good'), isTrue);
  });
}
