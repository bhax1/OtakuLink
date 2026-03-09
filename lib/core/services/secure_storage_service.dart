import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A secure implementation of Supabase's [LocalStorage] that encrypts the persistence session.
/// Addresses IAS (Information Assurance and Security) requirement to prevent unsecure components
/// and enforce local data encryption on the device.
class SecureStorageService extends LocalStorage {
  final FlutterSecureStorage _storage;
  final String _key;

  const SecureStorageService({
    FlutterSecureStorage storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    ),
    String key = supabasePersistSessionKey,
  }) : _storage = storage,
       _key = key;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async {
    return await _storage.containsKey(key: _key);
  }

  @override
  Future<String?> accessToken() async {
    return await _storage.read(key: _key);
  }

  @override
  Future<void> removePersistedSession() async {
    await _storage.delete(key: _key);
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    await _storage.write(key: _key, value: persistSessionString);
  }
}
