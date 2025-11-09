import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cryptic_notes/providers/mnemonic_notifier.dart';
import 'package:cryptic_notes/services/mnemonic_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MnemonicNotifier', () {
    const initialMnemonic =
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
    const importedMnemonic =
        'legal winner thank year wave sausage worth useful legal winner thank yellow';

    late _FakeMnemonicService service;
    late MnemonicNotifier notifier;

    setUp(() {
      service = _FakeMnemonicService(initialMnemonic);
      notifier = MnemonicNotifier(
        mnemonicService: service,
        initialMnemonic: initialMnemonic,
      );
    });

    tearDown(() {
      notifier.dispose();
    });

    test('importMnemonic replaces mnemonic and updates user hash', () async {
      final previousHash = notifier.userIdHash;

      await notifier.importMnemonic(importedMnemonic);

      expect(
        notifier.mnemonic,
        'legal winner thank year wave sausage worth useful legal winner thank yellow',
      );
      expect(notifier.userIdHash, isNot(previousHash));
      expect(await service.readMnemonic(), notifier.mnemonic);
    });

    test('isValidMnemonic returns false for invalid phrases', () {
      expect(
        notifier.isValidMnemonic('not a valid mnemonic'),
        isFalse,
      );
    });
  });
}

class _FakeMnemonicService extends MnemonicService {
  _FakeMnemonicService(String mnemonic)
      : _mnemonic = mnemonic,
        super(secureStorage: const FlutterSecureStorage());

  String _mnemonic;

  @override
  Future<String?> readMnemonic() async => _mnemonic;

  @override
  Future<String> loadOrCreateMnemonic() async => _normalize(_mnemonic);

  @override
  Future<void> saveMnemonic(String mnemonic) async {
    _mnemonic = _normalize(mnemonic);
  }

  @override
  Future<void> clearMnemonic() async {
    _mnemonic = '';
  }

  @override
  String deriveUserId(String mnemonic) {
    final normalized = _normalize(mnemonic);
    final digest = sha256.convert(utf8.encode(normalized));
    return digest.toString();
  }

  String _normalize(String mnemonic) =>
      mnemonic.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}


