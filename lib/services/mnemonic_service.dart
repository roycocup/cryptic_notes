import 'dart:convert';

import 'package:bip39/bip39.dart' as bip39;
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MnemonicService {
  MnemonicService({FlutterSecureStorage? secureStorage})
    : _storage = secureStorage ?? const FlutterSecureStorage();

  static const _mnemonicKey = 'user_mnemonic';
  static const _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );
  static const _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock,
  );

  final FlutterSecureStorage _storage;

  Future<String?> readMnemonic() async {
    return _storage.read(
      key: _mnemonicKey,
      aOptions: _androidOptions,
      iOptions: _iosOptions,
    );
  }

  Future<String> loadOrCreateMnemonic() async {
    final cached = await readMnemonic();
    if (cached != null && cached.trim().isNotEmpty) {
      return _normalize(cached);
    }
    final generated = bip39.generateMnemonic(strength: 128);
    await saveMnemonic(generated);
    return _normalize(generated);
  }

  Future<void> saveMnemonic(String mnemonic) async {
    await _storage.write(
      key: _mnemonicKey,
      value: _normalize(mnemonic),
      aOptions: _androidOptions,
      iOptions: _iosOptions,
    );
  }

  Future<String> importMnemonic(String mnemonic) async {
    final normalized = _normalize(mnemonic);
    if (!bip39.validateMnemonic(normalized)) {
      throw ArgumentError('Invalid mnemonic phrase.');
    }
    await saveMnemonic(normalized);
    return normalized;
  }

  bool isValidMnemonic(String mnemonic) {
    return bip39.validateMnemonic(_normalize(mnemonic));
  }

  Future<void> clearMnemonic() => _storage.delete(
    key: _mnemonicKey,
    aOptions: _androidOptions,
    iOptions: _iosOptions,
  );

  String deriveUserId(String mnemonic) {
    final normalized = _normalize(mnemonic);
    final digest = sha256.convert(utf8.encode(normalized));
    return digest.toString();
  }

  String _normalize(String mnemonic) =>
      mnemonic.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}
