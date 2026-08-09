import 'dart:io';
import 'package:flutter/material.dart';
import 'package:muninn/src/rust/api/search.dart' as rust_search;
import 'package:muninn/features/editor/services/editor_manager.dart';
import 'package:muninn/features/editor/widgets/markdown_renderer.dart';
import 'package:flutter/services.dart';

class SpotlightSearchDialog extends StatefulWidget {
  const SpotlightSearchDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => const SpotlightSearchDialog(),
    );
  }

  @override
  State<SpotlightSearchDialog> createState() => _SpotlightSearchDialogState();
}

class _SpotlightSearchDialogState extends State<SpotlightSearchDialog> {
  final TextEditingController _queryController = TextEditingController();
  final FocusNode _queryFocus = FocusNode();

  // 1: Brut, 2: Rendu, 3: Smart (inactif pour l'instant)
  int _selectedMode = 2;
  Map<String, List<rust_search.SearchResult>> _groupedResults = {};
  String? _selectedFilePath;
  rust_search.SearchResult? _selectedMatch;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _queryFocus.requestFocus();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _queryFocus.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _queryController.text;
    if (query.isEmpty) {
      setState(() {
        _groupedResults = {};
        _selectedFilePath = null;
        _selectedMatch = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      if (_selectedMode == 3) {
        setState(() {
          _groupedResults = {};
          _isSearching = false;
        });
        return;
      }

      final results = rust_search.searchDocuments(
        query: query,
        mode: _selectedMode,
      );

      if (mounted) {
        setState(() {
          _groupedResults = {};
          for (var r in results) {
            _groupedResults.putIfAbsent(r.filePath, () => []).add(r);
          }
          if (_groupedResults.isNotEmpty) {
            _selectedFilePath = _groupedResults.keys.first;
          } else {
            _selectedFilePath = null;
          }
          _selectedMatch = null;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _groupedResults = {};
        });
      }
      debugPrint("Erreur de recherche: $e");
    }
  }

  void _openMatch(rust_search.SearchResult match) {
    EditorManager.instance.teleportTo(
      match.filePath,
      match.rawStartOffset.toInt(),
      match.rawEndOffset.toInt(),
    );
    Navigator.of(context).pop();
  }

  void _openSelectedResult() {
    if (_selectedMatch != null) {
      _openMatch(_selectedMatch!);
    } else if (_selectedFilePath != null &&
        _groupedResults[_selectedFilePath!]!.isNotEmpty) {
      _openMatch(_groupedResults[_selectedFilePath!]!.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Center(
      child: Container(
        width: size.width * 0.8,
        height: size.height * 0.8,
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: theme.scaffoldBackgroundColor,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: theme.dividerColor)),
                  color: theme.colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search,
                      color: theme.iconTheme.color?.withValues(alpha: 0.5),
                      size: 28,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CallbackShortcuts(
                        bindings: {
                          const SingleActivator(
                            LogicalKeyboardKey.arrowDown,
                          ): () {
                            // Simple nav logic could be added here
                          },
                          const SingleActivator(
                            LogicalKeyboardKey.arrowUp,
                          ): () {
                            // Simple nav logic could be added here
                          },
                          const SingleActivator(LogicalKeyboardKey.enter):
                              _openSelectedResult,
                        },
                        child: TextField(
                          controller: _queryController,
                          focusNode: _queryFocus,
                          style: const TextStyle(fontSize: 20),
                          decoration: const InputDecoration(
                            hintText: 'Rechercher dans le wiki...',
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onChanged: (val) => _performSearch(),
                          onSubmitted: (_) => _openSelectedResult(),
                        ),
                      ),
                    ),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(
                          value: 1,
                          label: Text('Brut'),
                          icon: Icon(Icons.code, size: 16),
                        ),
                        ButtonSegment(
                          value: 2,
                          label: Text('Rendu'),
                          icon: Icon(Icons.preview, size: 16),
                        ),
                        ButtonSegment(
                          value: 3,
                          label: Text('Smart'),
                          icon: Icon(Icons.auto_awesome, size: 16),
                        ),
                      ],
                      selected: {_selectedMode},
                      onSelectionChanged: (Set<int> newSelection) {
                        setState(() {
                          _selectedMode = newSelection.first;
                        });
                        _performSearch();
                      },
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        textStyle: WidgetStateProperty.all(
                          const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Body
              Expanded(
                child: Row(
                  children: [
                    // Panneau gauche
                    Expanded(
                      flex: 3,
                      child: Container(
                        color: theme.colorScheme.surface.withValues(alpha: 0.5),
                        child: _selectedFilePath == null
                            ? Center(
                                child: Text(
                                  _isSearching
                                      ? 'Recherche en cours...'
                                      : 'Aucun r\u00E9sultat',
                                  style: TextStyle(color: theme.hintColor),
                                ),
                              )
                            : Material(
                                type: MaterialType.transparency,
                                child: _PreviewPane(
                                  filePath: _selectedFilePath!,
                                  matches:
                                      _groupedResults[_selectedFilePath!] ?? [],
                                  searchMode: _selectedMode,
                                ),
                              ),
                      ),
                    ),

                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: theme.dividerColor,
                    ),

                    // Panneau droit
                    Expanded(
                      flex: 2,
                      child: _groupedResults.isEmpty
                          ? Center(
                              child: Text(
                                _isSearching ? '' : '0 r�sultat',
                                style: TextStyle(color: theme.hintColor),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _groupedResults.length,
                              itemBuilder: (context, index) {
                                final filePath = _groupedResults.keys.elementAt(
                                  index,
                                );
                                final matches = _groupedResults[filePath]!;
                                final filename = filePath
                                    .split(RegExp(r'[/\\]'))
                                    .last;
                                final isSelectedFile =
                                    filePath == _selectedFilePath;

                                return _ResultAccordion(
                                  initiallyExpanded: isSelectedFile,
                                  onExpansionChanged: (expanded) {
                                    if (expanded) {
                                      setState(() {
                                        _selectedFilePath = filePath;
                                      });
                                    }
                                  },
                                  isSelectedFile: isSelectedFile,
                                  title: Text(
                                    filename,
                                    style: TextStyle(
                                      fontWeight: isSelectedFile
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSelectedFile
                                          ? theme.colorScheme.primary
                                          : null,
                                    ),
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${matches.length}',
                                      style: TextStyle(
                                        color: theme.colorScheme.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  children: matches.map((match) {
                                    final isSelectedMatch =
                                        match == _selectedMatch;
                                    return InkWell(
                                      onTap: () {
                                        setState(() {
                                          _selectedFilePath = filePath;
                                          _selectedMatch = match;
                                        });
                                      },
                                      onDoubleTap: () => _openMatch(match),
                                      child: Container(
                                        padding: const EdgeInsets.only(
                                          left: 32,
                                          right: 16,
                                          top: 8,
                                          bottom: 8,
                                        ),
                                        color: isSelectedMatch
                                            ? theme.colorScheme.secondary
                                                  .withValues(alpha: 0.1)
                                            : Colors.transparent,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              match.previewText.replaceAll(
                                                '\n',
                                                ' ',
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontFamily: 'Consolas',
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Icon(
                                                  match.isCaseMatch
                                                      ? Icons.text_fields
                                                      : Icons.text_fields,
                                                  size: 14,
                                                  color: match.isCaseMatch
                                                      ? Colors.green
                                                      : Colors.red,
                                                ),
                                                const SizedBox(width: 8),
                                                Icon(
                                                  match.isSyntaxClean
                                                      ? Icons
                                                            .check_circle_outline
                                                      : Icons.error_outline,
                                                  size: 14,
                                                  color: match.isSyntaxClean
                                                      ? Colors.green
                                                      : Colors.red,
                                                ),
                                                const SizedBox(width: 8),
                                                Icon(
                                                  match.isWholeWord
                                                      ? Icons.space_bar
                                                      : Icons.space_bar,
                                                  size: 14,
                                                  color: match.isWholeWord
                                                      ? Colors.green
                                                      : Colors.red,
                                                ),
                                                const Spacer(),
                                                Text(
                                                  'L${match.lineNumber}:C${match.columnNumber}',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: theme.hintColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultAccordion extends StatefulWidget {
  final Widget title;
  final Widget trailing;
  final List<Widget> children;
  final bool initiallyExpanded;
  final ValueChanged<bool> onExpansionChanged;
  final bool isSelectedFile;

  const _ResultAccordion({
    required this.title,
    required this.trailing,
    required this.children,
    this.initiallyExpanded = false,
    required this.onExpansionChanged,
    required this.isSelectedFile,
  });

  @override
  State<_ResultAccordion> createState() => _ResultAccordionState();
}

class _ResultAccordionState extends State<_ResultAccordion> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  void didUpdateWidget(_ResultAccordion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initiallyExpanded != oldWidget.initiallyExpanded) {
      _expanded = widget.initiallyExpanded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: widget.isSelectedFile
          ? theme.colorScheme.primary.withValues(alpha: 0.05)
          : Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _expanded = !_expanded;
              });
              widget.onExpansionChanged(_expanded);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(child: widget.title),
                  widget.trailing,
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(height: 0, width: double.infinity),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: widget.children,
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

class _PreviewPane extends StatelessWidget {
  final String filePath;
  final List<rust_search.SearchResult> matches;
  final int searchMode;

  const _PreviewPane({
    required this.filePath,
    required this.matches,
    required this.searchMode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<String>(
      future: File(filePath).readAsString(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final content = snapshot.data!;

        final sortedMatches = List<rust_search.SearchResult>.from(matches)
          ..sort((a, b) => a.rawStartOffset.compareTo(b.rawStartOffset));

        if (searchMode == 1) {
          List<TextSpan> spans = [];
          int currentOffset = 0;
          for (var match in sortedMatches) {
            int start = match.rawStartOffset.toInt();
            int end = match.rawEndOffset.toInt();
            if (start < currentOffset) continue;
            if (start > content.length) break;
            if (end > content.length) end = content.length;

            spans.add(TextSpan(text: content.substring(currentOffset, start)));
            spans.add(
              TextSpan(
                text: content.substring(start, end),
                style: TextStyle(
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.3,
                  ),
                  color: theme.colorScheme.onSurface,
                ),
              ),
            );
            currentOffset = end;
          }
          if (currentOffset < content.length) {
            spans.add(TextSpan(text: content.substring(currentOffset)));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  filePath,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.hintColor,
                    fontFamily: 'Consolas',
                  ),
                ),
                const SizedBox(height: 16),
                SelectableText.rich(
                  TextSpan(children: spans),
                  style: TextStyle(fontFamily: 'Consolas', fontSize: 13),
                ),
              ],
            ),
          );
        }

        // Render parsed markdown for Mode 2 (Rendu)
        String mdContent = content;
        int offsetAdjustment = 0;

        for (var match in sortedMatches) {
          int start = match.rawStartOffset.toInt() + offsetAdjustment;
          int end = match.rawEndOffset.toInt() + offsetAdjustment;

          // Basic protection against out-of-bounds in Dart String length
          if (start > mdContent.length) break;
          if (end > mdContent.length) end = mdContent.length;
          if (start < 0 || end < start) continue;

          final prefix = '<mark>';
          final suffix = '</mark>';

          mdContent =
              mdContent.substring(0, start) +
              prefix +
              mdContent.substring(start, end) +
              suffix +
              mdContent.substring(end);

          offsetAdjustment += prefix.length + suffix.length;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                filePath,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.hintColor,
                  fontFamily: 'Consolas',
                ),
              ),
              const SizedBox(height: 16),
              MarkdownRenderer(content: mdContent, filePath: filePath),
            ],
          ),
        );
      },
    );
  }
}
