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

  const OrderPaymentScreen({
    super.key,
    required this.orderId,
    required this.paymentUrl,
    required this.paymentAmount,
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
      _checkPaymentStatus(showErrors: false);
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

  void _setupWebView(String paymentUrl) {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _handleNavigation,
          onPageFinished: (_) {
            if (!mounted || _paymentCompleted) return;
            _checkPaymentStatus(showErrors: false);
          },
        ),
      )
      ..loadRequest(Uri.parse(paymentUrl));

    _webViewController = controller;
  }

  NavigationDecision _handleNavigation(NavigationRequest request) {
    final url = request.url.toLowerCase();

    if (_isPaymentReturnUrl(url)) {
      unawaited(_checkPaymentStatus(showErrors: false));
    }

    return NavigationDecision.navigate;
  }

  bool _isPaymentReturnUrl(String url) {
    return url.contains('/api/payments/success') ||
        url.contains('/api/payments/fail');
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_paymentCompleted && mounted) {
        _checkPaymentStatus(showErrors: false);
      }
    });
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

    if (!mounted) return;

    Navigator.pop(context, true);
  }

  Future<void> _openInBrowser() async {
    final url = _paymentUrl;

    if (url == null || url.isEmpty) return;

    final uri = Uri.parse(url);

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть страницу оплаты')),
      );
    }
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
                'После оплаты заказ автоматически отправится на кухню.',
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
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _openInBrowser,
                    child: const Text('Открыть в браузере'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.header,
                    ),
                    onPressed: () =>
                        _checkPaymentStatus(showErrors: true),
                    child: const Text('Проверить оплату'),
                  ),
                ),
              ],
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
