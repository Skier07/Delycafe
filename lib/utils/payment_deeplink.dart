import 'package:delycafe/utils/url_allowlist.dart';

/// Классификация URL в платёжном WebView (Альфа-Банк + СБП НСПК).
///
/// Принцип (как рекомендуют эквайеры и НСПК):
/// - форма оплаты / выбор банка остаются в WebView;
/// - deep link и universal link приложения банка открываются снаружи;
/// - без белого списка банков: любой региональный банк из виджета СБП.
enum PaymentUrlAction {
  /// Продолжить загрузку в WebView.
  stayInWebView,

  /// Открыть во внешнем приложении (банк / intent).
  openExternally,

  /// Игнорировать (about:/data:/javascript:).
  ignore,
}

bool isPaymentGatewayHost(Uri uri) {
  final host = uri.host.toLowerCase();
  if (host.isEmpty) return false;

  return host.contains('alfabank') ||
      host.contains('rbsuat') ||
      host.contains('securepayecom') ||
      host == 'nspk.ru' ||
      host == 'qr.nspk.ru' ||
      host == 'sub.nspk.ru' ||
      host.endsWith('.nspk.ru');
}

bool isPaymentReturnUrl(String url) {
  final normalized = url.toLowerCase();
  return normalized.contains('/api/payments/success') ||
      normalized.contains('/api/payments/fail');
}

/// Deep link приложения банка СБП (`bank100…://…`, intent://, sberpay://, …).
bool isSbpBankAppDeepLink(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) {
    return false;
  }

  final lowered = trimmed.toLowerCase();
  if (lowered.startsWith('intent:')) {
    return true;
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null) {
    return false;
  }

  final scheme = uri.scheme.toLowerCase();
  if (scheme.isEmpty ||
      scheme == 'http' ||
      scheme == 'https' ||
      scheme == 'about' ||
      scheme == 'data' ||
      scheme == 'javascript' ||
      scheme == 'blob' ||
      scheme == 'file' ||
      scheme == 'content') {
    return false;
  }

  return true;
}

/// Решает, что делать с URL из платёжного WebView.
PaymentUrlAction classifyPaymentNavigationUrl(String rawUrl) {
  final url = rawUrl.trim();
  if (url.isEmpty) {
    return PaymentUrlAction.ignore;
  }

  if (isPaymentReturnUrl(url)) {
    return PaymentUrlAction.stayInWebView;
  }

  final lowered = url.toLowerCase();
  if (lowered.startsWith('intent:')) {
    return PaymentUrlAction.openExternally;
  }

  final uri = Uri.tryParse(url);
  if (uri == null) {
    return PaymentUrlAction.ignore;
  }

  final scheme = uri.scheme.toLowerCase();

  if (scheme.isEmpty ||
      scheme == 'about' ||
      scheme == 'data' ||
      scheme == 'javascript' ||
      scheme == 'blob') {
    return PaymentUrlAction.ignore;
  }

  // ВАЖНО: до проверки 3DS/НСПК.
  // `bank100…://qr.nspk.ru/...` имеет host qr.nspk.ru и раньше
  // ошибочно оставался в WebView → net::ERR_UNKNOWN_URL_SCHEME.
  if (scheme != 'http' && scheme != 'https') {
    return PaymentUrlAction.openExternally;
  }

  if (isCard3dsPaymentUrl(url)) {
    return PaymentUrlAction.stayInWebView;
  }

  if (isPaymentGatewayHost(uri)) {
    return PaymentUrlAction.stayInWebView;
  }

  // HTTPS/HTTP вне шлюза Альфы/НСПК — universal link банка после выбора в СБП.
  return PaymentUrlAction.openExternally;
}

bool shouldOpenPaymentUrlExternally(String url) {
  return classifyPaymentNavigationUrl(url) == PaymentUrlAction.openExternally;
}

