import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:delycafe/services/food_phrase_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('rotates server phrases without repetition and applies edits', () async {
    var phrases = ['Первый', 'Второй', 'Третий'];
    final service = FoodPhraseService(client: MockClient((request) async {
      expect(request.url.path, '/api/catalog/food-phrases/');
      return http.Response(jsonEncode(phrases), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }));
    final seen = <String>{};
    for (var i = 0; i < 3; i++) {
      seen.add(await service.next());
    }
    expect(seen, phrases.toSet());
    phrases = ['Новая фраза'];
    expect(await service.next(), 'Новая фраза');
    phrases = [];
    expect(await service.next(), '');
  });

  test('keeps server content across offline restart, no bundled fallback',
      () async {
    final online = FoodPhraseService(
        client:
            MockClient((_) async => http.Response('["Saved phrase"]', 200)));
    expect(await online.next(), 'Saved phrase');
    final offline = FoodPhraseService(
        client: MockClient((_) async => throw http.ClientException('Offline')));
    expect(await offline.next(), 'Saved phrase');
    SharedPreferences.setMockInitialValues({});
    final empty = FoodPhraseService(
        client: MockClient((_) async => http.Response('', 500)));
    expect(await empty.next(), '');
  });
}
