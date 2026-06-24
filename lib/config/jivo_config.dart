/// Jivo chat widget for customer support.
///
/// Get Widget ID from Jivo cabinet (same as on pizzaozersk.ru) and pass at build:
/// `flutter run --dart-define=JIVO_WIDGET_ID=xxxxxxxx`
class JivoConfig {
  static const String widgetId = String.fromEnvironment(
    'JIVO_WIDGET_ID',
    defaultValue: '',
  );

  static bool get isConfigured => widgetId.trim().isNotEmpty;
}
