import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:otakulink/core/cache/local_cache_service.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otakulink/services/user_service.dart';

// --- RIVERPOD PROVIDER ---
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    auth: FirebaseAuth.instance,
    firestore: FirebaseFirestore.instance,
    userService: ref.watch(userServiceProvider),
  );
});

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => message;
}

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final UserService _userService; // Holds the Riverpod memory cache

  AuthRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required UserService userService,
  })  : _auth = auth,
        _firestore = firestore,
        _userService = userService;

  // Security Constants
  static const String _genericError = "Invalid email, username, or password.";
  static const Duration _networkTimeout = Duration(seconds: 15);

  /// Authenticates a user using either Email or Username.
  /// Protects against User Enumeration by returning generic messages.
  Future<User> login(
      {required String identifier, required String password}) async {
    // ... [Keep your exact same login logic, input sanitization, and identifier resolution here] ...
    String emailToUse = identifier.trim();

    try {
      if (emailToUse.isEmpty || password.isEmpty) {
        throw const AuthException("Please fill in all fields.");
      }

      final isEmail =
          RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(emailToUse);

      if (!isEmail) {
        final querySnapshot = await _firestore
            .collection('users')
            .where('usernameLowercase', isEqualTo: emailToUse.toLowerCase())
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 10));

        if (querySnapshot.docs.isEmpty) {
          await Future.delayed(const Duration(milliseconds: 500));
          throw FirebaseAuthException(code: 'user-not-found');
        }
        emailToUse = querySnapshot.docs.first.get('email');
      }

      final credential = await _auth
          .signInWithEmailAndPassword(email: emailToUse, password: password)
          .timeout(_networkTimeout);

      final user = credential.user!;

      if (!user.emailVerified) {
        await _auth.signOut();
        throw const AuthException(
            "Email not verified. Please check your inbox.");
      }

      await _cacheUserData(user);
      await LocalCacheService.switchHistoryBox();

      return user;
    } on FirebaseAuthException catch (e) {
      print("Auth Security Log: ${e.code}");
      throw const AuthException(_genericError);
    } on SocketException {
      throw const AuthException("No internet connection.");
    } on TimeoutException {
      throw const AuthException("Request timed out. Please try again.");
    } catch (e) {
      throw const AuthException("An unexpected error occurred.");
    }
  }

  /// Registers a new user and ensures username uniqueness.
  /// Strictly rolls back all partial data if any step fails.
  Future<void> signUp({
    required String email,
    required String username,
    required String password,
  }) async {
    User? createdUser;
    bool usernameReserved = false;
    final lowerUsername = username.trim().toLowerCase();

    try {
      if (username.contains('@')) {
        throw const AuthException("Username cannot contain '@'.");
      }

      // 1. ATOMIC USERNAME RESERVATION
      final usernameRef = _firestore.collection('usernames').doc(lowerUsername);

      await _firestore.runTransaction((transaction) async {
        final usernameDoc = await transaction.get(usernameRef);

        if (usernameDoc.exists) {
          final data = usernameDoc.data() as Map<String, dynamic>;
          final status = data['status'];

          // Check if it's claimed OR if it's a recently pending reservation
          if (status == 'claimed') {
            throw const AuthException("This username is already taken.");
          } else if (status == 'pending') {
            final reservedAt = (data['reservedAt'] as Timestamp?)?.toDate();
            // If the reservation is less than 5 minutes old, consider it locked.
            if (reservedAt != null &&
                DateTime.now().difference(reservedAt).inMinutes < 5) {
              throw const AuthException(
                  "This username is currently being registered. Try again in a few minutes.");
            }
            // If it's older than 5 minutes, it's a zombie. We can safely overwrite it below.
          }
        }

        // Write the pending status ALONG with a timestamp
        transaction.set(usernameRef, {
          'status': 'pending',
          'reservedAt': FieldValue.serverTimestamp(),
        });
      });
      usernameReserved = true;

      // 2. Create Firebase Account
      final credential = await _auth
          .createUserWithEmailAndPassword(
              email: email.trim(), password: password)
          .timeout(_networkTimeout);

      createdUser = credential.user;

      // 3. Write Data
      final userRef = _firestore.collection('users').doc(createdUser!.uid);

      final uuid = const Uuid();
      final id = uuid.v4().replaceAll('-', '');
      final suffix = id.substring(0, 6);
      final displayName = 'user_$suffix';

      final batch = _firestore.batch();
      batch.set(userRef, {
        'username': username.trim(),
        'displayName': displayName,
        'usernameLowercase': lowerUsername,
        'email': email.trim(),
        'role': 'user',
        'createdAt': FieldValue.serverTimestamp(),
        // --- NEW: Initialize default cloud settings ---
        'settings': {
          'theme': 'light',
          'nsfw': false, // Always default to safe
        }
      });

      batch.update(usernameRef, {'uid': createdUser.uid, 'status': 'claimed'});

      await batch.commit().timeout(const Duration(seconds: 10));
      await createdUser.sendEmailVerification();
    } on AuthException {
      await _rollbackSignUp(createdUser, lowerUsername, usernameReserved);
      rethrow;
    } on FirebaseAuthException catch (e) {
      await _rollbackSignUp(createdUser, lowerUsername, usernameReserved);
      throw AuthException(_mapFirebaseError(e));
    } catch (e) {
      await _rollbackSignUp(createdUser, lowerUsername, usernameReserved);
      throw const AuthException("An unexpected error occurred during signup.");
    }
  }

  /// Helper method to guarantee data backtrack on sign-up failure
  Future<void> _rollbackSignUp(
      User? user, String usernameDocId, bool needsUsernameRollback) async {
    if (user != null) {
      try {
        await user.delete();
      } catch (_) {}
    }

    if (needsUsernameRollback) {
      try {
        await _firestore.collection('usernames').doc(usernameDocId).delete();
      } catch (_) {}
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      if (email.isEmpty) {
        throw const AuthException("Please enter an email address.");
      }

      await _auth
          .sendPasswordResetEmail(email: email.trim())
          .timeout(_networkTimeout);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        final fakeDelay = Random().nextInt(1000) + 500;
        await Future.delayed(Duration(milliseconds: fakeDelay));
        return;
      }

      if (e.code == 'invalid-email') {
        throw const AuthException("Please enter a valid email address.");
      }

      print("Reset Error: ${e.code}");
      throw const AuthException("Service temporarily unavailable.");
    } on SocketException {
      throw const AuthException("No internet connection.");
    } on TimeoutException {
      throw const AuthException("Request timed out. Connection is too slow.");
    } catch (e) {
      throw const AuthException("An unexpected error occurred.");
    }
  }

  Future<void> updatePassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthException("No active session found.");

    try {
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw const AuthException(
            'Please log out and log in again to change password.');
      }
      throw AuthException(e.message ?? 'Error updating password.');
    } catch (e) {
      throw const AuthException('An unexpected error occurred.');
    }
  }

  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'Password is too weak.';
      case 'email-already-in-use':
        return 'Email is already registered.';
      case 'invalid-email':
        return 'Please enter a valid email.';
      default:
        return 'Registration failed. Try again later.';
    }
  }

  Future<void> logout() async {
    try {
      // 1. Clear persistent disk cache
      await LocalCacheService.clearUserCache();

      // 2. CRITICAL FIX: Clear the Riverpod RAM cache to prevent cross-session data leaks
      _userService.clearAllCache();
    } catch (e) {
      print("Error clearing caches during logout: $e");
    }

    try {
      // 3. End Firebase session
      await _auth.signOut();

      // 4. Switch reading history back to guest box
      await LocalCacheService.switchHistoryBox();
    } catch (e) {
      throw const AuthException("Failed to log out cleanly. Please try again.");
    }
  }

  // Replace your old caching logic with this:
  Future<void> _cacheUserData(User user) async {
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return;

      final data = doc.data() as Map<String, dynamic>;

      // 1. Save Profile Data
      await LocalCacheService.saveUserProfile({
        'username': data['username'],
        'role': data['role'] ?? 'user',
        'lastSync': DateTime.now().millisecondsSinceEpoch,
      });

      // 2. Sync Cloud Settings to Local Cache
      if (data.containsKey('settings')) {
        final settingsMap = Map<String, dynamic>.from(data['settings']);
        await LocalCacheService.saveAllSettings(settingsMap);
      }
    } catch (e) {
      print("Caching failed: $e");
    }
  }

  Future<String?> getCachedUsername() async {
    return await LocalCacheService.getCachedUsername();
  }
}
