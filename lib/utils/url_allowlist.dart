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

bool isAllowedPaymentUrl(String url) {
  final uri = Uri.tryParse(url);

  if (uri == null) {
    return false;
  }

  const allowedHosts = {
    'payment.alfabank.ru',
    'alfa.rbsuat.com',
    'pay.alfabank.ru',
  };

  final host = uri.host.toLowerCase();

  if (allowedHosts.contains(host)) {
    return true;
  }

  return host.endsWith('.alfabank.ru');
}
