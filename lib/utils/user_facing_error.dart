import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

const String serverUnavailableMessage = 'Нет доступа к серверам';

String userFacingError(Object error) {
  if (error is SocketException ||
      error is TimeoutException ||
      error is HandshakeException ||
      error is HttpException ||
      error is http.ClientException) {
    return serverUnavailableMessage;
  }

  final message = error.toString().replaceFirst('Exception: ', '').trim();
  final normalized = message.toLowerCase();

  const networkMarkers = [
    'socketexception',
    'clientexception',
    'connection reset',
    'connection refused',
    'failed host lookup',
    'network is unreachable',
    'connection timed out',
    'operation timed out',
    'errno =',
  ];

  if (networkMarkers.any(normalized.contains)) {
    return serverUnavailableMessage;
  }

  return message;
}
