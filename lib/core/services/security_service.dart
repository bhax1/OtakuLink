import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:otakulink/core/utils/secure_logger.dart';

enum UserRole { user, moderator, admin }

class SecurityService {
  final SupabaseClient _client;

  // Cache for the current user's profile
  Map<String, dynamic>? _currentProfile;

  final _roleController = StreamController<UserRole>.broadcast();
  Stream<UserRole> get onRoleChanged => _roleController.stream;

  SecurityService(this._client) {
    _init();
  }

  void _init() {
    _client.auth.onAuthStateChange.listen((data) {
      if (data.session != null) {
        _fetchProfile(data.session!.user.id);
      } else {
        _currentProfile = null;
        _roleController.add(UserRole.user);
      }
    });
  }

  Future<void> _fetchProfile(String userId) async {
    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      _currentProfile = data;
      _roleController.add(_getRoleFromString(data['role']));
    } catch (e, stack) {
      SecureLogger.logError("SecurityService _fetchProfile", e, stack);
      // If profile doesn't exist yet or error, default to user
      _roleController.add(UserRole.user);
    }
  }

  UserRole _getRoleFromString(String? role) {
    switch (role) {
      case 'admin':
        return UserRole.admin;
      case 'moderator':
        return UserRole.moderator;
      default:
        return UserRole.user;
    }
  }

  bool get isModerator =>
      _currentProfile?['role'] == 'moderator' ||
      _currentProfile?['role'] == 'admin';

  bool get isAdmin => _currentProfile?['role'] == 'admin';

  bool get isEmailVerified =>
      _client.auth.currentUser?.emailConfirmedAt != null;

  Future<void> resendVerificationEmail() async {
    final email = _client.auth.currentUser?.email;
    if (email != null) {
      await _client.auth.resend(type: OtpType.signup, email: email);
    }
  }

  Future<void> logAction({
    required String action,
    String? targetType,
    String? targetId,
    Map<String, dynamic>? metadata,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client.from('audit_logs').insert({
      'actor_id': userId,
      'action': action,
      'target_type': targetType,
      'target_id': targetId,
      'metadata': metadata,
    });
  }
}
