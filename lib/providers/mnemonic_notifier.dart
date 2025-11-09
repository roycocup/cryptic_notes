import 'package:flutter/foundation.dart';

import '../services/mnemonic_service.dart';

class MnemonicNotifier extends ChangeNotifier {
  MnemonicNotifier({
    required this.mnemonicService,
    required String initialMnemonic,
  }) {
    _setMnemonic(initialMnemonic);
  }

  final MnemonicService mnemonicService;

  String? _mnemonic;
  String? _userIdHash;

  String get mnemonic => _mnemonic!;

  String get userIdHash => _userIdHash!;

  bool get isReady => _mnemonic != null && _userIdHash != null;

  Future<void> regenerate() async {
    await mnemonicService.clearMnemonic();
    final fresh = await mnemonicService.loadOrCreateMnemonic();
    _setMnemonic(fresh);
  }

  Future<void> reset() => regenerate();

  Future<void> importMnemonic(String mnemonic) async {
    final normalized = await mnemonicService.importMnemonic(mnemonic);
    _setMnemonic(normalized);
  }

  Future<void> logout() async {
    await mnemonicService.clearMnemonic();
    _mnemonic = null;
    _userIdHash = null;
    notifyListeners();
  }

  bool isValidMnemonic(String mnemonic) {
    return mnemonicService.isValidMnemonic(mnemonic);
  }

  void _setMnemonic(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    _mnemonic = normalized;
    _userIdHash = mnemonicService.deriveUserId(normalized);
    notifyListeners();
  }
}
