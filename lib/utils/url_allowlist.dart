import 'package:delycafe/config/api_config.dart';

bool isSecureWebUri(Uri? uri) =>
    uri != null &&
    uri.scheme == 'https' &&
    uri.host.isNotEmpty &&
    uri.userInfo.isEmpty &&
    uri.port == 443;

bool hostMatches(String host, String domain) =>
    host == domain || host.endsWith('.$domain');

bool isAllowedLegalDocumentUrl(String url) {
  final uri = Uri.tryParse(url);
  final api = Uri.parse(ApiConfig.normalizedBaseUrl);
  return isSecureWebUri(uri) && uri!.origin == api.origin;
}

String normalizePaymentUrl(String raw) {
  final url = raw.trim();
  // Do not decode an entire URL: it changes encoded query values and separators.
  return url.startsWith('//') ? 'https:$url' : url;
}

bool isTrustedPaymentReturnUrl(String url) {
  final uri = Uri.tryParse(url);
  final api = Uri.parse(ApiConfig.normalizedBaseUrl);
  return isSecureWebUri(uri) &&
      uri!.origin == api.origin &&
      const {
        '/api/payments/success/',
        '/api/payments/fail/',
        '/api/payments/success',
        '/api/payments/fail'
      }.contains(uri.path);
}

bool isTrustedPaymentGateway(Uri uri) {
  if (!isSecureWebUri(uri)) return false;
  final host = uri.host.toLowerCase();
  return ApiConfig.paymentAllowedHosts.contains(host) ||
      ApiConfig.paymentAllowedHostSuffixes.any((suffix) => hostMatches(
          host, suffix.startsWith('.') ? suffix.substring(1) : suffix)) ||
      hostMatches(host, 'nspk.ru');
}

bool isAllowedPaymentUrl(String url) {
  final normalized = normalizePaymentUrl(url);
  final uri = Uri.tryParse(normalized);
  return uri != null &&
      (isTrustedPaymentGateway(uri) || isTrustedPaymentReturnUrl(normalized));
}

/// Additional ACS origins are explicit; path fragments such as /acs/ confer no trust.
/// Unknown HTTPS issuer pages open in the system browser with a visible address.
bool isCard3dsPaymentUrl(String url) {
  final uri = Uri.tryParse(url);
  if (!isSecureWebUri(uri)) return false;
  const configured = String.fromEnvironment('PAYMENT_3DS_ALLOWED_HOSTS');
  final hosts =
      configured.split(',').map((value) => value.trim().toLowerCase());
  return hosts.contains(uri!.host.toLowerCase());
}

String paymentUrlRejectionHint(String url) {
  final normalized = normalizePaymentUrl(url);
  final uri = Uri.tryParse(normalized);
  final host = uri?.host.trim() ?? '';

  if (host.isEmpty) {
    return 'Недопустимая ссылка на оплату';
  }

  return 'Недопустимая ссылка на оплату ($host)';
}
