import 'dart:convert';

import 'package:delycafe/config/api_config.dart';
import 'package:delycafe/models/content_post.dart';
import 'package:http/http.dart' as http;

class ContentApiService {
  Future<List<ContentPost>> fetchPosts({required String type}) async {
    final uri = ApiConfig.uri(
      '/api/catalog/content/',
      queryParameters: {'type': type},
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Ошибка загрузки материалов: ${response.statusCode}');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));

    if (decoded is! List) {
      throw Exception('Неверный формат материалов');
    }

    return decoded
        .whereType<Map>()
        .map(
          (item) => ContentPost.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  Future<AppPageContent> fetchPage(String key) async {
    final uri = ApiConfig.uri('/api/catalog/pages/$key/');
    final response = await http.get(uri).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Ошибка загрузки страницы: ${response.statusCode}');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));

    if (decoded is! Map) {
      throw Exception('Неверный формат страницы');
    }

    return AppPageContent.fromJson(Map<String, dynamic>.from(decoded));
  }
}
