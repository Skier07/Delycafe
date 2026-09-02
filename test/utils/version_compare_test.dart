import 'package:delycafe/utils/version_compare.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compares semver-like versions', () {
    expect(isVersionGreater('1.4.3', '1.4.2'), isTrue);
    expect(isVersionGreater('1.4.2', '1.4.3'), isFalse);
    expect(isVersionGreater('1.4.10', '1.4.9'), isTrue);
    expect(isVersionGreater('1.4.2', '1.4.2'), isFalse);
  });
}
