import 'dart:convert';

import 'package:delycafe/models/catalog_item.dart';
import 'package:http/http.dart' as http;

class CatalogApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  Future<List<CatalogItem>> fetchProducts() async {
    final uri = Uri.parse('$baseUrl/api/catalog/products/');

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'Ошибка загрузки каталога: ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));

    if (decoded is! List) {
      throw Exception('Неверный формат ответа каталога');
    }

    return decoded.map<CatalogItem>((json) {
      return _catalogItemFromJson(json as Map<String, dynamic>);
    }).toList();
  }

  CatalogItem _catalogItemFromJson(Map<String, dynamic> json) {
    final variantsJson = json['variants'];

    final variants = variantsJson is List
        ? variantsJson.map<ProductVariant>((variantJson) {
            return _variantFromJson(
              variantJson as Map<String, dynamic>,
            );
          }).toList()
        : <ProductVariant>[];

    return CatalogItem(
      id: 'api_${json['id']}',
      sabyId: _toNullableInt(json['saby_id']),
      title: json['title']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Другое',
      categorySortOrder: _toInt(
        json['category_sort_order'],
        defaultValue: 500,
      ),
      price: _toInt(json['price']),
      image: json['image']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      weight: json['weight']?.toString(),
      isNew: json['is_new'] == true,
      isHit: json['is_hit'] == true,
      sortOrder: _toInt(json['sort_order'], defaultValue: 500),
      variants: variants,
    );
  }

  ProductVariant _variantFromJson(Map<String, dynamic> json) {
    final sabyId = _toNullableInt(json['saby_id']);
    final apiId = json['id']?.toString() ?? '';

    return ProductVariant(
      id: sabyId?.toString() ?? 'variant_$apiId',
      sabyId: sabyId,
      title: json['title']?.toString() ?? '',
      price: _toInt(json['price']),
      weight: json['weight']?.toString() ?? '',
    );
  }

  int _toInt(
    dynamic value, {
    int defaultValue = 0,
  }) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? defaultValue;

    return defaultValue;
  }

  int? _toNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value);

    return null;
  }
}
