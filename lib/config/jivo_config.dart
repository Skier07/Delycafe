/// Jivo chat widget for customer support.
///
/// Override at build time if needed:
/// `flutter run --dart-define=JIVO_WIDGET_ID=other_id`
class JivoConfig {
  static const String defaultWidgetId = 'TEfZ2JmXOW';

  /// Origin for WebView — Jivo CDN, no dependency on marketing sites.
  static const String baseUrl = 'https://code.jivo.ru/';

  static const String widgetId = String.fromEnvironment(
    'JIVO_WIDGET_ID',
    defaultValue: defaultWidgetId,
  );

  static bool get isConfigured => widgetId.trim().isNotEmpty;

  static String get widgetScriptUrl =>
      'https://code.jivo.ru/widget/${widgetId.trim()}';

  static String get browserChatUrl => 'https://jivo.chat/${widgetId.trim()}';

  static const Duration loadTimeout = Duration(seconds: 15);
}