/// Собирает deep link из Android intent:// URL.
String? buildUrlFromAndroidIntent(String intentUrl) {
  final schemeMatch = RegExp(
    r';scheme=([^;]+);',
    caseSensitive: false,
  ).firstMatch(intentUrl);
  final scheme = schemeMatch?.group(1)?.trim();
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

String? extractAndroidIntentFallbackUrl(String intentUrl) {
  final fallbackMatch = RegExp(
    r';S\.browser_fallback_url=([^;]+);',
    caseSensitive: false,
  ).firstMatch(intentUrl);

  final encoded = fallbackMatch?.group(1);
  if (encoded == null || encoded.isEmpty) {
    return null;
  }

  try {
    return Uri.decodeComponent(encoded);
  } catch (_) {
    return encoded;
  }
}

String? extractAndroidIntentPackage(String intentUrl) {
  final packageMatch = RegExp(
    r';package=([^;]+);',
    caseSensitive: false,
  ).firstMatch(intentUrl);
  final packageName = packageMatch?.group(1)?.trim();
  if (packageName == null || packageName.isEmpty) {
    return null;
  }
  return packageName;
}

bool isHttpOrHttpsUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return false;
  final scheme = uri.scheme.toLowerCase();
  return scheme == 'http' || scheme == 'https';
}

/// `bank100…://qr.nspk.ru/PAYLOAD` → `https://qr.nspk.ru/PAYLOAD`
///
/// Если приложение банка не установлено, НСПК-ссылка открывается в браузере
/// (оплата через веб / установка приложения).
String? httpsFallbackFromSbpBankDeepLink(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  if (trimmed.toLowerCase().startsWith('intent:')) {
    final fromIntent = extractAndroidIntentFallbackUrl(trimmed);
    if (fromIntent != null && isHttpOrHttpsUrl(fromIntent)) {
      return fromIntent;
    }

    final rebuilt = buildUrlFromAndroidIntent(trimmed);
    if (rebuilt != null) {
      return httpsFallbackFromSbpBankDeepLink(rebuilt);
    }
    return null;
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null) {
    return null;
  }

  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'http' || scheme == 'https') {
    return null;
  }

  final host = uri.host.toLowerCase();
  if (host != 'qr.nspk.ru' &&
      host != 'sub.nspk.ru' &&
      !host.endsWith('.nspk.ru')) {
    // Иногда payload лежит в path без host: bank100…:///AD10100...
    final path = uri.path;
    if (path.isNotEmpty &&
        RegExp(r'^/?[A-Z0-9]{10,}', caseSensitive: false).hasMatch(path)) {
      final normalizedPath = path.startsWith('/') ? path : '/$path';
      final query = uri.hasQuery ? '?${uri.query}' : '';
      return 'https://qr.nspk.ru$normalizedPath$query';
    }
    return null;
  }

  final path = uri.path.isEmpty ? '' : uri.path;
  final query = uri.hasQuery ? '?${uri.query}' : '';
  final fragment = uri.hasFragment ? '#${uri.fragment}' : '';
  return 'https://$host$path$query$fragment';
}

/// Кандидаты на запуск: deep link банка → https НСПК → intent fallbacks.
List<String> paymentExternalLaunchCandidates(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) {
    return const [];
  }

  final candidates = <String>[];

  if (trimmed.toLowerCase().startsWith('intent:')) {
    final fromScheme = buildUrlFromAndroidIntent(trimmed);
    if (fromScheme != null && fromScheme.isNotEmpty) {
      candidates.add(fromScheme);
      final nspk = httpsFallbackFromSbpBankDeepLink(fromScheme);
      if (nspk != null) {
        candidates.add(nspk);
      }
    }

    final fallback = extractAndroidIntentFallbackUrl(trimmed);
    if (fallback != null && fallback.isNotEmpty) {
      candidates.add(fallback);
    }

    final packageName = extractAndroidIntentPackage(trimmed);
    if (packageName != null) {
      candidates.add('market://details?id=$packageName');
      candidates.add(
        'https://play.google.com/store/apps/details?id=$packageName',
      );
    }

    candidates.add(trimmed);
  } else {
    candidates.add(trimmed);
    final nspk = httpsFallbackFromSbpBankDeepLink(trimmed);
    if (nspk != null) {
      candidates.add(nspk);
    }
  }

  final seen = <String>{};
  return [
    for (final candidate in candidates)
      if (seen.add(candidate)) candidate,
  ];
}
