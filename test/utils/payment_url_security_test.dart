import 'package:delycafe/utils/payment_deeplink.dart';
import 'package:delycafe/utils/url_allowlist.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only exact HTTPS payment origins are embedded', () {
    for (final url in [
      'https://alfabank.attacker.invalid/payment/?mdOrder=x',
      'https://attacker.invalid/api/payments/success/',
      'https://attacker.invalid/acs/login',
      'http://payment.alfabank.ru/payment/',
      'https://payment.alfabank.ru.attacker.invalid/payment/',
      'https://payment.alfabank.ru@attacker.invalid/payment/',
      'https://payment.alfabank.ru:8443/payment/',
    ]) {
      expect(isAllowedPaymentUrl(url), isFalse, reason: url);
      expect(classifyPaymentNavigationUrl(url),
          isNot(PaymentUrlAction.stayInWebView),
          reason: url);
    }
    expect(
        isAllowedPaymentUrl('https://payment.alfabank.ru/payment/?mdOrder=x'),
        isTrue);
    expect(
        isPaymentReturnUrl(
            'https://api.delycafe.ru/api/payments/success/?orderId=1'),
        isTrue);
    expect(
        isPaymentReturnUrl('https://api.delycafe.ru/api/payments/success/evil'),
        isFalse);
    expect(isAllowedLegalDocumentUrl('http://api.delycafe.ru/terms/'), isFalse);
  });

  test('local URLs and unsafe intent fallbacks never launch', () {
    for (final url in [
      'file:///secret',
      'content://contacts',
      'javascript:alert(1)',
      'intent://secret#Intent;scheme=file;end'
    ]) {
      expect(classifyPaymentNavigationUrl(url), PaymentUrlAction.ignore);
    }
    final candidates = paymentExternalLaunchCandidates(
        'intent://pay#Intent;scheme=bank100000000007;S.browser_fallback_url=javascript%3Aalert(1);end');
    expect(candidates.any((url) => url.startsWith('javascript:')), isFalse);
  });

  test('normalization does not alter a bank query signature', () {
    const url =
        'https://payment.alfabank.ru/payment/?returnUrl=https%3A%2F%2Fapi.delycafe.ru%2F';
    expect(normalizePaymentUrl(url), url);
  });
}
