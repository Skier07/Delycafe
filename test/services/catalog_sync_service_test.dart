import 'package:delycafe/services/catalog_cache_service.dart';
import 'package:delycafe/services/catalog_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_catalog_repository.dart';
import '../test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initTestEnvironment();
  });

  tearDown(() {
    CatalogSyncService.instance.onAppBackground();
  });

  test('concurrent refresh waits for in-flight request', () async {
    final cacheService = CatalogCacheService();
    final repository = FakeCatalogRepository(
      cacheService: cacheService,
      products: [testCatalogProduct()],
      categories: [testCategory()],
    );
    final service = CatalogSyncService.forTesting(repository);

    final first = service.refresh(force: true);
    final second = service.refresh(force: true);

    await Future.wait([first, second]);

    expect(repository.fetchCallCount, 1);
    expect(repository.readCached()?.products.single.title, 'Пирог тестовый');
  });

  test('foreground refresh during forced refresh does not skip cache write', () async {
    final cacheService = CatalogCacheService();
    final repository = FakeCatalogRepository(
      cacheService: cacheService,
      delay: const Duration(milliseconds: 120),
      products: [testCatalogProduct(title: 'Из API')],
      categories: [testCategory()],
    );
    final service = CatalogSyncService.forTesting(repository);

    final forced = service.refresh(force: true);
    final foreground = service.refresh();

    await Future.wait([forced, foreground]);

    expect(repository.fetchCallCount, 1);

    final snapshot = repository.readCached();
    expect(snapshot, isNotNull);
    expect(snapshot!.products.single.title, 'Из API');
  });
}
