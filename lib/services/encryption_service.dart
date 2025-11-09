import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

class EncryptedPayload {
  EncryptedPayload({
    required this.ciphertext,
    required this.initializationVector,
  });

  final String ciphertext;
  final String initializationVector;
}

class EncryptionService {
  EncryptedPayload encryptJson(Map<String, dynamic> payload, String mnemonic) {
    final plaintext = jsonEncode(payload);
    final key = _deriveKey(mnemonic);
    final ivBytes = _generateIv();
    final aes = encrypt.Encrypter(
      encrypt.AES(
        encrypt.Key(key),
        mode: encrypt.AESMode.cbc,
        padding: 'PKCS7',
      ),
    );
    final encrypted = aes.encrypt(
      plaintext,
      iv: encrypt.IV(ivBytes),
    );
    return EncryptedPayload(
      ciphertext: encrypted.base64,
      initializationVector: base64Encode(ivBytes),
    );
  }

  Map<String, dynamic> decryptJson(
    String ciphertext,
    String initializationVector,
    String mnemonic,
  ) {
    final key = _deriveKey(mnemonic);
    final iv = encrypt.IV(base64Decode(initializationVector));
    final aes = encrypt.Encrypter(
      encrypt.AES(
        encrypt.Key(key),
        mode: encrypt.AESMode.cbc,
        padding: 'PKCS7',
      ),
    );
    final decrypted = aes.decrypt64(ciphertext, iv: iv);
    return jsonDecode(decrypted) as Map<String, dynamic>;
  }

  Uint8List _deriveKey(String mnemonic) {
    final normalized = mnemonic.trim().replaceAll(RegExp(r'\s+'), ' ');
    final digest = sha256.convert(utf8.encode(normalized));
    return Uint8List.fromList(digest.bytes);
  }

  Uint8List _generateIv() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return Uint8List.fromList(bytes);
  }
}

