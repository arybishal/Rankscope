import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PBKDF2 + AES-GCM 256 encryption and decryption', () async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 10000,
      bits: 256,
    );
    final algorithm = AesGcm.with256bits();

    final random = Random.secure();
    final salt = Uint8List.fromList(
      List<int>.generate(16, (_) => random.nextInt(256)),
    );
    final nonce = Uint8List.fromList(
      List<int>.generate(12, (_) => random.nextInt(256)),
    );

    const password = 'SuperSecretPassword123!';
    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );

    final plaintext = utf8.encode(jsonEncode({'hello': 'world', 'count': 42}));
    final secretBox = await algorithm.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
    );

    // Decrypt with correct password
    final decryptedBytes = await algorithm.decrypt(
      SecretBox(secretBox.cipherText, nonce: nonce, mac: secretBox.mac),
      secretKey: secretKey,
    );
    expect(
      utf8.decode(decryptedBytes),
      jsonEncode({'hello': 'world', 'count': 42}),
    );

    // Decrypt with wrong password
    final wrongKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode('WrongPassword')),
      nonce: salt,
    );
    expect(
      () => algorithm.decrypt(
        SecretBox(secretBox.cipherText, nonce: nonce, mac: secretBox.mac),
        secretKey: wrongKey,
      ),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });
}
