import 'dart:math' as math;

import 'package:delycafe/models/catalog_image_variant.dart';
import 'package:flutter/painting.dart';

/// Select before download so the disk cache contains the chosen server file.
CatalogImageVariant? selectProductImageVariant(
  List<CatalogImageVariant> variants,
  Size logicalSize,
  double devicePixelRatio,
  BoxFit fit,
) {
  if (variants.isEmpty) return null;
  final sorted = [...variants]
    ..sort((a, b) => (a.width * a.height).compareTo(b.width * b.height));
  for (final variant in sorted) {
    if (_scale(variant, logicalSize, devicePixelRatio, fit) <= 1) {
      return variant;
    }
  }
  return sorted.last;
}

double _scale(CatalogImageVariant image, Size size, double dpr, BoxFit fit) {
  final fitted = applyBoxFit(
    fit,
    Size(image.width.toDouble(), image.height.toDouble()),
    size,
  );
  if (fitted.source.isEmpty) return 0;
  return math.max(
        fitted.destination.width / fitted.source.width,
        fitted.destination.height / fitted.source.height,
      ) *
      dpr;
}

int productImageDecodeWidth(
  CatalogImageVariant image,
  Size logicalSize,
  double devicePixelRatio,
  BoxFit fit,
) {
  final pixels =
      image.width * _scale(image, logicalSize, devicePixelRatio, fit);
  // Bucket nearby layout sizes to avoid many identical in-memory decodes.
  return ((pixels / 64).ceil() * 64).clamp(1, math.min(image.width, 3840));
}
