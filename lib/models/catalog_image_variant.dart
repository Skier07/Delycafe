class CatalogImageVariant {
  final String url;
  final int width;
  final int height;

  const CatalogImageVariant({
    required this.url,
    required this.width,
    required this.height,
  });

  Map<String, dynamic> toJson() => {
        'url': url,
        'width': width,
        'height': height,
      };

  static Map<String, List<CatalogImageVariant>> parseMap(dynamic raw) {
    if (raw is! Map) return const {};
    final result = <String, List<CatalogImageVariant>>{};
    for (final entry in raw.entries) {
      if (entry.value is! List) continue;
      final variants = <CatalogImageVariant>[];
      for (final value in entry.value as List) {
        if (value is! Map) continue;
        final width = int.tryParse('${value['width']}') ?? 0;
        final height = int.tryParse('${value['height']}') ?? 0;
        final url = value['url']?.toString() ?? '';
        if (width > 0 && height > 0 && url.isNotEmpty) {
          variants
              .add(CatalogImageVariant(url: url, width: width, height: height));
        }
      }
      if (variants.isNotEmpty) result[entry.key.toString()] = variants;
    }
    return result;
  }
}
