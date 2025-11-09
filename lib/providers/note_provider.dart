import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/secure_note.dart';
import '../services/encryption_service.dart';
import '../services/note_repository.dart';
import 'mnemonic_notifier.dart';

class NoteProvider extends ChangeNotifier {
  NoteProvider({
    required NoteRepository repository,
    required EncryptionService encryptionService,
    required MnemonicNotifier mnemonicNotifier,
  })  : _repository = repository,
        _encryptionService = encryptionService {
    _applyMnemonic(mnemonicNotifier);
  }

  final NoteRepository _repository;
  final EncryptionService _encryptionService;

  List<SecureNote> _notes = <SecureNote>[];
  StreamSubscription<List<EncryptedNoteDto>>? _subscription;
  String? _mnemonic;
  String? _userIdHash;
  bool _loading = false;
  String? _error;

  List<SecureNote> get notes => List.unmodifiable(_notes);

  bool get isLoading => _loading;

  String? get error => _error;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void updateMnemonic(MnemonicNotifier mnemonicNotifier) {
    if (!mnemonicNotifier.isReady) {
      _clearSession();
      return;
    }
    if (_mnemonic == mnemonicNotifier.mnemonic) {
      return;
    }
    _applyMnemonic(mnemonicNotifier);
  }

  Future<void> saveNote({
    String? id,
    required String title,
    required String body,
  }) async {
    final mnemonic = _mnemonic;
    final userIdHash = _userIdHash;
    if (mnemonic == null || userIdHash == null) {
      throw StateError('Mnemonic is not initialized.');
    }

    final payload = _encryptionService.encryptJson(
      <String, dynamic>{
        'title': title,
        'body': body,
      },
      mnemonic,
    );

    if (id == null) {
      await _repository.addNote(userIdHash, payload);
    } else {
      await _repository.updateNote(userIdHash, id, payload);
    }
  }

  Future<void> deleteNote(String noteId) async {
    final userIdHash = _userIdHash;
    if (userIdHash == null) {
      throw StateError('Mnemonic is not initialized.');
    }
    await _repository.deleteNote(userIdHash, noteId);
  }

  void _applyMnemonic(MnemonicNotifier notifier) {
    _mnemonic = notifier.mnemonic;
    _userIdHash = notifier.userIdHash;
    _loading = true;
    _error = null;
    notifyListeners();
    _subscription?.cancel();
    _subscription = _repository
        .watchNotes(_userIdHash!)
        .listen(_handleSnapshot, onError: _handleError);
  }

  void _handleSnapshot(List<EncryptedNoteDto> encryptedNotes) {
    final mnemonic = _mnemonic;
    if (mnemonic == null) {
      return;
    }

    final decrypted = <SecureNote>[];
    for (final dto in encryptedNotes) {
      try {
        final data = _encryptionService.decryptJson(
          dto.payload.ciphertext,
          dto.payload.initializationVector,
          mnemonic,
        );
        decrypted.add(
          SecureNote(
            id: dto.id,
            title: data['title'] as String? ?? 'Untitled',
            body: data['body'] as String? ?? '',
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt,
          ),
        );
      } catch (error) {
        debugPrint('Failed to decrypt note ${dto.id}: $error');
      }
    }

    _notes = decrypted;
    _loading = false;
    _error = null;
    notifyListeners();
  }

  void _handleError(Object error, StackTrace stackTrace) {
    _loading = false;
    _error = error.toString();
    notifyListeners();
  }

  void _clearSession() {
    final hadData = _mnemonic != null ||
        _userIdHash != null ||
        _notes.isNotEmpty ||
        _loading ||
        _error != null;
    _subscription?.cancel();
    _subscription = null;
    _mnemonic = null;
    _userIdHash = null;
    _notes = <SecureNote>[];
    _loading = false;
    _error = null;
    if (hadData) {
      notifyListeners();
    }
  }
}

