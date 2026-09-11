import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class StartCodeUtils {
  /// Generates a cryptographically random 6-digit numeric code (e.g., '384912').
  static String generateRandom6DigitCode() {
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

  /// Hashes the plain-text start code together with a salt using SHA-256.
  static String hashStartCode(String code, String salt) {
    final cleanCode = code.trim();
    final bytes = utf8.encode('$salt:$cleanCode');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verifies if [inputCode] matches the [expectedHash] when combined with [salt].
  /// This operates completely offline with zero network dependency.
  static bool verifyStartCode({
    required String inputCode,
    required String expectedHash,
    required String salt,
  }) {
    if (inputCode.trim().isEmpty || expectedHash.isEmpty) {
      return false;
    }
    final computed = hashStartCode(inputCode, salt);
    return computed.toLowerCase() == expectedHash.toLowerCase();
  }
}
