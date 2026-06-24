import 'dart:convert';

import 'package:delycafe/config/jivo_config.dart';
import 'package:delycafe/models/user.dart';
import 'package:delycafe/ui/components/glass/shader_glass_container.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class JivoChatScreen extends StatefulWidget {
  final User? user;

  const JivoChatScreen({
    super.key,
    this.user,
  });

  @override
  State<JivoChatScreen> createState() => _JivoChatScreenState();
}

class _JivoChatScreenState extends State<JivoChatScreen> {
  WebViewController? _webViewController;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  Future<void> _initializeWebView() async {
    final widgetId = JivoConfig.widgetId.trim();

    if (widgetId.isEmpty) {
      setState(() {
        _errorMessage = 'JIVO_WIDGET_ID не задан';
        _isLoading = false;
      });
      return;
    }

    final user = widget.user;
    final contactName = jsonEncode(user?.name.trim() ?? '');
    final contactPhone = jsonEncode(user?.phone.trim() ?? '');

    final html = '''
<!DOCTYPE html>
<html lang="ru">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
  <style>
    html, body {
      margin: 0;
      height: 100%;
      background: #191430;
    }
  </style>
</head>
<body>
  <script>
    function jivo_onLoadCallback() {
      var name = $contactName;
      var phone = $contactPhone;

      if (name || phone) {
        jivo_api.setContactInfo({
          name: name || 'Клиент',
          phone: phone,
          description: 'Приложение Delycafe'
        });
      }

      jivo_api.open();
    }
  </script>
  <script src="https://code.jivo.ru/widget/$widgetId" async></script>
</body>
</html>
''';

    final controller = WebViewController();
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (_) {
          if (!mounted) return;

          setState(() => _isLoading = false);
        },
        onWebResourceError: (error) {
          if (!mounted) return;

          setState(() {
            _errorMessage = error.description;
            _isLoading = false;
          });
        },
      ),
    );
    await controller.loadHtmlString(html, baseUrl: 'https://delycafe.ru');

    setState(() {
      _webViewController = controller;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF191430),
      appBar: AppBar(
        backgroundColor: const Color(0xFF191430),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Поддержка'),
        leading: ShaderGlassContainer(
          borderRadius: 30,
          onPressed: () => Navigator.pop(context),
          padding: const EdgeInsets.all(8),
          child: const Icon(
            CupertinoIcons.chevron_left_2,
            color: Colors.white,
            size: 24,
          ),
        ),
        leadingWidth: 56,
      ),
      body: Stack(
        children: [
          if (_webViewController != null)
            WebViewWidget(controller: _webViewController!),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
