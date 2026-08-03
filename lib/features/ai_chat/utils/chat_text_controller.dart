import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

class ChatTextController extends TextEditingController {
  ChatTextController({super.text});

  @override
  set value(TextEditingValue newValue) {
    final oldText = text;
    // Updated regex to handle parentheses inside the path by looking for a boundary after the closing parenthesis
    final exp = RegExp(r'@\[([^\]]+)\]\((.*?)\)(?=[\s\.,;!?]|$)');
    
    if (newValue.text.length < oldText.length) {
      final diff = oldText.length - newValue.text.length;
      final cursor = newValue.selection.baseOffset;
      if (cursor >= 0 && cursor + diff <= oldText.length) {
        int deleteStart = cursor;
        int deleteEnd = cursor + diff;
        bool modified = false;
        
        for (final match in exp.allMatches(oldText)) {
          if (deleteStart < match.end && deleteEnd > match.start) {
            if (match.start < deleteStart) deleteStart = match.start;
            if (match.end > deleteEnd) deleteEnd = match.end;
            modified = true;
          }
        }
        
        if (modified) {
          final adjustedText = oldText.substring(0, deleteStart) + oldText.substring(deleteEnd);
          super.value = TextEditingValue(
            text: adjustedText,
            selection: TextSelection.collapsed(offset: deleteStart),
          );
          return;
        }
      }
    } else if (newValue.text.length > oldText.length) {
      final diff = newValue.text.length - oldText.length;
      final cursor = newValue.selection.baseOffset;
      if (cursor - diff >= 0) {
        final insertPos = cursor - diff;
        for (final match in exp.allMatches(oldText)) {
          if (insertPos > match.start && insertPos < match.end) {
            // Reject insertion inside pill
            super.value = TextEditingValue(
              text: oldText,
              selection: TextSelection.collapsed(offset: match.end),
            );
            return;
          }
        }
      }
    } else if (newValue.selection != selection) {
      final cursor = newValue.selection.baseOffset;
      if (cursor >= 0 && newValue.selection.isCollapsed) {
        for (final match in exp.allMatches(oldText)) {
          if (cursor > match.start && cursor < match.end) {
            // Snap cursor to end of pill
            super.value = newValue.copyWith(
              selection: TextSelection.collapsed(offset: match.end),
            );
            return;
          }
        }
      }
    }
    
    super.value = newValue;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final List<InlineSpan> children = [];
    final textStr = text;
    final RegExp exp = RegExp(r'@\[([^\]]+)\]\((.*?)\)(?=[\s\.,;!?]|$)');
    int lastMatchEnd = 0;
    
    final theme = Theme.of(context);
    final hiddenStyle = style?.copyWith(color: Colors.transparent, fontSize: 0.1);

    for (final match in exp.allMatches(textStr)) {
      if (match.start > lastMatchEnd) {
        children.add(TextSpan(
          text: textStr.substring(lastMatchEnd, match.start),
          style: style,
        ));
      }

      final title = match.group(1) ?? 'Fichier';
      
      children.add(
        TextSpan(
          children: [
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.file_text,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            TextSpan(
              text: textStr.substring(match.start, match.end),
              style: hiddenStyle,
            ),
          ],
        ),
      );

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < textStr.length) {
      children.add(TextSpan(
        text: textStr.substring(lastMatchEnd),
        style: style,
      ));
    }

    return TextSpan(style: style, children: children);
  }
}
