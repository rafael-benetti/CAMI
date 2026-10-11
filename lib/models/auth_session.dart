class AuthSession {
  final String token;
  final Map<String, dynamic> user;

  const AuthSession({required this.token, required this.user});
}
