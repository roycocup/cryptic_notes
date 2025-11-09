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
            actions: [
              IconButton(
                onPressed: () =>
                    _showMnemonicSheet(context, mnemonicNotifier.mnemonic),
                icon: const Icon(Icons.vpn_key),
                tooltip: 'Show mnemonic',
              ),
            ],
          ),
          body: _buildBody(noteProvider),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openEditor(context),
            icon: const Icon(Icons.add),
            label: const Text('New note'),
          ),
        );
      },
    );
  }

  Widget _buildBody(NoteProvider provider) {
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

  void _openEditor(BuildContext context, {SecureNote? note}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(note: note),
      ),
    );
  }

  Future<void> _showMnemonicSheet(
    BuildContext context,
    String mnemonic,
  ) async {
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
                      (index) => Chip(
                        label: Text('${index + 1}. ${words[index]}'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: mnemonic),
                      );
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
    final timePart =
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
    return '$datePart $timePart';
  }
}

