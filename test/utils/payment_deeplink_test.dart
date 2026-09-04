import 'package:delycafe/utils/payment_deeplink.dart';
import 'package:delycafe/utils/url_allowlist.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('classifyPaymentNavigationUrl', () {
    test('keeps Alfa payment page in WebView', () {
      expect(
        classifyPaymentNavigationUrl(
          'https://payment.alfabank.ru/payment/merchants/r-pizzaozersk/payment_ru.html?mdOrder=abc',
        ),
        PaymentUrlAction.stayInWebView,
      );
      expect(
        classifyPaymentNavigationUrl('https://payment.alfabank.ru/sc/JYPwxQDHJfsypzSo'),
        PaymentUrlAction.stayInWebView,
      );
    });

    test('keeps NSPK bank catalog in WebView', () {
      expect(
        classifyPaymentNavigationUrl(
          'https://qr.nspk.ru/AS100001ORTF4GAF80KPJ53K186D9A3G?type=01',
        ),
        PaymentUrlAction.stayInWebView,
      );
      expect(
        classifyPaymentNavigationUrl('https://sub.nspk.ru/proxyapp/c2bmembers.json'),
        PaymentUrlAction.stayInWebView,
      );
    });

    test('opens NSPK bank100 deep links externally (not 3DS)', () {
      const urls = [
        'bank100000000111://qr.nspk.ru/AD10100IQ8AIV6ET',
        'bank100000000140://qr.nspk.ru/AD10100IQ8AIV6ET?type=01',
        'bank100000000004://qr.nspk.ru/AS100001ORTF4GAF80KPJ53K186D9A3G',
      ];

      for (final url in urls) {
        expect(isCard3dsPaymentUrl(url), isFalse, reason: url);
        expect(isSbpBankAppDeepLink(url), isTrue, reason: url);
        expect(
          classifyPaymentNavigationUrl(url),
          PaymentUrlAction.openExternally,
          reason: url,
        );
      }
    });

    test('opens any bank custom scheme externally', () {
      const schemes = [
        'bank100000000111://payment?id=1',
        'bank100000000004://sbp?payload=1',
        'sberpay://transfer/123',
        'yandexbank://pay?token=1',
        'btripsexpenses://sbp',
        'intent://pay#Intent;scheme=bank100000000007;package=com.idamob.tinkoff.android;end',
      ];

      for (final url in schemes) {
        expect(
          classifyPaymentNavigationUrl(url),
          PaymentUrlAction.openExternally,
          reason: url,
        );
      }
    });

    test('opens regional bank HTTPS universal links externally', () {
      const banks = [
        'https://bank.yandex.ru/pay/sbp?id=1',
        'https://online.sberbank.ru/CSAFront/index.do#/pay',
        'https://www.tinkoff.ru/mybank/payments/sbp/',
        'https://online.vtb.ru/i/sbp',
        'https://ibo.gazprombank.ru/sbp/pay',
        'https://retail.rshb.ru/sbp',
        'https://my.pochtabank.ru/sbp',
      ];

      for (final url in banks) {
        expect(
          classifyPaymentNavigationUrl(url),
          PaymentUrlAction.openExternally,
          reason: url,
        );
      }
    });

    test('keeps return and 3DS urls in WebView', () {
      expect(
        classifyPaymentNavigationUrl(
          'https://api.delycafe.ru/api/payments/success/?orderId=1',
        ),
        PaymentUrlAction.stayInWebView,
      );
      expect(
        classifyPaymentNavigationUrl(
          'https://acs.example-bank.ru/3ds/challenge?xid=1',
        ),
        PaymentUrlAction.stayInWebView,
      );
    });

    test('ignores unsafe schemes', () {
      expect(
        classifyPaymentNavigationUrl('javascript:alert(1)'),
        PaymentUrlAction.ignore,
      );
      expect(
        classifyPaymentNavigationUrl('data:text/html,hi'),
        PaymentUrlAction.ignore,
      );
    });
  });

  group('paymentExternalLaunchCandidates', () {
    test('parses Android intent into bank scheme and fallbacks', () {
      const intent =
          'intent://payment/sbp#Intent;scheme=bank100000000007;'
          'package=com.idamob.tinkoff.android;'
          'S.browser_fallback_url=https%3A%2F%2Fwww.tinkoff.ru%2Fsbp;'
          'end';

      final candidates = paymentExternalLaunchCandidates(intent);

      expect(candidates.first, 'bank100000000007://payment/sbp');
      expect(candidates, contains('https://www.tinkoff.ru/sbp'));
      expect(
        candidates,
        contains('market://details?id=com.idamob.tinkoff.android'),
      );
    });

    test('builds https NSPK fallback from bank100 deep link', () {
      expect(
        httpsFallbackFromSbpBankDeepLink(
          'bank100000000111://qr.nspk.ru/AD10100IQ8AIV6ET',
        ),
        'https://qr.nspk.ru/AD10100IQ8AIV6ET',
      );
      expect(
        httpsFallbackFromSbpBankDeepLink(
          'bank100000000140://qr.nspk.ru/AD10100IQ8AIV6ET?type=01',
        ),
        'https://qr.nspk.ru/AD10100IQ8AIV6ET?type=01',
      );
    });

    test('launch candidates include https NSPK after bank scheme', () {
      final candidates = paymentExternalLaunchCandidates(
        'bank100000000111://qr.nspk.ru/AD10100IQ8AIV6ET',
      );

      expect(candidates.first, 'bank100000000111://qr.nspk.ru/AD10100IQ8AIV6ET');
      expect(candidates, contains('https://qr.nspk.ru/AD10100IQ8AIV6ET'));
    });

    test('returns plain url as single candidate', () {
      expect(
        paymentExternalLaunchCandidates('yandexbank://pay'),
        ['yandexbank://pay'],
      );
    });
  });
}
