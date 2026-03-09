import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_dto.dart';

abstract class AuthRemoteDataSource {
  Future<UserDto> login(String identifier, String password);
  Future<void> logout();
  Future<UserDto?> getCurrentUser();
  Future<UserDto> signUp(
    String email,
    String username,
    String password, {
    String? displayName,
  });
  Future<void> sendPasswordReset(String email);
}

class SupabaseAuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final SupabaseClient supabaseClient;

  SupabaseAuthRemoteDataSourceImpl(this.supabaseClient);

  @override
  Future<UserDto> login(String identifier, String password) async {
    try {
      // 1. Resolve username to email using the secure Postgres RPC
      final rpcResponse = await supabaseClient.rpc(
        'login_with_username',
        params: {'login_identifier': identifier, 'login_password': password},
      );

      final resolvedEmail = rpcResponse['email'] as String?;
      if (resolvedEmail == null || resolvedEmail.isEmpty) {
        throw const ServerException('Account not found');
      }

      // 2. Perform the actual native SDK login with the resolved email
      final response = await supabaseClient.auth.signInWithPassword(
        email: resolvedEmail,
        password: password,
      );

      if (response.user == null) {
        throw const ServerException('Login failed: User is null');
      }

      // Map Supabase User to UserDto
      return UserDto(
        id: response.user!.id,
        email: response.user!.email ?? '',
        username: response.user!.userMetadata?['username'] as String?,
        displayName: response.user!.userMetadata?['display_name'] as String?,
        emailConfirmedAt: response.user!.emailConfirmedAt,
      );
    } on AuthException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> logout() async {
    try {
      await supabaseClient.auth.signOut();
    } catch (e) {
      throw ServerException('Failed to logout');
    }
  }

  @override
  Future<UserDto?> getCurrentUser() async {
    final user = supabaseClient.auth.currentUser;
    if (user != null) {
      return UserDto(
        id: user.id,
        email: user.email ?? '',
        username: user.userMetadata?['username'] as String?,
        displayName: user.userMetadata?['display_name'] as String?,
        emailConfirmedAt: user.emailConfirmedAt,
      );
    }
    return null;
  }

  @override
  Future<UserDto> signUp(
    String email,
    String username,
    String password, {
    String? displayName,
  }) async {
    try {
      // 1. Check if the username is available using the Postgres RPC
      final isAvailable = await supabaseClient.rpc(
        'check_username_available',
        params: {'requested_username': username},
      );

      // rpc returns a boolean based on our SQL script
      if (isAvailable == false) {
        throw const ServerException(
          'This username is already taken. Please choose another.',
        );
      }

      // 2. If available, proceed with account creation
      final response = await supabaseClient.auth.signUp(
        email: email,
        password: password,
        data: {'username': username, 'display_name': displayName ?? username},
      );
      if (response.user == null) {
        throw const ServerException('Sign up failed: User is null');
      }
      return UserDto(
        id: response.user!.id,
        email: response.user!.email ?? '',
        username: response.user!.userMetadata?['username'] as String?,
        displayName: response.user!.userMetadata?['display_name'] as String?,
        emailConfirmedAt: response.user!.emailConfirmedAt,
      );
    } on AuthException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await supabaseClient.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}

class ServerException implements Exception {
  final String message;
  const ServerException(this.message);
}
