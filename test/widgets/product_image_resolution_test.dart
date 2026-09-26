import 'package:delycafe/models/catalog_image_variant.dart';
import 'package:delycafe/models/catalog_item.dart';
import 'package:delycafe/widgets/catalog/product_image_resolution.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const small =
      CatalogImageVariant(url: '/small.webp', width: 1254, height: 1254);
  const large =
      CatalogImageVariant(url: '/large.webp', width: 3840, height: 3840);
  const versions = [large, small];

  test('phone and small tablet tiles download only small version', () {
    expect(
        selectProductImageVariant(
            versions, const Size(390, 320), 3, BoxFit.contain),
        small);
    expect(
        selectProductImageVariant(
            versions, const Size(240, 200), 2, BoxFit.cover),
        small);
  });
  test('large tablet hero and 4K area use large version', () {
    expect(
        selectProductImageVariant(
            versions, const Size(1024, 717), 2, BoxFit.contain),
        large);
    expect(
        selectProductImageVariant(
            versions, const Size(1280, 1280), 3, BoxFit.contain),
        large);
    expect(
        productImageDecodeWidth(
            large, const Size(1280, 1280), 3, BoxFit.contain),
        3840);
  });
  test('contain and cover use actual fitted pixel requirement', () {
    expect(
        selectProductImageVariant(
            versions, const Size(800, 320), 2, BoxFit.contain),
        small);
    expect(
        selectProductImageVariant(
            versions, const Size(800, 320), 2, BoxFit.cover),
        large);
    expect(
        productImageDecodeWidth(large, const Size(800, 320), 2, BoxFit.cover),
        1600);
  });
  test('missing versions fallback, undersized sources are not decoded larger',
      () {
    expect(selectProductImageVariant([], const Size(320, 320), 3, BoxFit.cover),
        isNull);
    expect(
        productImageDecodeWidth(small, const Size(2000, 2000), 3, BoxFit.cover),
        1254);
  });
  test('Hive catalog round trip preserves variant URLs and dimensions', () {
    final item = CatalogItem.fromJson({
      'id': 69,
      'image': '/pizza.png',
      'image_variants': {
        '/pizza.png': [small.toJson(), large.toJson()]
      },
    });
    final restored = CatalogItem.fromJson(item.toJson());
    expect(restored.imageVariants['/pizza.png']!.last.width, 3840);
    expect(restored.imageVariants['/pizza.png']!.first.url, '/small.webp');
    expect(CatalogItem.fromJson({'id': 1}).imageVariants, isEmpty);
  });
}
