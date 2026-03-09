import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/security_service.dart';

final securityServiceProvider = Provider<SecurityService>((ref) {
  final client = Supabase.instance.client;
  return SecurityService(client);
});

final userRoleProvider = StreamProvider<UserRole>((ref) {
  final securityService = ref.watch(securityServiceProvider);
  return securityService.onRoleChanged;
});
