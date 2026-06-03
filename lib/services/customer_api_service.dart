import 'dart:convert';

import 'package:delycafe/models/user.dart';
import 'package:http/http.dart' as http;

class CustomerApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  Future<User> fetchProfile({
    required String phone,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/customers/profile/?phone=${Uri.encodeComponent(phone)}',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'Ошибка загрузки профиля: ${response.statusCode}\n'
        '${utf8.decode(response.bodyBytes)}',
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Неверный формат профиля клиента');
    }

    return User.fromJson(decoded);
  }
}
