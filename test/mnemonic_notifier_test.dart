import 'dart:collection';
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

    test('regenerate creates a fresh mnemonic after logout', () async {
      final serviceWithQueue = _FakeMnemonicService(
        initialMnemonic,
        generatedMnemonics: const [importedMnemonic],
      );
      final notifierWithQueue = MnemonicNotifier(
        mnemonicService: serviceWithQueue,
        initialMnemonic: initialMnemonic,
      );

      await notifierWithQueue.logout();
      await notifierWithQueue.regenerate();

      expect(
        notifierWithQueue.mnemonic,
        'legal winner thank year wave sausage worth useful legal winner thank yellow',
      );
      expect(notifierWithQueue.isReady, isTrue);
      expect(
        await serviceWithQueue.readMnemonic(),
        notifierWithQueue.mnemonic,
      );

      notifierWithQueue.dispose();
    });
  });
}

class _FakeMnemonicService extends MnemonicService {
  _FakeMnemonicService(
    String mnemonic, {
    List<String> generatedMnemonics = const [],
  })  : _mnemonic = mnemonic,
        _generatedMnemonics = Queue<String>.of(generatedMnemonics),
        super(secureStorage: const FlutterSecureStorage());

  String _mnemonic;
  final Queue<String> _generatedMnemonics;

  @override
  Future<String?> readMnemonic() async {
    if (_mnemonic.trim().isEmpty) {
      return null;
    }
    return _normalize(_mnemonic);
  }

  @override
  Future<String> loadOrCreateMnemonic() async {
    final cached = await readMnemonic();
    if (cached != null) {
      return cached;
    }
    if (_generatedMnemonics.isEmpty) {
      throw StateError('No generated mnemonics queued.');
    }
    final generated = _generatedMnemonics.removeFirst();
    _mnemonic = generated;
    return _normalize(generated);
  }

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


