import 'dart:convert';
import 'dart:math';
import 'package:delycafe/config/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class FoodPhraseService {
  FoodPhraseService({http.Client? client}) : _client = client ?? http.Client();
  static final instance = FoodPhraseService();
  final http.Client _client;
  final _random = Random();
  final List<String> _remaining = [];
  List<String> _phrases = [];
  String? _last;
  Future<void>? _pending;
  bool _loaded = false;
  String get _cacheKey => 'food_phrases_v1_${ApiConfig.normalizedBaseUrl}';

  Future<void> _load() async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      if (!_loaded) {
        _phrases = prefs.getStringList(_cacheKey) ?? [];
        _last = prefs.getString('${_cacheKey}_last');
      }
    } catch (_) {
      // A storage failure must not prevent fetching public content.
    }
    _loaded = true;
    try {
      final response = await _client
          .get(ApiConfig.uri('/api/catalog/food-phrases/'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return;
      final value = jsonDecode(utf8.decode(response.bodyBytes));
      if (value is! List || value.any((entry) => entry is! String)) return;
      final updated = value
          .cast<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();
      if (jsonEncode(updated) != jsonEncode(_phrases)) {
        _phrases = updated;
        _remaining.clear();
      }
      await prefs?.setStringList(_cacheKey, _phrases);
    } catch (_) {
      // Keep the last successful list offline. No bundled marketing phrases.
    }
  }

  Future<String> next() async {
    final pending = _pending ??= _load();
    await pending;
    if (identical(_pending, pending)) _pending = null;
    if (_phrases.isEmpty) return '';
    if (_remaining.isEmpty) {
      _remaining.addAll(_phrases.toList()..shuffle(_random));
      if (_remaining.length > 1 && _remaining.last == _last) {
        final first = _remaining.first;
        _remaining[0] = _remaining.last;
        _remaining[_remaining.length - 1] = first;
      }
    }
    final phrase = _remaining.removeLast();
    _last = phrase;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${_cacheKey}_last', phrase);
    } catch (_) {
      // The phrase can still be displayed when storage is unavailable.
    }
    return phrase;
  }
}
