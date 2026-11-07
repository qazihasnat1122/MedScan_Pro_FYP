class AppAuthUser {
  final String uid;
  final String email;
  final String displayName;

  const AppAuthUser({
    required this.uid,
    required this.email,
    this.displayName = '',
  });

  @override
  String toString() => 'AppAuthUser(uid: $uid, email: $email, name: $displayName)';
}
