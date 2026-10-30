import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rankscope/core/utils/checksum_util.dart';

void main() {
  group('ChecksumUtil', () {
    test('calculates correct SHA-256 for strings and raw bytes', () {
      final input = 'RankScope-Air-Gapped-Backup';
      final bytes = utf8.encode(input);
      final hash = ChecksumUtil.calculateSha256(bytes);

      expect(hash, isNotEmpty);
      expect(hash.length, 64);
      expect(ChecksumUtil.verifyChecksum(bytes, hash), isTrue);
      expect(ChecksumUtil.verifyChecksum(bytes, 'corrupted_hash'), isFalse);
    });
  });
}
