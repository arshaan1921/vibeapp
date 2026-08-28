import 'dart:async';
import 'package:flutter/material.dart';
import '../services/mention_service.dart';

class MentionInput extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final TextStyle? style;
  final InputDecoration? decoration;
  final FocusNode? focusNode;

  const MentionInput({
    super.key,
    required this.controller,
    this.hintText = "",
    this.maxLines = 1,
    this.onChanged,
    this.style,
    this.decoration,
    this.focusNode,
  });

  @override
  State<MentionInput> createState() => _MentionInputState();
}

class _MentionInputState extends State<MentionInput> {
  List<Map<String, dynamic>> _suggestions = [];
  bool _showSuggestions = false;
  Timer? _debounce;
  String _currentQuery = "";
  int _mentionStartIndex = -1;

  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (widget.focusNode == null) _focusNode.dispose();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    final selection = widget.controller.selection;

    if (!selection.isValid || selection.isCollapsed == false) {
      _hideSuggestions();
      return;
    }

    final cursorPosition = selection.baseOffset;
    if (cursorPosition <= 0) {
      _hideSuggestions();
      return;
    }

    // Look back for '@'
    final textBeforeCursor = text.substring(0, cursorPosition);
    final lastAtIndex = textBeforeCursor.lastIndexOf('@');

    if (lastAtIndex != -1) {
      // Check if there's a space between '@' and cursor
      final queryCandidate = textBeforeCursor.substring(lastAtIndex + 1);
      if (!queryCandidate.contains(' ')) {
        _currentQuery = queryCandidate;
        _mentionStartIndex = lastAtIndex;
        _onSearchChanged(_currentQuery);
        return;
      }
    }

    _hideSuggestions();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (query.isEmpty) {
        // Show recent or common users? For now just hide if empty @
        setState(() {
          _suggestions = [];
          _showSuggestions = false;
        });
        return;
      }

      final results = await MentionService.searchUsers(query);
      if (mounted) {
        setState(() {
          _suggestions = results;
          _showSuggestions = results.isNotEmpty;
        });
      }
    });
  }

  void _hideSuggestions() {
    if (_showSuggestions) {
      setState(() {
        _showSuggestions = false;
        _suggestions = [];
      });
    }
  }

  void _selectUser(String username) {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    final cursorPosition = selection.baseOffset;

    final newText = text.replaceRange(
      _mentionStartIndex,
      cursorPosition,
      "@$username ",
    );

    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: _mentionStartIndex + username.length + 2,
      ),
    );

    _hideSuggestions();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_showSuggestions)
          Container(
            constraints: const BoxConstraints(maxHeight: 160),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _suggestions.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final user = _suggestions[index];
                return ListTile(
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundImage: (user['avatar_url'] != null && user['avatar_url'] != '') 
                        ? NetworkImage(user['avatar_url']) 
                        : null,
                    child: (user['avatar_url'] == null || user['avatar_url'] == '') 
                        ? const Icon(Icons.person, size: 16) 
                        : null,
                  ),
                  title: Text(
                    user['username'] ?? "User",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  onTap: () => _selectUser(user['username']),
                );
              },
            ),
          ),
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          maxLines: widget.maxLines,
          onChanged: widget.onChanged,
          style: widget.style,
          decoration: widget.decoration ?? InputDecoration(
            hintText: widget.hintText,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
