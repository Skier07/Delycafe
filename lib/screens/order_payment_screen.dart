import 'dart:async';

import 'package:delycafe/services/payment_api_service.dart';
import 'package:delycafe/ui/components/glass/shader_glass_container.dart';
import 'package:delycafe/ui/tokens/app_colors.dart';
import 'package:delycafe/utils/haptic_feedback.dart';
import 'package:delycafe/utils/payment_deeplink.dart';
import 'package:delycafe/utils/url_allowlist.dart';
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
  bool _paymentFailedNotified = false;
  bool _awaitingBankReturn = false;
  bool _isClosing = false;
  String? _lastLaunchedExternalUrl;
  DateTime? _lastLaunchedAt;
  int _statusRetryGeneration = 0;
  bool _sbpFlowTriggered = false;

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
    var paymentUrl = normalizePaymentUrl(widget.paymentUrl);

    if (paymentUrl.isEmpty) {
      try {
        final session = await _paymentApi.createPayment(widget.orderId);
        paymentUrl = normalizePaymentUrl(session.paymentUrl);
      } catch (error) {
        if (!mounted) return;

        AppHaptics.error();
        setState(() {
          _errorMessage = error.toString();
          _isLoading = false;
        });
        return;
      }
    }

    if (!isAllowedPaymentUrl(paymentUrl)) {
      try {
        final session = await _paymentApi.createPayment(widget.orderId);
        final refreshed = normalizePaymentUrl(session.paymentUrl);

        if (refreshed.isNotEmpty && isAllowedPaymentUrl(refreshed)) {
          paymentUrl = refreshed;
        }
      } catch (_) {
        // Keep the original URL and show a clear allowlist error below.
      }
    }

    if (paymentUrl.isEmpty) {
      if (!mounted) return;

      AppHaptics.error();
      setState(() {
        _errorMessage = 'Ссылка на оплату не получена';
        _isLoading = false;
      });
      return;
    }

    if (!isAllowedPaymentUrl(paymentUrl)) {
      if (!mounted) return;

      AppHaptics.error();
      setState(() {
        _errorMessage = paymentUrlRejectionHint(paymentUrl);
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
      ..setOnJavaScriptAlertDialog((request) async {
        // Виджет СБП/Альфы сам пишет alert, если bank-app не установлен.
        // Мы уже открываем https://qr.nspk.ru/... в браузере — глушим шум.
        final message = request.message.toLowerCase();
        if (message.contains('не установлен') ||
            message.contains('not installed') ||
            message.contains('приложение не')) {
          return;
        }
      })
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _handleNavigation,
          onUrlChange: (change) {
            final url = change.url;
            if (url == null || url.isEmpty) {
              return;
            }

            _handleExternalUrl(url);
          },
          onPageFinished: (url) {
            if (!mounted || _paymentCompleted) return;
            unawaited(_maybeTriggerSbpFlow());
            if (isPaymentReturnUrl(url)) {
              _checkPaymentStatus(showErrors: false);
            }
          },
          onWebResourceError: (error) {
            if (!mounted || _paymentCompleted) return;

            final failingUrl = error.url ?? '';
            if (failingUrl.isEmpty) return;

            final isUnknownScheme =
                error.errorCode == -10 ||
                error.description.contains('ERR_UNKNOWN_URL_SCHEME') ||
                isSbpBankAppDeepLink(failingUrl);

            // bank100…:// не грузится в WebView — всегда пробуем приложение банка,
            // даже если ошибка не main-frame.
            if (isUnknownScheme || shouldOpenPaymentUrlExternally(failingUrl)) {
              if (_handleExternalUrl(failingUrl)) {
                unawaited(_recoverWebViewAfterBankHandoff());
              }
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(paymentUrl));

    _webViewController = controller;
  }

  /// Убирает страницу «Webpage not available» после handoff в банк.
  Future<void> _recoverWebViewAfterBankHandoff() async {
    final controller = _webViewController;
    if (controller == null) return;

    try {
      if (await controller.canGoBack()) {
        await controller.goBack();
        return;
      }
    } catch (_) {
      // fall through
    }

    final paymentUrl = _paymentUrl;
    if (paymentUrl != null && paymentUrl.isNotEmpty) {
      try {
        await controller.loadRequest(Uri.parse(paymentUrl));
      } catch (error) {
        debugPrint('Не удалось восстановить платёжную страницу: $error');
      }
    }
  }

  NavigationDecision _handleNavigation(NavigationRequest request) {
    final url = request.url;

    if (isPaymentReturnUrl(url)) {
      unawaited(_checkPaymentStatusWithRetries());
      return NavigationDecision.navigate;
    }

    if (isCard3dsPaymentUrl(url)) {
      return NavigationDecision.navigate;
    }

    switch (classifyPaymentNavigationUrl(url)) {
      case PaymentUrlAction.ignore:
        return NavigationDecision.prevent;
      case PaymentUrlAction.openExternally:
        _handleExternalUrl(url);
        return NavigationDecision.prevent;
      case PaymentUrlAction.stayInWebView:
        return NavigationDecision.navigate;
    }
  }

  bool _handleExternalUrl(String url) {
    if (!shouldOpenPaymentUrlExternally(url)) {
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
        now.difference(_lastLaunchedAt!) < const Duration(seconds: 2)) {
      return false;
    }

    _lastLaunchedExternalUrl = url;
    _lastLaunchedAt = now;
    return true;
  }

  Future<void> _launchExternalPaymentUrl(String url) async {
    _awaitingBankReturn = true;

    if (mounted) {
      setState(() {
        _errorMessage = null;
      });
    }

    final launchedApp = await _tryLaunchExternalUrl(
      url,
      preferBrowserFallback: false,
    );

    if (!mounted) {
      return;
    }

    if (launchedApp) {
      return;
    }

    // Приложения нет — открываем https://qr.nspk.ru/... в браузере.
    final browserFallback = httpsFallbackFromSbpBankDeepLink(url) ??
        _httpsFallbackForFailedLaunch(url);

    if (browserFallback != null) {
      final openedBrowser = await _tryLaunchHttpsInBrowser(browserFallback);
      if (!mounted) {
        return;
      }
      if (openedBrowser) {
        setState(() {
          _errorMessage = null;
        });
        return;
      }

      // Браузер тоже не открылся — форма НСПК внутри WebView.
      try {
        await _webViewController?.loadRequest(Uri.parse(browserFallback));
        if (mounted) {
          setState(() {
            _awaitingBankReturn = false;
            _errorMessage = null;
          });
        }
        return;
      } catch (error) {
        debugPrint('Не удалось загрузить fallback URL банка: $error');
      }
    }

    AppHaptics.error();
    setState(() {
      _errorMessage =
          'Не удалось открыть оплату. Установите приложение банка '
          'или выберите другой банк в списке СБП.';
    });
  }

  String? _httpsFallbackForFailedLaunch(String url) {
    final fromDeepLink = httpsFallbackFromSbpBankDeepLink(url);
    if (fromDeepLink != null) {
      return fromDeepLink;
    }

    if (isHttpOrHttpsUrl(url)) {
      return url;
    }

    for (final candidate in paymentExternalLaunchCandidates(url)) {
      if (isHttpOrHttpsUrl(candidate) &&
          !candidate.contains('play.google.com') &&
          !candidate.startsWith('market:')) {
        return candidate;
      }
    }

    return null;
  }

  Future<bool> _tryLaunchHttpsInBrowser(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !isHttpOrHttpsUrl(url)) {
      return false;
    }

    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (error) {
      debugPrint('Не удалось открыть браузер для СБП ($url): $error');
      return false;
    }
  }

  Future<bool> _tryLaunchExternalUrl(
    String url, {
    bool preferBrowserFallback = false,
  }) async {
    final candidates = paymentExternalLaunchCandidates(url);

    for (final candidate in candidates) {
      final uri = Uri.tryParse(candidate);
      if (uri == null) {
        continue;
      }

      // Не вызываем canLaunchUrl: на iOS лимит LSApplicationQueriesSchemes (~50)
      // не покрывает все банки СБП. openURL работает без whitelist схем.
      try {
        if (isHttpOrHttpsUrl(candidate)) {
          if (!preferBrowserFallback) {
            // Сначала только приложение банка (не браузер).
            if (await launchUrl(
              uri,
              mode: LaunchMode.externalNonBrowserApplication,
            )) {
              return true;
            }
            continue;
          }

          if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
            return true;
          }
          continue;
        }

        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          return true;
        }
      } catch (error) {
        debugPrint('Не удалось открыть банковский URL ($candidate): $error');
      }
    }

    return false;
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

      if (status.isFailed && !_paymentFailedNotified) {
        _paymentFailedNotified = true;
        _pollTimer?.cancel();
        AppHaptics.error();
        setState(() {
          _errorMessage = 'Оплата не прошла. Попробуйте ещё раз.';
        });
      }
    } catch (error) {
      if (showErrors && mounted) {
        AppHaptics.error();
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

  /// Назад / системная кнопка: сначала сверяем статус с банком.
  /// Иначе после успешной оплаты на промо-странице банка «Назад»
  /// ошибочно помечает платёж как незавершённый.
  Future<void> _onClosePressed() async {
    if (_paymentCompleted || _isClosing) return;

    setState(() {
      _isClosing = true;
      _errorMessage = null;
    });

    try {
      await _checkPaymentStatusWithRetries();

      if (!mounted) return;

      if (_paymentCompleted) {
        return;
      }

      Navigator.pop(context, false);
    } finally {
      if (mounted && !_paymentCompleted) {
        setState(() {
          _isClosing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_onClosePressed());
      },
      child: Scaffold(
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
                onPressed:
                    _isClosing ? null : () => unawaited(_onClosePressed()),
                padding: const EdgeInsets.all(8),
                child: _isClosing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        CupertinoIcons.chevron_left_2,
                        color: Colors.white,
                        size: 24,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _isClosing
                      ? 'Проверяем оплату…'
                      : 'Оплата заказа №${widget.orderId}',
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
      ),
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
