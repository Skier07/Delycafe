import 'dart:convert';

import 'package:delycafe/config/jivo_config.dart';

class JivoHtmlBuilder {
  const JivoHtmlBuilder._();

  static String build({
    required String? contactName,
    required String? contactPhone,
    required String userToken,
  }) {
    final name = jsonEncode(contactName?.trim() ?? '');
    final phone = jsonEncode(contactPhone?.trim() ?? '');
    final token = jsonEncode(userToken);

    return '''
<!DOCTYPE html>
<html lang="ru">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover">
  <style>
    html, body {
      margin: 0;
      padding: 0;
      height: 100%;
      background: #ffffff;
      overflow: hidden;
    }
  </style>
</head>
<body>
  <script>
    function jivo_onLoadCallback() {
      var name = $name;
      var phone = $phone;
      var userToken = $token;

      if (userToken) {
        jivo_api.setUserToken(userToken);
      }

      if (name || phone) {
        jivo_api.setContactInfo({
          name: name || 'Клиент',
          phone: phone,
          description: 'Мобильное приложение Delycafe'
        });
      }

      jivo_api.setCustomData([
        { content: 'Источник: приложение Delycafe' }
      ]);

      jivo_api.sendPageTitle(
        'Delycafe — Поддержка',
        true,
        '${JivoConfig.baseUrl}support'
      );

      jivo_api.open({ start: 'chat' });

      if (window.JivoBridge) {
        JivoBridge.postMessage('loaded');
      }
    }

    function jivo_onOpen() {
      if (window.JivoBridge) {
        JivoBridge.postMessage('loaded');
      }
    }

    function jivo_onClose() {
      if (window.JivoBridge) {
        JivoBridge.postMessage('closed');
      }
    }
  </script>
  <script src="${JivoConfig.widgetScriptUrl}" async></script>
</body>
</html>
''';
  }
}
