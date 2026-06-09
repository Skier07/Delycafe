import 'dart:convert';

import 'package:delycafe/models/bonus_summary.dart';
import 'package:http/http.dart' as http;

class BonusApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  Future<BonusSummary> fetchBonuses({
    required String phone,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/customers/bonuses/?phone=${Uri.encodeComponent(phone)}',
    );

    final response = await http.get(uri);

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
