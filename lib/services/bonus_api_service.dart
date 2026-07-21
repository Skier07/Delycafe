import 'dart:convert';

import 'package:delycafe/config/api_config.dart';
import 'package:delycafe/models/bonus_summary.dart';
import 'package:delycafe/services/api_auth_storage.dart';
import 'package:http/http.dart' as http;

class BonusApiService {
  Future<BonusSummary> fetchBonuses() async {
    final uri = ApiConfig.uri('/api/customers/bonuses/');

    final response = await http.get(
      uri,
      headers: ApiAuthStorage.instance.headers(),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Ошибка загрузки бонусов: ${response.statusCode}\n'
        '${utf8.decode(response.bodyBytes)}',
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Неверный формат данных бонусов');
    }

    return BonusSummary.fromJson(decoded);
  }
}
