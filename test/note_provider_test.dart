import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:cryptic_notes/providers/mnemonic_notifier.dart';
import 'package:cryptic_notes/providers/note_provider.dart';
import 'package:cryptic_notes/services/encryption_service.dart';
import 'package:cryptic_notes/services/mnemonic_service.dart';
import 'package:cryptic_notes/services/note_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NoteProvider', () {
    late FakeFirebaseFirestore firestore;
    late NoteRepository repository;
    late EncryptionService encryptionService;
    late MnemonicNotifier mnemonicNotifier;
    late NoteProvider provider;

    setUp(() {
      const mnemonic =
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
      firestore = FakeFirebaseFirestore();
      repository = NoteRepository(firestore: firestore);
      encryptionService = EncryptionService();
      mnemonicNotifier = MnemonicNotifier(
        mnemonicService: _FakeMnemonicService(mnemonic),
        initialMnemonic: mnemonic,
      );
      provider = NoteProvider(
        repository: repository,
        encryptionService: encryptionService,
        mnemonicNotifier: mnemonicNotifier,
      );
    });

    tearDown(() {
      provider.dispose();
      mnemonicNotifier.dispose();
    });

    Future<void> pumpEvents() async {
      await pumpEventQueue(times: 5);
    }

    test('saveNote persists and exposes decrypted note', () async {
      await provider.saveNote(title: 'Hello', body: 'Secret body');
      await pumpEvents();

      expect(provider.notes, hasLength(1));
      final note = provider.notes.single;
      expect(note.title, 'Hello');
      expect(note.body, 'Secret body');
      expect(note.createdAt, isNotNull);
    });

    test('updateNote refreshes existing note contents', () async {
      await provider.saveNote(title: 'Original', body: 'Body');
      await pumpEvents();

      final existing = provider.notes.single;
      await provider.saveNote(
        id: existing.id,
        title: 'Updated',
        body: 'New body',
      );
      await pumpEvents();

      final updated = provider.notes.single;
      expect(updated.id, existing.id);
      expect(updated.title, 'Updated');
      expect(updated.body, 'New body');
      expect(updated.updatedAt, isNotNull);
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

