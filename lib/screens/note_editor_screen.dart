import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../models/secure_note.dart';
import '../providers/note_provider.dart';

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({super.key, this.note});

  final SecureNote? note;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _bodyController = TextEditingController(text: widget.note?.body ?? '');
    _titleController.addListener(_handleTextChanged);
    _bodyController.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _titleController.removeListener(_handleTextChanged);
    _bodyController.removeListener(_handleTextChanged);
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.note != null;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? 'Edit Note' : 'New Note'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Write'),
              Tab(text: 'Preview'),
            ],
          ),
          actions: [
            if (isEditing)
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: _isSaving ? null : _confirmDelete,
                tooltip: 'Delete note',
              ),
            TextButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Title',
                    ),
                    style: Theme.of(context).textTheme.headlineSmall,
                    textInputAction: TextInputAction.next,
                  ),
                  const Divider(),
                  Expanded(
                    child: TextField(
                      controller: _bodyController,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Write your secure note...',
                      ),
                      keyboardType: TextInputType.multiline,
                      maxLines: null,
                      expands: true,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  if (_titleController.text.trim().isNotEmpty) ...[
                    Text(
                      _titleController.text,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                  ],
                  MarkdownBody(
                    data: _bodyController.text.isEmpty
                        ? '_Nothing to preview yet._'
                        : _bodyController.text,
                    selectable: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!mounted) {
      return;
    }
    final title = _titleController.text.trim();
    final body = _bodyController.text;
    if (title.isEmpty && body.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot save an empty note.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await context.read<NoteProvider>().saveNote(
            id: widget.note?.id,
            title: title,
            body: body,
          );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save note: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _confirmDelete() async {
    if (!mounted) {
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete note'),
        content: const Text(
          'This will remove the note permanently from Firebase. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      await context
          .read<NoteProvider>()
          .deleteNote(widget.note!.id);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete note: $error')),
      );
      setState(() => _isSaving = false);
    }
  }

  void _handleTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }
}

