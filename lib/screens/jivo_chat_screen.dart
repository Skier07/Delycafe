import 'dart:convert';

import 'package:delycafe/config/jivo_config.dart';
import 'package:delycafe/models/user.dart';
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
  bool _initStarted = false;

  static const double _extraTopInset = 20;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_initStarted) return;

    _initStarted = true;
    _initializeWebView();
  }

  double _chatTopInset(BuildContext context) {
    return MediaQuery.viewPaddingOf(context).top + _extraTopInset;
  }

  void _closeChat() {
    if (!mounted) return;

    Navigator.of(context).pop(true);
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
    final userToken = jsonEncode(_buildUserToken(user?.phone));

    final html = '''
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
      var name = $contactName;
      var phone = $contactPhone;
      var userToken = $userToken;

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

      jivo_api.sendPageTitle('Delycafe — Поддержка', true, 'app://support');

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
  <script src="https://code.jivo.ru/widget/$widgetId" async></script>
</body>
</html>
''';

    final controller = WebViewController();
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setBackgroundColor(Colors.white);
    await controller.addJavaScriptChannel(
      'JivoBridge',
      onMessageReceived: (message) {
        if (!mounted) return;

        if (message.message == 'closed') {
          _closeChat();
          return;
        }

        setState(() => _isLoading = false);
      },
    );
    await controller.setNavigationDelegate(
      NavigationDelegate(
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

    if (!mounted) return;

    setState(() {
      _webViewController = controller;
    });

    Future.delayed(const Duration(seconds: 12), () {
      if (!mounted || !_isLoading) return;

      setState(() => _isLoading = false);
    });
  }

  String _buildUserToken(String? phone) {
    if (phone == null || phone.trim().isEmpty) {
      return '';
    }

    var digits = phone.replaceAll(RegExp(r'\D'), '');

    if (digits.length == 11 && digits.startsWith('8')) {
      digits = '7${digits.substring(1)}';
    }

    if (digits.length == 10) {
      digits = '7$digits';
    }

    return digits;
  }

  @override
  Widget build(BuildContext context) {
    final topInset = _chatTopInset(context);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        _closeChat();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Padding(
          padding: EdgeInsets.only(
            top: topInset,
            bottom: bottomInset,
          ),
          child: Stack(
            children: [
              if (_webViewController != null)
                WebViewWidget(controller: _webViewController!),
              if (_isLoading)
                const ColoredBox(
                  color: Color(0xFF191430),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 16),
                        Text(
                          'Подключаем чат…',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_errorMessage != null)
                ColoredBox(
                  color: const Color(0xFF191430),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
