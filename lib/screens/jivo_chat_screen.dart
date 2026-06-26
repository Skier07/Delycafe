import 'package:delycafe/config/jivo_config.dart';
import 'package:delycafe/models/user.dart';
import 'package:delycafe/services/jivo_html_builder.dart';
import 'package:delycafe/ui/tokens/app_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

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
  bool _chatLoaded = false;

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

  Future<void> _configureAndroidWebView(WebViewController controller) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    final platform = controller.platform;

    if (platform is! AndroidWebViewController) {
      return;
    }

    await platform.setMediaPlaybackRequiresUserGesture(false);

    final cookieManager = AndroidWebViewCookieManager(
      AndroidWebViewCookieManagerCreationParams.fromPlatformWebViewCookieManagerCreationParams(
        const PlatformWebViewCookieManagerCreationParams(),
      ),
    );

    try {
      await cookieManager.setAcceptThirdPartyCookies(platform, true);
    } catch (error) {
      debugPrint('Jivo: third-party cookies setup failed: $error');
    }
  }

  Future<WebViewController> _createWebViewController(String html) async {
    final controller = WebViewController();

    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setBackgroundColor(Colors.white);
    await _configureAndroidWebView(controller);

    await controller.addJavaScriptChannel(
      'JivoBridge',
      onMessageReceived: (message) {
        if (!mounted) return;

        if (message.message == 'closed') {
          _closeChat();
          return;
        }

        setState(() {
          _chatLoaded = true;
          _isLoading = false;
          _errorMessage = null;
        });
      },
    );

    await controller.setNavigationDelegate(
      NavigationDelegate(
        onWebResourceError: (error) {
          if (!mounted || _chatLoaded) return;

          final isMainFrame = error.isForMainFrame ?? true;

          if (!isMainFrame) return;

          setState(() {
            _errorMessage = error.description;
            _isLoading = false;
          });
        },
      ),
    );

    await controller.loadHtmlString(html, baseUrl: JivoConfig.baseUrl);

    return controller;
  }

  Future<void> _initializeWebView() async {
    if (!JivoConfig.isConfigured) {
      setState(() {
        _errorMessage = 'JIVO_WIDGET_ID не задан';
        _isLoading = false;
      });
      return;
    }

    final user = widget.user;
    final html = JivoHtmlBuilder.build(
      contactName: user?.name,
      contactPhone: user?.phone,
      userToken: _buildUserToken(user?.phone),
    );

    try {
      final controller = await _createWebViewController(html);

      if (!mounted) return;

      setState(() {
        _webViewController = controller;
      });

      Future.delayed(JivoConfig.loadTimeout, () {
        if (!mounted || _chatLoaded || _errorMessage != null) return;

        setState(() {
          _isLoading = false;
          _errorMessage =
              'Не удалось загрузить чат. Попробуйте ещё раз или откройте в браузере.';
        });
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Ошибка инициализации чата: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _retry() async {
    setState(() {
      _webViewController = null;
      _isLoading = true;
      _errorMessage = null;
      _chatLoaded = false;
      _initStarted = false;
    });

    _initStarted = true;
    await _initializeWebView();
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.parse(JivoConfig.browserChatUrl);

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось открыть чат в браузере'),
        ),
      );
    }
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
                  color: AppColors.splashBackground,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CupertinoActivityIndicator(color: Colors.white),
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
                  color: AppColors.splashBackground,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: _isLoading ? null : _retry,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.header,
                            ),
                            child: const Text('Повторить'),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _openInBrowser,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white54),
                            ),
                            child: const Text('Открыть в браузере'),
                          ),
                        ],
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
