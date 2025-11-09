import 'package:cryptic_notes/services/encryption_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Encryption round-trip keeps payload intact', () {
    const mnemonic =
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
    final encryptionService = EncryptionService();
    final payload = encryptionService.encryptJson(
      const <String, dynamic>{
        'title': 'Hello',
        'body': 'Secret world',
      },
      mnemonic,
    );

    final decrypted = encryptionService.decryptJson(
      payload.ciphertext,
      payload.initializationVector,
      mnemonic,
    );

    expect(decrypted['title'], 'Hello');
    expect(decrypted['body'], 'Secret world');
  });
}
