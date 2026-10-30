import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Cryptographic hashing and integrity checksum utilities.
class ChecksumUtil {
  ChecksumUtil._();

  /// Computes SHA-256 hex digest of raw bytes.
  static String calculateSha256(Uint8List bytes) {
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Computes SHA-256 hex digest of a string.
  static String calculateStringSha256(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  /// Verifies byte array matches expected SHA-256 checksum in constant time.
  static bool verifyChecksum(Uint8List bytes, String expectedHexDigest) {
    final actual = calculateSha256(bytes);
    return actual.toLowerCase() == expectedHexDigest.toLowerCase();
  }
}
