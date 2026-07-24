import 'package:delycafe/config/api_config.dart';

bool isAllowedLegalDocumentUrl(String url) {
  final uri = Uri.tryParse(url);

  if (uri == null) {
    return false;
  }

  final host = uri.host.toLowerCase();
  final apiHost = Uri.parse(ApiConfig.normalizedBaseUrl).host.toLowerCase();

  return host == apiHost;
}

String normalizePaymentUrl(String raw) {
  var url = raw.trim();

  if (url.isEmpty) {
    return url;
  }

  if (url.contains('%3A%2F%2F') || url.contains('%2F')) {
    try {
      url = Uri.decodeComponent(url);
    } catch (_) {
      // Keep the original value when decoding fails.
    }
  }

  if (url.startsWith('//')) {
    return 'https:$url';
  }

  if (!RegExp(r'^[a-zA-Z][a-zA-Z\d+\-.]*://').hasMatch(url)) {
    return 'https://$url';
  }

  return url;
}

bool _isPaymentReturnUrl(String url) {
  final normalized = url.toLowerCase();

  return normalized.contains('/api/payments/success') ||
      normalized.contains('/api/payments/fail');
}

bool _isAlfaPaymentSessionUrl(String url) {
  final normalized = normalizePaymentUrl(url).toLowerCase();

  if (!normalized.contains('mdorder=')) {
    return false;
  }

  final uri = Uri.tryParse(normalized);
  if (uri == null || uri.host.isEmpty) {
    return false;
  }

  final host = uri.host.toLowerCase();

  return host.contains('alfabank') ||
      host.contains('rbsuat') ||
      host.contains('nspk') ||
      host.contains('securepayecom');
}

bool isAllowedPaymentUrl(String url) {
  final normalized = normalizePaymentUrl(url);
  final uri = Uri.tryParse(normalized);

  if (uri == null || uri.host.isEmpty) {
    return false;
  }

  if (_isPaymentReturnUrl(normalized)) {
    return true;
  }

  if (_isAlfaPaymentSessionUrl(normalized)) {
    return true;
  }

  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'https' && scheme != 'http') {
    return false;
  }

  final host = uri.host.toLowerCase();

  if (host.contains('alfabank') ||
      host.contains('rbsuat') ||
      host.contains('securepayecom') ||
      host == 'qr.nspk.ru' ||
      host == 'sub.nspk.ru') {
    return true;
  }

  for (final allowedHost in ApiConfig.paymentAllowedHosts) {
    if (host == allowedHost) {
      return true;
    }
  }

  for (final suffix in ApiConfig.paymentAllowedHostSuffixes) {
    if (host == suffix.substring(1) || host.endsWith(suffix)) {
      return true;
    }
  }

  final lowered = normalized.toLowerCase();

  return lowered.contains('alfabank.ru/payment/') ||
      lowered.contains('rbsuat.com/payment/');
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
