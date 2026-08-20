import 'dart:async';
import 'dart:convert';

import 'package:delycafe/config/api_config.dart';
import 'package:delycafe/exceptions/auth_required_exception.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiAuthStorage {
  ApiAuthStorage._();

  static final ApiAuthStorage instance = ApiAuthStorage._();

  static const String _accessTokenKey = 'customer_access_token';
  static const String _refreshTokenKey = 'customer_refresh_token';
  static const String _orderAccessTokenKey = 'order_access_token';
  static const Duration _refreshSkew = Duration(minutes: 2);

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String? _accessToken;
  String? _refreshToken;
  String? _orderAccessToken;
  Future<void>? _refreshFuture;
  bool _legacyBootstrapAttempted = false;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  String? get orderAccessToken => _orderAccessToken;

  bool get hasAccessToken => _accessToken?.isNotEmpty == true;
  bool get hasRefreshToken => _refreshToken?.isNotEmpty == true;
  bool get hasCustomerSession => hasAccessToken || hasRefreshToken;

  Future<void> load() async {
    _accessToken = await _secureStorage.read(key: _accessTokenKey);
    _refreshToken = await _secureStorage.read(key: _refreshTokenKey);
    _orderAccessToken = await _secureStorage.read(key: _orderAccessTokenKey);

    final prefs = await SharedPreferences.getInstance();
    final legacyAccessToken = prefs.getString(_accessTokenKey);
    final legacyOrderAccessToken = prefs.getString(_orderAccessTokenKey);

    if ((_accessToken == null || _accessToken!.isEmpty) &&
        legacyAccessToken != null &&
        legacyAccessToken.isNotEmpty) {
      _accessToken = legacyAccessToken;
      await _secureStorage.write(
        key: _accessTokenKey,
        value: legacyAccessToken,
      );
    }

    if ((_orderAccessToken == null || _orderAccessToken!.isEmpty) &&
        legacyOrderAccessToken != null &&
        legacyOrderAccessToken.isNotEmpty) {
      _orderAccessToken = legacyOrderAccessToken;
      await _secureStorage.write(
        key: _orderAccessTokenKey,
        value: legacyOrderAccessToken,
      );
    }

    await prefs.remove(_accessTokenKey);
    await prefs.remove(_orderAccessTokenKey);
  }

  Future<void> saveAccessToken(String token) async {
    _accessToken = token.trim();
    _legacyBootstrapAttempted = false;
    await _secureStorage.write(key: _accessTokenKey, value: _accessToken);
  }

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
  }) async {
    _accessToken = accessToken.trim();
    _refreshToken = refreshToken.trim();
    // Сначала сохраняем долгоживущий токен: если процесс прервётся между
    // записями, новый access token можно безопасно получить при следующем старте.
    await _secureStorage.write(
      key: _refreshTokenKey,
      value: _refreshToken,
    );
    await _secureStorage.write(
      key: _accessTokenKey,
      value: _accessToken,
    );
  }

  Future<void> saveOrderAccessToken(String token) async {
    _orderAccessToken = token.trim();
    await _secureStorage.write(
      key: _orderAccessTokenKey,
      value: _orderAccessToken,
    );
  }

  Future<void> clearAccessToken() async {
    _accessToken = null;
    await _secureStorage.delete(key: _accessTokenKey);
  }

  Future<void> clearCustomerSession() async {
    _accessToken = null;
    _refreshToken = null;
    _legacyBootstrapAttempted = false;
    await Future.wait([
      _secureStorage.delete(key: _accessTokenKey),
      _secureStorage.delete(key: _refreshTokenKey),
    ]);
  }

  Future<void> clearOrderAccessToken() async {
    _orderAccessToken = null;
    await _secureStorage.delete(key: _orderAccessTokenKey);
  }

  Future<void> clearAll() async {
    _accessToken = null;
    _refreshToken = null;
    _orderAccessToken = null;
    _legacyBootstrapAttempted = false;

    await Future.wait([
      _secureStorage.delete(key: _accessTokenKey),
      _secureStorage.delete(key: _refreshTokenKey),
      _secureStorage.delete(key: _orderAccessTokenKey),
    ]);
  }

  Future<void> revokeRefreshToken() async {
    final token = _refreshToken;
    if (token == null || token.isEmpty) return;

    try {
      await http
          .post(
            ApiConfig.uri('/api/customers/auth/token/revoke/'),
            headers: const {
              'Content-Type': 'application/json; charset=utf-8',
            },
            body: jsonEncode({'refresh_token': token}),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // Локальный выход не должен блокироваться из-за отсутствия сети.
    }
  }

  Future<Map<String, String>> authorizedHeaders({
    bool includeOrderAccess = false,
    bool jsonContentType = false,
    bool includeAccessToken = true,
  }) async {
    if (includeAccessToken) {
      await ensureValidAccessToken();
    }

    return headers(
      includeOrderAccess: includeOrderAccess,
      jsonContentType: jsonContentType,
      includeAccessToken: includeAccessToken,
    );
  }

  Future<void> ensureValidAccessToken() async {
    if (hasAccessToken && !hasRefreshToken && !_legacyBootstrapAttempted) {
      _legacyBootstrapAttempted = true;
      await _bootstrapLegacySession();
    }

    if (!_accessTokenNeedsRefresh()) return;

    if (!hasRefreshToken) {
      if (_isAccessTokenExpired()) {
        await clearAccessToken();
      }
      return;
    }

    final inProgress = _refreshFuture;
    if (inProgress != null) {
      await inProgress;
      return;
    }

    final refresh = _refreshAccessToken();
    _refreshFuture = refresh;

    try {
      await refresh;
    } finally {
      _refreshFuture = null;
    }
  }

  Future<void> _refreshAccessToken() async {
    final token = _refreshToken;
    if (token == null || token.isEmpty) return;

    final response = await http
        .post(
          ApiConfig.uri('/api/customers/auth/token/refresh/'),
          headers: const {
            'Content-Type': 'application/json; charset=utf-8',
          },
          body: jsonEncode({'refresh_token': token}),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Сервер вернул неверный формат refresh-сессии.');
      }

      final nextAccessToken = decoded['access_token']?.toString() ?? '';
      final nextRefreshToken = decoded['refresh_token']?.toString() ?? '';
      if (nextAccessToken.isEmpty || nextRefreshToken.isEmpty) {
        throw Exception('Сервер не вернул обновлённую сессию.');
      }

      await saveSession(
        accessToken: nextAccessToken,
        refreshToken: nextRefreshToken,
      );
      return;
    }

    if (response.statusCode == 400 || response.statusCode == 401) {
      await clearCustomerSession();
      throw const AuthRequiredException(
        'Сессия истекла. Войдите по SMS для продолжения.',
      );
    }

    throw Exception(
      'Не удалось обновить сессию: ${response.statusCode}',
    );
  }

  Future<void> _bootstrapLegacySession() async {
    final token = _accessToken;
    if (token == null || token.isEmpty) return;

    try {
      final response = await http.post(
        ApiConfig.uri('/api/customers/auth/token/bootstrap/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=utf-8',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is! Map<String, dynamic>) return;

        final nextAccessToken = decoded['access_token']?.toString() ?? '';
        final nextRefreshToken = decoded['refresh_token']?.toString() ?? '';
        if (nextAccessToken.isNotEmpty && nextRefreshToken.isNotEmpty) {
          await saveSession(
            accessToken: nextAccessToken,
            refreshToken: nextRefreshToken,
          );
        }
        return;
      }

      if (response.statusCode == 401) {
        await clearCustomerSession();
        throw const AuthRequiredException(
          'Сессия истекла. Войдите по SMS для продолжения.',
        );
      }
    } on AuthRequiredException {
      rethrow;
    } catch (_) {
      // Старый access token продолжает работать, если bootstrap временно
      // недоступен (например, приложение обновилось раньше backend).
    }
  }

  bool _accessTokenNeedsRefresh() {
    final expiresAt = _accessTokenExpiresAt();
    if (_accessToken == null || _accessToken!.isEmpty) {
      return hasRefreshToken;
    }
    if (expiresAt == null) return false;
    return expiresAt.isBefore(DateTime.now().add(_refreshSkew));
  }

  bool _isAccessTokenExpired() {
    final expiresAt = _accessTokenExpiresAt();
    return expiresAt != null && expiresAt.isBefore(DateTime.now());
  }

  DateTime? _accessTokenExpiresAt() {
    final token = _accessToken;
    if (token == null || token.isEmpty) return null;

    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (payload is! Map<String, dynamic>) return null;
      final rawExpiration = payload['exp'];
      final expiration = rawExpiration is int
          ? rawExpiration
          : int.tryParse(rawExpiration?.toString() ?? '');
      if (expiration == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(
        expiration * 1000,
        isUtc: true,
      ).toLocal();
    } catch (_) {
      return null;
    }
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
