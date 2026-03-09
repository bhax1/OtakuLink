import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/user_entity.dart';
import '../../auth_providers.dart';

/// The state class could also be created using Freezed, but we use AsyncValue implicitly with AsyncNotifier.
class AuthController extends AsyncNotifier<UserEntity?> {
  @override
  Future<UserEntity?> build() async {
    // Initial fetch of current user
    final repository = ref.watch(authRepositoryProvider);
    final result = await repository.getCurrentUser();

    return result.fold(
      (failure) => null, // If failed to get user or no user, state is null
      (user) => user,
    );
  }

  Future<void> login(String identifier, String password) async {
    state = const AsyncValue.loading();

    final loginUseCase = ref.read(loginUseCaseProvider);
    final result = await loginUseCase(
      identifier: identifier,
      password: password,
    );

    result.fold((failure) {
      state = AsyncValue.error(failure.message, StackTrace.current);
      throw AuthException(failure.message);
    }, (user) => state = AsyncValue.data(user));
  }

  Future<void> logout() async {
    state = const AsyncValue.loading();

    final repository = ref.read(authRepositoryProvider);
    await repository.logout();

    state = const AsyncValue.data(null);
  }

  Future<void> signUp(
    String email,
    String username,
    String password, {
    String? displayName,
  }) async {
    state = const AsyncValue.loading();

    final repository = ref.read(authRepositoryProvider);
    final result = await repository.signUp(
      email: email,
      username: username,
      password: password,
      displayName: displayName,
    );

    result.fold((failure) {
      state = AsyncValue.error(failure.message, StackTrace.current);
      throw AuthException(failure.message);
    }, (user) => state = AsyncValue.data(user));
  }

  Future<void> sendPasswordReset(String email) async {
    final repository = ref.read(authRepositoryProvider);
    final result = await repository.sendPasswordReset(email);

    result.fold((failure) => throw AuthException(failure.message), (_) => null);
  }
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, UserEntity?>(() {
      return AuthController();
    });
