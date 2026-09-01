import 'dart:convert';

import 'package:delycafe/config/api_config.dart';
import 'package:delycafe/models/catalog_item.dart';
import 'package:delycafe/models/category.dart';
import 'package:http/http.dart' as http;

class CatalogApiService {
  Future<List<CatalogItem>> fetchProducts() async {
    final uri = ApiConfig.uri('/api/catalog/products/');

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
      return CatalogItem.fromJson(json as Map<String, dynamic>);
    }).toList();
  }

  Future<List<Category>> fetchCategories() async {
    final uri = ApiConfig.uri('/api/catalog/categories/');

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'Ошибка загрузки категорий: ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(
      utf8.decode(response.bodyBytes),
    ) as List;

    return decoded
        .map(
          (e) => Category.fromJson(
            e as Map<String, dynamic>,
          ),
        )
        .toList();
  }
}
