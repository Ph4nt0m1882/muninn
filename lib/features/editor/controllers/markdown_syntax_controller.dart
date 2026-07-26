import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:munnin/features/editor/services/editor_manager.dart';
import 'package:munnin/features/editor/services/link_preview_manager.dart';

class MarkdownSyntaxController extends TextEditingController {
  String? _hoveredUrl;

  String? _exitingUrl;

  MarkdownSyntaxController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final textStr = text;
    final currentFilePath = EditorManager.instance.activeFilePath ?? '';

    final theme = Theme.of(context);
    // Regex matches in order:
    // 1. WikiLinks: [[title]]
    // 2. Footnotes: [^id]
    // 3. Markdown links: [title](url)
    // 4. HTTP links: http(s)://...
    final regex = RegExp(
      r'\[\[([^\]]+)\]\]|\[\^([^\]]+)\]|\[([^\]]+)\]\(([^)]+)\)|https?:\/\/[^\s]+',
    );
    final matches = regex.allMatches(textStr);

    if (matches.isEmpty) {
      return TextSpan(text: textStr, style: style);
    }

    List<TextSpan> spans = [];
    int lastMatchEnd = 0;

    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(
          TextSpan(
            text: textStr.substring(lastMatchEnd, match.start),
            style: style,
          ),
        );
      }

      final fullMatch = match.group(0)!;
      final isWikiLink = match.group(1) != null;
      final isFootnote = match.group(2) != null;
      final isMarkdownLink = match.group(3) != null;

      String url;
      Color linkColor = Colors.blue;

      if (isWikiLink) {
        url = "wiki://${match.group(1)}";
        linkColor = theme.colorScheme.tertiary; // WikiLinks in tertiary color
      } else if (isFootnote) {
        url = "footnote://${match.group(2)}";
        linkColor = theme.colorScheme.secondary; // Footnotes in secondary color
      } else if (isMarkdownLink) {
        url = match.group(4)!;
        linkColor =
            theme.colorScheme.primary; // Markdown links in primary color
      } else {
        url = fullMatch;
        linkColor = theme.colorScheme.primary; // HTTP links in primary color
      }

      final isHovered = _hoveredUrl == url;

      spans.add(
        TextSpan(
          text: fullMatch,
          style: style?.copyWith(
            color: linkColor,
            decoration: isHovered
                ? TextDecoration.underline
                : TextDecoration.none,
          ),
          onEnter: (PointerEnterEvent event) {
            _exitingUrl = null;
            if (_hoveredUrl != url) {
              _hoveredUrl = url;
              notifyListeners(); // Rebuild to show underline
              LinkPreviewManager().show(
                context,
                url,
                event.position,
                currentFilePath,
              );
            }
          },
          onExit: (PointerExitEvent event) async {
            final exitingUrl = url;
            _exitingUrl = exitingUrl;

            await Future.delayed(const Duration(milliseconds: 10));

            if (_exitingUrl == exitingUrl && _hoveredUrl == exitingUrl) {
              _hoveredUrl = null;
              notifyListeners(); // Rebuild to hide underline
              LinkPreviewManager().hide();
            }
          },
        ),
      );

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < textStr.length) {
      spans.add(TextSpan(text: textStr.substring(lastMatchEnd), style: style));
    }

    return TextSpan(children: spans, style: style);
  }
}
