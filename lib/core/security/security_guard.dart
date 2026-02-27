import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:safe_device/safe_device.dart';

class SecurityGuard {
  /// Returns `true` only if the device passes all integrity checks.
  /// Returns `false` if rooted, jailbroken, or if the check fails (Fail-Closed).
  static Future<bool> isDeviceSecure() async {
    if (kDebugMode) {
      // Allow emulators/root only during development
      return true; 
    }

    try {
      final isJailBroken = await SafeDevice.isJailBroken;
      final isRealDevice = await SafeDevice.isRealDevice;

      // 1. Root/Jailbreak Check
      if (isJailBroken) return false;

      // 2. Emulator Check (Optional: enforce real devices only in prod)
      if (!isRealDevice) return false;

      return true;
    } catch (e) {
      // SECURITY FIX: If the check crashes, assume the device is COMPROMISED.
      // Do not log the specific error to console in release mode (avoids info leakage).
      return false;
    }
  }

  /// Terminates the app immediately.
  static void lockdown() {
    exit(0);
  }
}