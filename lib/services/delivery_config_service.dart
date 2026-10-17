import 'dart:convert';

import 'package:delycafe/config/api_config.dart';
import 'package:delycafe/models/delivery_config.dart';
import 'package:http/http.dart' as http;

class DeliveryConfigService {
  DeliveryConfigService({http.Client? client})
      : _client = client ?? http.Client();

  static final DeliveryConfigService instance = DeliveryConfigService();

  final http.Client _client;
  DeliveryConfig? _cache;
  DateTime? _fetchedAt;
  Future<DeliveryConfig>? _inFlight;

  Future<DeliveryConfig> fetch({
    bool forceRefresh = false,
    bool requireFresh = false,
  }) async {
    if (_cache != null &&
        !forceRefresh &&
        !requireFresh &&
        DateTime.now().difference(_fetchedAt!) < const Duration(minutes: 1)) {
      return _cache!;
    }

    final request = _inFlight ??= _request();
    try {
      return await request;
    } catch (_) {
      if (requireFresh) {
        throw Exception(
            'Не удалось обновить условия доставки. Проверьте подключение и повторите попытку.');
      }
      // An offline request must not replace good rates with hardcoded defaults.
      return _cache ?? DeliveryConfig.fallback();
    } finally {
      if (identical(_inFlight, request)) _inFlight = null;
    }
  }

  Future<DeliveryConfig> _request() async {
    final response = await _client.get(
      ApiConfig.uri('/api/orders/delivery-config/'),
      headers: {'Cache-Control': 'no-cache'},
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw const FormatException('Delivery config unavailable');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid delivery config');
    }
    final config = DeliveryConfig.fromJson(decoded);
    if (config.zones.isEmpty || config.zones.any((zone) => zone.code.isEmpty)) {
      throw const FormatException('Empty delivery zones');
    }
    _cache = config;
    _fetchedAt = DateTime.now();
    return config;
  }
}
