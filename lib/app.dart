import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/mnemonic_notifier.dart';
import 'providers/note_provider.dart';
import 'screens/home_screen.dart';
import 'services/encryption_service.dart';
import 'services/mnemonic_service.dart';
import 'services/note_repository.dart';

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.mnemonicService,
    required this.initialMnemonic,
  });

  final MnemonicService mnemonicService;
  final String initialMnemonic;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<MnemonicService>.value(value: mnemonicService),
        Provider<EncryptionService>(
          create: (_) => EncryptionService(),
        ),
        Provider<NoteRepository>(
          create: (_) => NoteRepository(),
        ),
        ChangeNotifierProvider<MnemonicNotifier>(
          create: (_) => MnemonicNotifier(
            mnemonicService: mnemonicService,
            initialMnemonic: initialMnemonic,
          ),
        ),
        ChangeNotifierProxyProvider<MnemonicNotifier, NoteProvider>(
          create: (context) => NoteProvider(
            repository: context.read<NoteRepository>(),
            encryptionService: context.read<EncryptionService>(),
            mnemonicNotifier: context.read<MnemonicNotifier>(),
          ),
          update: (context, mnemonicNotifier, previous) {
            if (previous == null) {
              return NoteProvider(
                repository: context.read<NoteRepository>(),
                encryptionService: context.read<EncryptionService>(),
                mnemonicNotifier: mnemonicNotifier,
              );
            }
            previous.updateMnemonic(mnemonicNotifier);
            return previous;
          },
        ),
      ],
      child: MaterialApp(
        title: 'Cryptic Notes',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

