/// Central API base URL for all backend requests.
///
/// Override at build time:
/// `flutter run --dart-define=API_BASE_URL=https://api.delycafe.ru`
class ApiConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.delycafe.ru',
  );

  static String get normalizedBaseUrl {
    final url = apiBaseUrl.trim();

    if (url.endsWith('/')) {
      return url.substring(0, url.length - 1);
    }

    return url;
  }

  static Uri uri(
    String path, {
    Map<String, String>? queryParameters,
  }) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';

    return Uri.parse('$normalizedBaseUrl$normalizedPath').replace(
      queryParameters: queryParameters,
    );
  }

  /// Rewrites legacy local dev media URLs to the configured API host.
  static String normalizeMediaUrl(String value) {
    final imagePath = value.trim();

    for (final localPrefix in _localDevPrefixes) {
      if (imagePath.startsWith(localPrefix)) {
        return imagePath.replaceFirst(localPrefix, normalizedBaseUrl);
      }
    }

    return imagePath;
  }

  static const List<String> _localDevPrefixes = [
    'http://127.0.0.1:8000',
    'http://localhost:8000',
    'http://10.0.2.2:8000',
  ];
}
