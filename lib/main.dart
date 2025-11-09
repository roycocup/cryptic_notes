import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/mnemonic_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) {
    await auth.signInAnonymously();
  }
  final mnemonicService = MnemonicService();
  final mnemonic = await mnemonicService.loadOrCreateMnemonic();

  runApp(
    MyApp(
      mnemonicService: mnemonicService,
      initialMnemonic: mnemonic,
    ),
  );
}
