import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/secure_note.dart';
import '../providers/mnemonic_notifier.dart';
import '../providers/note_provider.dart';
import 'note_editor_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<MnemonicNotifier, NoteProvider>(
      builder: (context, mnemonicNotifier, noteProvider, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Cryptic Notes'),
            leading: IconButton(
              onPressed: () => _showSettingsSheet(context, mnemonicNotifier),
              icon: const Icon(Icons.menu),
              tooltip: 'Settings',
            ),
          ),
          body: _buildBody(context, mnemonicNotifier, noteProvider),
          floatingActionButton: mnemonicNotifier.isReady
              ? FloatingActionButton.extended(
                  onPressed: () => _openEditor(context),
                  icon: const Icon(Icons.add),
                  label: const Text('New note'),
                )
              : null,
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    MnemonicNotifier mnemonicNotifier,
    NoteProvider provider,
  ) {
    if (!mnemonicNotifier.isReady) {
      return _buildLoggedOutState(context);
    }

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null) {
      return Center(
        child: Text(
          'Something went wrong:\n${provider.error}',
          textAlign: TextAlign.center,
        ),
      );
    }

    if (provider.notes.isEmpty) {
      return const Center(
        child: Text(
          'No notes yet.\nTap the button to create your first encrypted note.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      itemBuilder: (context, index) {
        final note = provider.notes[index];
        return _NoteCard(
          note: note,
          onTap: () => _openEditor(context, note: note),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemCount: provider.notes.length,
    );
  }

  Widget _buildLoggedOutState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 24),
            Text(
              'You are logged out',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Import your mnemonic to unlock your encrypted notes.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _showImportMnemonicDialog(context),
              icon: const Icon(Icons.key),
              label: const Text('Import mnemonic'),
            ),
          ],
        ),
      ),
    );
  }

  void _openEditor(BuildContext context, {SecureNote? note}) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)));
  }

  Future<void> _showMnemonicSheet(BuildContext context, String mnemonic) async {
    final words = mnemonic.split(' ');
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your 12-word key',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Keep these words secret. They unlock your encrypted notes.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(
                      words.length,
                      (index) =>
                          Chip(label: Text('${index + 1}. ${words[index]}')),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: mnemonic));
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Mnemonic copied to clipboard.'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy mnemonic'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showSettingsSheet(
    BuildContext context,
    MnemonicNotifier mnemonicNotifier,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.key),
                title: const Text('Import mnemonic'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showImportMnemonicDialog(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.vpn_key),
                title: const Text('Show mnemonic'),
                enabled: mnemonicNotifier.isReady,
                onTap: mnemonicNotifier.isReady
                    ? () {
                        Navigator.of(sheetContext).pop();
                        _showMnemonicSheet(context, mnemonicNotifier.mnemonic);
                      }
                    : null,
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Log out'),
                enabled: mnemonicNotifier.isReady,
                onTap: mnemonicNotifier.isReady
                    ? () {
                        Navigator.of(sheetContext).pop();
                        _confirmLogout(context);
                      }
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Log out'),
              content: const Text(
                'Logging out removes the mnemonic from this device. Import it again to access your encrypted notes.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Log out'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldLogout || !context.mounted) {
      return;
    }

    final notifier = context.read<MnemonicNotifier>();
    try {
      await notifier.logout();
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have been logged out.')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to log out: $error')),
      );
    }
  }

  Future<void> _showImportMnemonicDialog(BuildContext context) async {
    final mnemonicNotifier = context.read<MnemonicNotifier>();
    final controller = TextEditingController();
    String? errorMessage;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Enter mnemonic'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    minLines: 2,
                    maxLines: 4,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: 'Enter your 12-word mnemonic',
                      errorText: errorMessage,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final input = controller.text;
                    if (!mnemonicNotifier.isValidMnemonic(input)) {
                      setState(() {
                        errorMessage = 'That mnemonic is not valid.';
                      });
                      return;
                    }
                    try {
                      await mnemonicNotifier.importMnemonic(input);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Mnemonic imported successfully.'),
                          ),
                        );
                      }
                    } catch (error) {
                      setState(() {
                        errorMessage = 'Failed to import mnemonic.';
                      });
                    }
                  },
                  child: const Text('Use mnemonic'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, required this.onTap});

  final SecureNote note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final updatedAt = note.updatedAt ?? note.createdAt;
    return Material(
      color: theme.colorScheme.surface,
      elevation: 1,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note.title.isEmpty ? 'Untitled' : note.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                note.body.isEmpty ? 'No content' : note.body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
              if (updatedAt != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Updated ${_formatTimestamp(updatedAt)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime date) {
    final local = date.toLocal();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    final datePart =
        '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)}';
    final timePart = '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
    return '$datePart $timePart';
  }
}
