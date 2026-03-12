import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'supabase_service.dart';
import '../utils/secure_logger.dart';

/// Service responsible for recording significant user actions into the persistent audit_logs table.
/// This supports accountability, monitoring, and debugging in production.
class AuditService {
  final SupabaseClient _client;

  AuditService(this._client);

  /// Records an action in the audit log.
  /// [action] - The type of event (e.g., 'login', 'update_profile')
  /// [targetTable] - Optional table name related to the action
  /// [targetId] - Optional UUID of the specific record affected
  /// [details] - Optional metadata or state changes
  Future<void> logAction({
    required String action,
    String? targetTable,
    String? targetId,
    Map<String, dynamic>? details,
  }) async {
    try {
      await _client.rpc(
        'log_user_action',
        params: {
          'p_action': action,
          'p_target_table': targetTable,
          'p_target_id': targetId,
          'p_details': details,
        },
      );

      SecureLogger.info('AuditLogged: $action');
    } catch (e, stack) {
      // We log locally but don't crash the user flow if audit logging fails
      SecureLogger.logError('AuditService.logAction($action)', e, stack);
    }
  }
}

final auditServiceProvider = Provider<AuditService>((ref) {
  return AuditService(SupabaseService.client);
});
