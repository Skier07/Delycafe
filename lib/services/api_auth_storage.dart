import 'package:shared_preferences/shared_preferences.dart';

class ApiAuthStorage {
  ApiAuthStorage._();

  static final ApiAuthStorage instance = ApiAuthStorage._();

  static const String _accessTokenKey = 'customer_access_token';
  static const String _orderAccessTokenKey = 'order_access_token';

  String? _accessToken;
  String? _orderAccessToken;

  String? get accessToken => _accessToken;
  String? get orderAccessToken => _orderAccessToken;

  bool get hasAccessToken => _accessToken?.isNotEmpty == true;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_accessTokenKey);
    _orderAccessToken = prefs.getString(_orderAccessTokenKey);
  }

  Future<void> saveAccessToken(String token) async {
    _accessToken = token.trim();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, _accessToken!);
  }

  Future<void> saveOrderAccessToken(String token) async {
    _orderAccessToken = token.trim();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_orderAccessTokenKey, _orderAccessToken!);
  }

  Future<void> clearAccessToken() async {
    _accessToken = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
  }

  Future<void> clearOrderAccessToken() async {
    _orderAccessToken = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_orderAccessTokenKey);
  }

  Future<void> clearAll() async {
    _accessToken = null;
    _orderAccessToken = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_orderAccessTokenKey);
  }

  Map<String, String> headers({
    bool includeOrderAccess = false,
    bool jsonContentType = false,
    bool includeAccessToken = true,
  }) {
    final result = <String, String>{};

    if (jsonContentType) {
      result['Content-Type'] = 'application/json; charset=utf-8';
    }

    if (includeAccessToken) {
      final accessToken = _accessToken;

      if (accessToken != null && accessToken.isNotEmpty) {
        result['Authorization'] = 'Bearer $accessToken';
      }
    }

    if (includeOrderAccess) {
      final orderAccessToken = _orderAccessToken;

      if (orderAccessToken != null && orderAccessToken.isNotEmpty) {
        result['X-Order-Access'] = orderAccessToken;
      }
    }

    return result;
  }
}
