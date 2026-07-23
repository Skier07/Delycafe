class AuthRequiredException implements Exception {
  const AuthRequiredException([
    this.message = 'Войдите по SMS для продолжения.',
  ]);

  final String message;

  @override
  String toString() => message;
}
