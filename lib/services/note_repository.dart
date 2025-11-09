import 'package:cloud_firestore/cloud_firestore.dart';

import 'encryption_service.dart';

class EncryptedNoteDto {
  EncryptedNoteDto({
    required this.id,
    required this.payload,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final EncryptedPayload payload;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class NoteRepository {
  NoteRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _userCollection(String userIdHash) {
    return _firestore.collection('users').doc(userIdHash).collection('notes');
  }

  Stream<List<EncryptedNoteDto>> watchNotes(String userIdHash) {
    return _userCollection(userIdHash)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            return EncryptedNoteDto(
              id: doc.id,
              payload: EncryptedPayload(
                ciphertext: data['ciphertext'] as String? ?? '',
                initializationVector: data['iv'] as String? ?? '',
              ),
              createdAt: _timestampToDate(data['createdAt']),
              updatedAt: _timestampToDate(data['updatedAt']),
            );
          }).toList(),
        );
  }

  Future<void> addNote(
    String userIdHash,
    EncryptedPayload payload,
  ) async {
    await _userCollection(userIdHash).add({
      'ciphertext': payload.ciphertext,
      'iv': payload.initializationVector,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateNote(
    String userIdHash,
    String noteId,
    EncryptedPayload payload,
  ) async {
    await _userCollection(userIdHash).doc(noteId).update({
      'ciphertext': payload.ciphertext,
      'iv': payload.initializationVector,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteNote(String userIdHash, String noteId) {
    return _userCollection(userIdHash).doc(noteId).delete();
  }

  DateTime? _timestampToDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }
}

