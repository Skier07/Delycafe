/// Jivo chat widget for customer support (same as pizzaozersk.ru).
///
/// Override at build time if needed:
/// `flutter run --dart-define=JIVO_WIDGET_ID=other_id`
class JivoConfig {
  static const String defaultWidgetId = 'TEfZ2JmXOW';

  static const String widgetId = String.fromEnvironment(
    'JIVO_WIDGET_ID',
    defaultValue: defaultWidgetId,
  );

  static bool get isConfigured => widgetId.trim().isNotEmpty;
}
