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
  late final _HighlightingTextEditingController _bodyController;
  late final TextEditingController _searchController;
  late final FocusNode _bodyFocusNode;
  late final FocusNode _searchFocusNode;
  late final ScrollController _bodyScrollController;
  final GlobalKey _bodyTextFieldKey = GlobalKey();
  bool _isSaving = false;
  bool _isSearching = false;
  List<int> _searchMatches = const <int>[];
  int _currentMatchIndex = 0;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _bodyController =
        _HighlightingTextEditingController(text: widget.note?.body ?? '');
    _searchController = TextEditingController();
    _bodyFocusNode = FocusNode();
    _searchFocusNode = FocusNode();
    _bodyScrollController = ScrollController();
    _titleController.addListener(_handleTextChanged);
    _bodyController.addListener(_handleTextChanged);
    _searchController.addListener(_handleSearchQueryChanged);
  }

  @override
  void dispose() {
    _titleController.removeListener(_handleTextChanged);
    _bodyController.removeListener(_handleTextChanged);
    _searchController.removeListener(_handleSearchQueryChanged);
    _titleController.dispose();
    _bodyController.dispose();
    _searchController.dispose();
    _bodyFocusNode.dispose();
    _searchFocusNode.dispose();
    _bodyScrollController.dispose();
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
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(_isSearching ? 104 : 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isSearching) _buildSearchControls(context),
                const TabBar(
                  tabs: [
                    Tab(text: 'Write'),
                    Tab(text: 'Preview'),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search),
              onPressed: _toggleSearch,
              tooltip: _isSearching ? 'Close search' : 'Search in note',
            ),
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
                      key: _bodyTextFieldKey,
                      controller: _bodyController,
                      focusNode: _bodyFocusNode,
                      scrollController: _bodyScrollController,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Write your secure note...',
                      ),
                      style: Theme.of(context).textTheme.bodyMedium,
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

  Widget _buildSearchControls(BuildContext context) {
    final matchCount = _searchMatches.length;
    final matchSummary =
        matchCount == 0 ? '0/0' : '${_currentMatchIndex + 1}/$matchCount';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Search in note',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear search',
                        onPressed: _searchController.clear,
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              textInputAction: TextInputAction.search,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            matchSummary,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up),
            onPressed: matchCount > 0 ? _goToPreviousMatch : null,
            tooltip: 'Previous match',
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down),
            onPressed: matchCount > 0 ? _goToNextMatch : null,
            tooltip: 'Next match',
          ),
        ],
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
    if (!mounted) {
      return;
    }
    final hasQuery = _searchController.text.isNotEmpty;
    _bodyController.setHighlightQuery(hasQuery ? _searchController.text : '');
    setState(() {
      if (hasQuery) {
        final matches =
            _computeMatches(_searchController.text, _bodyController.text);
        _applyMatches(matches, jumpToFirst: false);
      }
    });
    if (hasQuery) {
      if (_searchMatches.isNotEmpty) {
        _highlightCurrentMatch();
      } else {
        _resetBodySelection();
      }
    }
  }

  void _handleSearchQueryChanged() {
    if (!mounted) {
      return;
    }
    final matches =
        _computeMatches(_searchController.text, _bodyController.text);
    _bodyController.setHighlightQuery(_searchController.text);
    setState(() {
      _applyMatches(matches, jumpToFirst: true);
    });
    if (_searchController.text.isEmpty) {
      _resetBodySelection();
    } else if (_searchMatches.isNotEmpty) {
      _highlightCurrentMatch();
    }
  }

  void _toggleSearch() {
    if (_isSearching) {
      _closeSearch();
      return;
    }
    setState(() {
      _isSearching = true;
    });
    _bodyController.setHighlightQuery(_searchController.text);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
    if (_searchController.text.isNotEmpty) {
      final matches =
          _computeMatches(_searchController.text, _bodyController.text);
      setState(() {
        _applyMatches(matches, jumpToFirst: true);
      });
      if (_searchMatches.isNotEmpty) {
        _highlightCurrentMatch();
      }
    }
  }

  void _closeSearch() {
    setState(() {
      _isSearching = false;
      _applyMatches(const <int>[], jumpToFirst: true);
    });
    if (_searchController.text.isNotEmpty) {
      _searchController.clear();
    } else {
      _resetBodySelection();
    }
    _bodyController.setHighlightQuery('');
  }

  List<int> _computeMatches(String query, String text) {
    if (query.isEmpty) {
      return const <int>[];
    }
    final lowerQuery = query.toLowerCase();
    final lowerText = text.toLowerCase();
    final matches = <int>[];
    var start = 0;
    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        break;
      }
      matches.add(index);
      start = index + lowerQuery.length;
    }
    return matches;
  }

  void _applyMatches(List<int> matches, {required bool jumpToFirst}) {
    _searchMatches = matches;
    if (_searchMatches.isEmpty) {
      _currentMatchIndex = 0;
      return;
    }
    if (jumpToFirst || _currentMatchIndex >= _searchMatches.length) {
      _currentMatchIndex = 0;
    }
  }

  void _goToNextMatch() {
    if (_searchMatches.isEmpty) {
      return;
    }
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _searchMatches.length;
    });
    _highlightCurrentMatch();
    if (!_searchFocusNode.hasFocus) {
      _searchFocusNode.requestFocus();
    }
  }

  void _goToPreviousMatch() {
    if (_searchMatches.isEmpty) {
      return;
    }
    setState(() {
      final length = _searchMatches.length;
      _currentMatchIndex = (_currentMatchIndex - 1 + length) % length;
    });
    _highlightCurrentMatch();
    if (!_searchFocusNode.hasFocus) {
      _searchFocusNode.requestFocus();
    }
  }

  void _highlightCurrentMatch() {
    if (_searchMatches.isEmpty) {
      return;
    }
    final query = _searchController.text;
    if (query.isEmpty) {
      return;
    }
    final start = _searchMatches[_currentMatchIndex];
    final end = start + query.length;
    _bodyController.selection = TextSelection(baseOffset: start, extentOffset: end);
    _centerOnCurrentMatch();
  }

  void _resetBodySelection() {
    final length = _bodyController.text.length;
    _bodyController.selection = TextSelection.collapsed(offset: length);
  }

  void _centerOnCurrentMatch() {
    if (!_bodyScrollController.hasClients || _searchMatches.isEmpty || !mounted) {
      return;
    }
    final start = _searchMatches[_currentMatchIndex];
    if (start < 0 || start > _bodyController.text.length) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_bodyScrollController.hasClients || !mounted) {
        return;
      }
      final context = _bodyTextFieldKey.currentContext;
      if (context == null) {
        return;
      }
      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox == null) {
        return;
      }
      final viewportHeight = renderBox.size.height;
      if (viewportHeight <= 0) {
        return;
      }
      final text = _bodyController.text;
      final textStyle = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
      final direction = Directionality.of(context);
      final safeStart = start.clamp(0, text.length);
      final substring = text.substring(0, safeStart);
      final textPainter = TextPainter(
        text: TextSpan(text: substring, style: textStyle),
        textDirection: direction,
        textAlign: TextAlign.left,
        maxLines: null,
      )..layout(maxWidth: renderBox.size.width);
      final caretOffset = textPainter.height;
      final lineHeight = textPainter.preferredLineHeight > 0
          ? textPainter.preferredLineHeight
          : (textStyle.fontSize ?? 16);
      final targetOffset = caretOffset - (viewportHeight - lineHeight) / 2;
      final maxScroll = _bodyScrollController.position.maxScrollExtent;
      final minScroll = _bodyScrollController.position.minScrollExtent;
      final clamped =
          targetOffset.clamp(minScroll, maxScroll).toDouble();
      _bodyScrollController.animateTo(
        clamped,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    });
  }
}

class _HighlightingTextEditingController extends TextEditingController {
  _HighlightingTextEditingController({super.text});

  String _highlightQuery = '';
  static const _highlightColor = Color(0x80FFF176);

  void setHighlightQuery(String query) {
    if (_highlightQuery == query) {
      return;
    }
    _highlightQuery = query;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    bool withComposing = false,
  }) {
    final textValue = text;
    if (_highlightQuery.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final lowerText = textValue.toLowerCase();
    final lowerQuery = _highlightQuery.toLowerCase();
    if (!lowerText.contains(lowerQuery)) {
      return TextSpan(style: style, text: textValue);
    }

    final spans = <TextSpan>[];
    var start = 0;
    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: textValue.substring(start, index), style: style));
      }
      spans.add(
        TextSpan(
          text: textValue.substring(index, index + lowerQuery.length),
          style: style?.merge(
                const TextStyle(
                  backgroundColor: _highlightColor,
                ),
              ) ??
              const TextStyle(backgroundColor: _highlightColor),
        ),
      );
      start = index + lowerQuery.length;
    }
    if (start < textValue.length) {
      spans.add(TextSpan(text: textValue.substring(start), style: style));
    }

    return TextSpan(style: style, children: spans);
  }
}

