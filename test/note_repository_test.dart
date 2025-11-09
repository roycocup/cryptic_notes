import 'dart:async';

import 'package:async/async.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cryptic_notes/services/encryption_service.dart';
import 'package:cryptic_notes/services/note_repository.dart';

void main() {
  group('NoteRepository', () {
    late FakeFirebaseFirestore firestore;
    late NoteRepository repository;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = NoteRepository(firestore: firestore);
    });

    test('adds note and emits it via watchNotes', () async {
      final payload = EncryptedPayload(
        ciphertext: 'ciphertext-1',
        initializationVector: 'iv-1',
      );

      await repository.addNote('user-hash', payload);

      final notes = await repository.watchNotes('user-hash').first;
      expect(notes, hasLength(1));
      final note = notes.first;
      expect(note.payload.ciphertext, 'ciphertext-1');
      expect(note.payload.initializationVector, 'iv-1');
      expect(note.id, isNotEmpty);
    });

    test('updateNote refreshes emitted payload and timestamps', () async {
      final initial = EncryptedPayload(
        ciphertext: 'ciphertext-initial',
        initializationVector: 'iv-initial',
      );
      await repository.addNote('user-hash', initial);

      final queue = StreamQueue(repository.watchNotes('user-hash'));
      final firstEmission = await queue.next;
      final noteId = firstEmission.single.id;

      final updated = EncryptedPayload(
        ciphertext: 'ciphertext-updated',
        initializationVector: 'iv-updated',
      );
      await repository.updateNote('user-hash', noteId, updated);

      final secondEmission = await queue.next;
      final updatedNote = secondEmission.singleWhere(
        (note) => note.id == noteId,
      );
      expect(updatedNote.payload.ciphertext, 'ciphertext-updated');
      expect(updatedNote.payload.initializationVector, 'iv-updated');
      expect(updatedNote.updatedAt, isNotNull);
      await queue.cancel();
    });
  });
}
