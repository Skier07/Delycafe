import 'dart:async';

import 'package:delycafe/services/payment_api_service.dart';
import 'package:delycafe/ui/components/glass/shader_glass_container.dart';
import 'package:delycafe/ui/tokens/app_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class OrderPaymentScreen extends StatefulWidget {
  final int orderId;
  final String paymentUrl;
  final int paymentAmount;
  final String paymentType;

  const OrderPaymentScreen({
    super.key,
    required this.orderId,
    required this.paymentUrl,
    required this.paymentAmount,
    this.paymentType = 'card',
  });

  @override
  State<OrderPaymentScreen> createState() => _OrderPaymentScreenState();
}

class _OrderPaymentScreenState extends State<OrderPaymentScreen>
    with WidgetsBindingObserver {
  final _paymentApi = PaymentApiService();

  WebViewController? _webViewController;
  Timer? _pollTimer;

  String? _paymentUrl;
  String? _errorMessage;
  bool _isLoading = true;
  bool _isCheckingStatus = false;
  bool _paymentCompleted = false;
  bool _awaitingBankReturn = false;
  String? _lastLaunchedExternalUrl;
  DateTime? _lastLaunchedAt;
  int _statusRetryGeneration = 0;
  bool _sbpFlowTriggered = false;

  static final _bankSbpPathPattern = RegExp(
    r'paymentsbp|/sbp/|/sbp$|paysbp|sbp-pay',
    caseSensitive: false,
  );

  static const _bankSbpHosts = {
    'online.vtb.ru',
    'vtb.ru',
    'online.sberbank.ru',
    'sberbank.ru',
    'online.alfabank.ru',
    'alfabank.ru',
    'www.tinkoff.ru',
    'tinkoff.ru',
    'qr.nspk.ru',
    'sub.nspk.ru',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePayment();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_paymentCompleted) {
      if (_awaitingBankReturn) {
        _awaitingBankReturn = false;
      }
      unawaited(_checkPaymentStatusWithRetries());
    }
  }

  Future<void> _initializePayment() async {
    var paymentUrl = widget.paymentUrl.trim();

    if (paymentUrl.isEmpty) {
      try {
        final session = await _paymentApi.createPayment(widget.orderId);
        paymentUrl = session.paymentUrl;
      } catch (error) {
        if (!mounted) return;

        setState(() {
          _errorMessage = error.toString();
          _isLoading = false;
        });
        return;
      }
    }

    if (paymentUrl.isEmpty) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Ссылка на оплату не получена';
        _isLoading = false;
      });
      return;
    }

    _paymentUrl = paymentUrl;
    _setupWebView(paymentUrl);
    _startPolling();

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _maybeTriggerSbpFlow() async {
    if (_sbpFlowTriggered ||
        widget.paymentType.toLowerCase() != 'sbp' ||
        _webViewController == null) {
      return;
    }

    _sbpFlowTriggered = true;

    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted || _paymentCompleted || _webViewController == null) {
      return;
    }

    try {
      await _webViewController!.runJavaScript('''
        (function () {
          var bodyText = (document.body && document.body.innerText) || '';
          if (bodyText.toLowerCase().indexOf('выберите банк') >= 0) {
            return;
          }

          var selectors = [
            'button[data-payment-way="SBP_C2B"]',
            '[data-payment-way="SBP_C2B"]',
            'button[data-payment-type="SBP"]',
            '[data-payment-type="SBP"]',
            'a[href*="sbp"]'
          ];

          for (var i = 0; i < selectors.length; i++) {
            var element = document.querySelector(selectors[i]);
            if (element) {
              element.click();
              return;
            }
          }

          var clickables = document.querySelectorAll(
            'button, a, [role="button"], [class*="payment"]'
          );

          for (var j = 0; j < clickables.length; j++) {
            var node = clickables[j];
            var text = ((node.innerText || node.textContent || '') + '').toLowerCase();
            if (text.indexOf('сбп') >= 0 || text.indexOf('sbp') >= 0) {
              node.click();
              return;
            }
          }
        })();
      ''');
    } catch (error) {
      debugPrint('Не удалось автоматически открыть СБП: $error');
      _sbpFlowTriggered = false;
    }
  }

  void _setupWebView(String paymentUrl) {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _handleNavigation,
          onUrlChange: (change) {
            final url = change.url;
            if (url == null || url.isEmpty) {
              return;
            }

            _handleExternalUrl(url, fromNavigationRequest: false);
          },
          onPageFinished: (url) {
            if (!mounted || _paymentCompleted) return;
            unawaited(_maybeTriggerSbpFlow());
            if (_isPaymentReturnUrl(url)) {
              _checkPaymentStatus(showErrors: false);
            }
          },
          onWebResourceError: (error) {
            if (!mounted || _paymentCompleted) return;

            final isMainFrame = error.isForMainFrame ?? true;
            if (!isMainFrame) return;

            final failingUrl = error.url ?? '';
            if (failingUrl.isNotEmpty &&
                _shouldOpenOutsideWebView(failingUrl) &&
                _handleExternalUrl(failingUrl, fromNavigationRequest: false)) {
              return;
            }

            if (error.errorCode == -10 ||
                error.errorCode == -2 ||
                error.description.contains('ERR_UNKNOWN_URL_SCHEME') ||
                error.description.contains('ERR_NAME_NOT_RESOLVED')) {
              if (failingUrl.isNotEmpty &&
                  _shouldOpenOutsideWebView(failingUrl) &&
                  _handleExternalUrl(failingUrl, fromNavigationRequest: false)) {
                return;
              }
              return;
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(paymentUrl));

    _webViewController = controller;
  }

  NavigationDecision _handleNavigation(NavigationRequest request) {
    final url = request.url;

    if (_isPaymentReturnUrl(url)) {
      unawaited(_checkPaymentStatusWithRetries());
    }

    if (_handleExternalUrl(url, fromNavigationRequest: true)) {
      return NavigationDecision.prevent;
    }

    return NavigationDecision.navigate;
  }

  bool _handleExternalUrl(
    String url, {
    required bool fromNavigationRequest,
  }) {
    if (_isPaymentReturnUrl(url)) {
      return false;
    }

    if (!_shouldOpenOutsideWebView(url)) {
      return false;
    }

    if (!_markExternalLaunch(url)) {
      return true;
    }

    unawaited(_launchExternalPaymentUrl(url));
    return true;
  }

  bool _markExternalLaunch(String url) {
    final now = DateTime.now();
    if (_lastLaunchedExternalUrl == url &&
        _lastLaunchedAt != null &&
        now.difference(_lastLaunchedAt!) < const Duration(seconds: 3)) {
      return false;
    }

    _lastLaunchedExternalUrl = url;
    _lastLaunchedAt = now;
    return true;
  }

  bool _shouldOpenOutsideWebView(String url) {
    if (_isPaymentReturnUrl(url)) {
      return false;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      return false;
    }

    if (_isAlfaPaymentHost(uri)) {
      return false;
    }

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return scheme != 'about' &&
          scheme != 'data' &&
          scheme != 'javascript';
    }

    return _isBankSbpPaymentUrl(uri);
  }

  bool _isAlfaPaymentHost(Uri uri) {
    final host = uri.host.toLowerCase();

    return host.contains('alfabank.ru') &&
        (host.startsWith('payment.') ||
            host.startsWith('pay.') ||
            host.contains('ecom'));
  }

  bool _isBankSbpPaymentUrl(Uri uri) {
    final host = uri.host.toLowerCase();
    final path = '${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}'
        .toLowerCase();

    if (host == 'qr.nspk.ru' || host == 'sub.nspk.ru') {
      return true;
    }

    if (_bankSbpHosts.contains(host) || host.endsWith('.vtb.ru')) {
      return _bankSbpPathPattern.hasMatch(path) || host.startsWith('online.');
    }

    if (host.contains('sberbank.ru') && _bankSbpPathPattern.hasMatch(path)) {
      return true;
    }

    return _bankSbpPathPattern.hasMatch(path);
  }

  Future<void> _launchExternalPaymentUrl(String url) async {
    _awaitingBankReturn = true;

    if (mounted) {
      setState(() {});
    }

    final launched = await _tryLaunchExternalUrl(url);

    if (!mounted || launched) {
      return;
    }

    setState(() {
      _errorMessage =
          'Не удалось открыть приложение банка. Установите приложение '
          'вашего банка и повторите оплату.';
    });
  }

  Future<bool> _tryLaunchExternalUrl(String url) async {
    if (url.startsWith('intent://')) {
      final intentUri = Uri.tryParse(url);
      if (intentUri != null &&
          await launchUrl(intentUri, mode: LaunchMode.externalApplication)) {
        return true;
      }

      final bankSchemeUrl = _buildUrlFromAndroidIntent(url);
      if (bankSchemeUrl != null &&
          await launchUrl(
            Uri.parse(bankSchemeUrl),
            mode: LaunchMode.externalApplication,
          )) {
        return true;
      }

      final fallbackUrl = _extractAndroidIntentFallback(url);
      if (fallbackUrl != null) {
        return _tryLaunchExternalUrl(fallbackUrl);
      }

      return false;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      return false;
    }

    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String? _buildUrlFromAndroidIntent(String intentUrl) {
    final schemeMatch = RegExp(
      r';scheme=([^;]+);',
      caseSensitive: false,
    ).firstMatch(intentUrl);
    final scheme = schemeMatch?.group(1);
    if (scheme == null || scheme.isEmpty) {
      return null;
    }

    final path = intentUrl
        .replaceFirst(RegExp(r'^intent://', caseSensitive: false), '')
        .split('#Intent')
        .first;

    if (path.isEmpty) {
      return null;
    }

    return '$scheme://$path';
  }

  String? _extractAndroidIntentFallback(String intentUrl) {
    final fallbackMatch = RegExp(
      r';S\.browser_fallback_url=([^;]+);',
      caseSensitive: false,
    ).firstMatch(intentUrl);

    final encoded = fallbackMatch?.group(1);
    if (encoded == null || encoded.isEmpty) {
      return null;
    }

    return Uri.decodeComponent(encoded);
  }

  bool _isPaymentReturnUrl(String url) {
    final normalized = url.toLowerCase();

    return normalized.contains('/api/payments/success') ||
        normalized.contains('/api/payments/fail');
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_paymentCompleted && mounted) {
        _checkPaymentStatus(showErrors: false);
      }
    });
  }

  Future<void> _checkPaymentStatusWithRetries() async {
    final generation = ++_statusRetryGeneration;

    const delays = <Duration>[
      Duration.zero,
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
    ];

    for (final delay in delays) {
      if (_paymentCompleted || !mounted || generation != _statusRetryGeneration) {
        return;
      }

      if (delay > Duration.zero) {
        await Future.delayed(delay);
      }

      if (_paymentCompleted || !mounted || generation != _statusRetryGeneration) {
        return;
      }

      await _checkPaymentStatus(showErrors: false);

      if (_paymentCompleted) {
        return;
      }
    }
  }

  Future<void> _checkPaymentStatus({required bool showErrors}) async {
    if (_paymentCompleted || _isCheckingStatus) return;

    _isCheckingStatus = true;

    try {
      final status = await _paymentApi.checkStatus(widget.orderId);

      if (!mounted) return;

      if (status.isPaid) {
        _handlePaymentSuccess();
        return;
      }

      if (status.isFailed) {
        setState(() {
          _errorMessage = 'Оплата не прошла. Попробуйте ещё раз.';
        });
      }
    } catch (error) {
      if (showErrors && mounted) {
        setState(() {
          _errorMessage = error.toString();
        });
      }
    } finally {
      _isCheckingStatus = false;
    }
  }

  void _handlePaymentSuccess() {
    if (_paymentCompleted) return;

    _paymentCompleted = true;
    _pollTimer?.cancel();
    _statusRetryGeneration++;

    if (!mounted) return;

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEF7FF),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.header,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 64,
        titleSpacing: 16,
        title: Row(
          children: [
            ShaderGlassContainer(
              borderRadius: 30,
              onPressed: () => Navigator.pop(context, false),
              padding: const EdgeInsets.all(8),
              child: const Icon(
                CupertinoIcons.chevron_left_2,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Оплата заказа №${widget.orderId}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.header),
      );
    }

    if (_errorMessage != null && _paymentUrl == null) {
      return _buildMessage(
        title: 'Не удалось начать оплату',
        message: _errorMessage!,
        actionLabel: 'Назад',
        onAction: () => Navigator.pop(context, false),
      );
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          color: AppColors.header.withValues(alpha: 0.08),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'К оплате: ${widget.paymentAmount} ₽',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _awaitingBankReturn
                    ? 'Завершите оплату в приложении банка и вернитесь сюда.'
                    : 'После оплаты заказ автоматически отправится на кухню.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  color: Colors.black.withValues(alpha: 0.68),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.red,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: _webViewController == null
              ? const SizedBox.shrink()
              : WebViewWidget(controller: _webViewController!),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.header,
                ),
                onPressed: () => _checkPaymentStatus(showErrors: true),
                child: const Text('Проверить оплату'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessage({
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: Colors.black.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.header,
              ),
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
