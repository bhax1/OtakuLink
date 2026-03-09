import '../../../../core/errors/failures.dart';
import '../entities/user_entity.dart';

/// Abstract repository for authentication.
/// Fully decoupled from Supabase or any specific implementation.
abstract class AuthRepository {
  /// Sign in with email or username and password
  FutureEither<UserEntity> login({
    required String identifier,
    required String password,
  });

  /// Sign out the current user
  FutureEitherVoid logout();

  /// Gets the currently authenticated user if one exists
  FutureEither<UserEntity?> getCurrentUser();

  /// Sign up with email, username, and password
  FutureEither<UserEntity> signUp({
    required String email,
    required String username,
    required String password,
    String? displayName,
  });

  /// Send a password reset email
  FutureEitherVoid sendPasswordReset(String email);
}
