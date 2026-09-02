/// Сравнение semver-подобных строк (1.4.2, 1.4.10).
bool isVersionGreater(String left, String right) {
  final leftParts = _parseVersionParts(left);
  final rightParts = _parseVersionParts(right);
  final length = leftParts.length > rightParts.length
      ? leftParts.length
      : rightParts.length;

  for (var index = 0; index < length; index++) {
    final leftValue = index < leftParts.length ? leftParts[index] : 0;
    final rightValue = index < rightParts.length ? rightParts[index] : 0;

    if (leftValue > rightValue) {
      return true;
    }

    if (leftValue < rightValue) {
      return false;
    }
  }

  return false;
}

List<int> _parseVersionParts(String value) {
  return value
      .split('.')
      .map((part) => int.tryParse(part.trim()) ?? 0)
      .toList(growable: false);
}
