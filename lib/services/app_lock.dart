import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Helpers for the app lock: PIN hashing, fingerprint and phone-lock checks,
/// and a short pass for when the app leaves the screen on purpose.
class AppLock {
  AppLock._();

  static final LocalAuthentication _auth = LocalAuthentication();
  static DateTime? _awayOkUntil;

  /// Call before opening something outside the app on purpose (the file
  /// picker, the share sheet). Coming back within [duration] will not lock.
  static void allowAwayFor(Duration duration) {
    _awayOkUntil = DateTime.now().add(duration);
  }

  /// True once if [allowAwayFor] was called recently. Clears the pass.
  static bool consumeAwayAllowance() {
    final until = _awayOkUntil;
    _awayOkUntil = null;
    return until != null && DateTime.now().isBefore(until);
  }

  static String newSalt() {
    final random = Random.secure();
    return base64UrlEncode(List<int>.generate(16, (_) => random.nextInt(256)));
  }

  static String hashPin(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  /// True when the phone has any screen lock (PIN, pattern, fingerprint).
  static Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// True when at least one fingerprint or face is enrolled.
  static Future<bool> hasBiometrics() async {
    try {
      if (!await _auth.canCheckBiometrics) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Fingerprint or face when [biometricOnly] is true, otherwise the phone's
  /// own screen lock too. Any failure counts as "not unlocked".
  static Future<bool> authenticate({
    required bool biometricOnly,
    String reason = 'Unlock Pocketwell',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          biometricOnly: biometricOnly,
          stickyAuth: true,
          useErrorDialogs: false,
        ),
      );
    } catch (e) {
      debugPrint('Device authentication failed: $e');
      return false;
    }
  }
}
