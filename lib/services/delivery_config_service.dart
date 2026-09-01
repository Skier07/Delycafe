import 'dart:convert';

import 'package:delycafe/config/api_config.dart';
import 'package:delycafe/models/delivery_config.dart';
import 'package:http/http.dart' as http;

class DeliveryConfigService {
  DeliveryConfigService._();

  static final DeliveryConfigService instance = DeliveryConfigService._();

  DeliveryConfig? _cache;

  Future<DeliveryConfig> fetch({bool forceRefresh = false}) async {
    if (_cache != null && !forceRefresh) {
      return _cache!;
    }

    try {
      final uri = ApiConfig.uri('/api/orders/delivery-config/');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));

        if (decoded is Map<String, dynamic>) {
          final config = DeliveryConfig.fromJson(decoded);

          if (config.zones.isNotEmpty) {
            _cache = config;
            return _cache!;
          }
        }
      }
    } catch (_) {
      // Fallback below.
    }

    _cache = DeliveryConfig.fallback();
    return _cache!;
  }
}
