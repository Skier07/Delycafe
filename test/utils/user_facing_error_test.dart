import 'dart:async';
import 'dart:io';

import 'package:delycafe/utils/user_facing_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('hides technical network errors', () {
    expect(
      userFacingError(const SocketException('Connection reset by peer')),
      serverUnavailableMessage,
    );
    expect(
      userFacingError(http.ClientException('Failed host lookup')),
      serverUnavailableMessage,
    );
    expect(
      userFacingError(TimeoutException('Connection timed out')),
      serverUnavailableMessage,
    );
  });

  test('preserves useful server messages', () {
    expect(
      userFacingError(Exception('Неверный код. Попробуйте ещё раз.')),
      'Неверный код. Попробуйте ещё раз.',
    );
  });
}
