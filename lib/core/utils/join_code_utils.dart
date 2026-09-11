import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class JoinCodeUtils {
  static const String _hashPrefix = 'admin_join_code_v1:';

  /// Generates a cryptographically random 6-digit numeric code (e.g., '482731').
  static String generate6DigitCode() {
    final random = Random.secure();
    final number = 100000 + random.nextInt(900000);
    return number.toString();
  }

  /// Generates a random cryptographic hex salt string.
  static String generateSalt([int length = 16]) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Normalizes the code (trims, removes dashes/spaces, converts to uppercase).
  static String normalizeCode(String code) {
    return code.trim().replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
  }

  /// Hashes the normalized join code deterministically using SHA-256.
  /// This hash is used directly as the unique Document ID in Firestore (`admin_join_codes/{codeHash}`).
  static String hashJoinCode(String code) {
    final normalized = normalizeCode(code);
    final bytes = utf8.encode('$_hashPrefix$normalized');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verifies whether the provided [inputCode] matches the [expectedHash].
  static bool verifyJoinCode(String inputCode, String expectedHash) {
    if (inputCode.trim().isEmpty || expectedHash.isEmpty) {
      return false;
    }
    final computed = hashJoinCode(inputCode);
    return computed.toLowerCase() == expectedHash.toLowerCase();
  }
}
