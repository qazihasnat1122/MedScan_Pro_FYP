class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  factory AuthException.fromFirebaseCode(String code) {
    switch (code) {
      case 'invalid-email':
        return AuthException('The email address is badly formatted.');
      case 'user-disabled':
        return AuthException(
          'Your account has been disabled. Please contact support.',
        );
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return AuthException('Invalid email or password.');
      case 'email-already-in-use':
        return AuthException('An account already exists for that email.');
      case 'operation-not-allowed':
        return AuthException('Email/password accounts are not enabled.');
      case 'weak-password':
        return AuthException('The password provided is too weak.');
      case 'network-request-failed':
        return AuthException('Network error. Please check your connection.');
      case 'permission-denied':
        return AuthException(
          'You do not have permission to perform this action.',
        );
      default:
        return AuthException('An unexpected error occurred. Please try again.');
    }
  }

  @override
  String toString() => message;
}
