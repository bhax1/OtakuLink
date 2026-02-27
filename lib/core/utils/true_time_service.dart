import 'package:flutter/foundation.dart';
import 'package:ntp/ntp.dart';

class TrueTimeService {
  // Stores the difference between the real world and the user's phone
  static Duration _offset = Duration.zero;

  /// Call this ONCE when the app starts
  static Future<void> init() async {
    try {
      // 1. Ask a global time server what time it actually is (with a strict timeout)
      final DateTime networkTime = await NTP.now(
        lookUpAddress: 'time.google.com',
        timeout: const Duration(seconds: 3),
      );

      // 2. Calculate the exact difference between the phone clock and reality
      _offset = networkTime.difference(DateTime.now());

      debugPrint(
          "TrueTime Initialized. Device clock offset: ${_offset.inMinutes} minutes.");
    } catch (e) {
      // 3. Fallback: If the user opens the app offline, we safely default to the device clock
      debugPrint("TrueTime Offline: Defaulting to local device time.");
      _offset = Duration.zero;
    }
  }

  /// Use this INSTEAD of DateTime.now() for all secure cache logic.
  /// This runs in O(1) time (instant) because it uses the pre-calculated offset.
  static DateTime now() {
    return DateTime.now().add(_offset);
  }
}
