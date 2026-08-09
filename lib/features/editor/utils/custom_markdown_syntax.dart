import 'package:markdown/markdown.dart';

/// Syntaxe personnalisée pour intercepter `!![alt](src)`
/// et générer une balise HTML custom `<muninn-img src="..." alt="..."></muninn-img>`
class DoubleBangImageSyntax extends InlineSyntax {
  // Regex pour attraper !![alt](src)
  // Group 1: alt text
  // Group 2: src URL
  DoubleBangImageSyntax() : super(r'!!\[(.*?)\]\((.*?)\)');

  @override
  bool onMatch(InlineParser parser, Match match) {
    final alt = match[1] ?? '';
    final src = match[2] ?? '';

    // Générer un élément HTML custom
    final el = Element.empty('muninn-img');
    el.attributes['alt'] = alt;
    el.attributes['src'] = src;

    parser.addNode(el);
    return true;
  }
}

class WikiLinkSyntax extends InlineSyntax {
  WikiLinkSyntax() : super(r'\[\[([^\]]+)\]\]');

  @override
  bool onMatch(InlineParser parser, Match match) {
    final inner = match[1] ?? '';

    String file = inner;
    String header = '';
    String alias = inner;

    // Check for Alias (after |)
    final pipeIndex = inner.indexOf('|');
    if (pipeIndex != -1) {
      alias = inner.substring(pipeIndex + 1);
      file = inner.substring(0, pipeIndex);
    }

    // Check for Header (inside parenthesis)
    final RegExp fileHeaderRegex = RegExp(r'^([^(]+)\(([^)]+)\)$');
    final fhMatch = fileHeaderRegex.firstMatch(file);
    if (fhMatch != null) {
      file = fhMatch.group(1)!;
      header = fhMatch.group(2)!;
    }

    final el = Element.text('wiki-link', alias);
    el.attributes['target'] = file;
    if (header.isNotEmpty) {
      el.attributes['header'] = header;
    }
    parser.addNode(el);
    return true;
  }
}

class FootnoteRefSyntax extends InlineSyntax {
  FootnoteRefSyntax() : super(r'\[\^([^\]]+)\]');

  @override
  bool onMatch(InlineParser parser, Match match) {
    final id = match[1] ?? '';
    final el = Element.text('footnote-ref', id);
    el.attributes['id'] = id;
    parser.addNode(el);
    return true;
  }
}

class ContextLinkSyntax extends InlineSyntax {
  ContextLinkSyntax() : super(r'@\[([^\]]+)\]\(([^)]+)\)');

  @override
  bool onMatch(InlineParser parser, Match match) {
    final title = match[1] ?? '';
    final path = match[2] ?? '';

    final el = Element.empty('muninn-context-link');
    el.attributes['title'] = title;
    el.attributes['path'] = path;
    
    parser.addNode(el);
    return true;
  }
}

class LatexDisplaySyntax extends InlineSyntax {
  LatexDisplaySyntax() : super('');

  @override
  RegExp get pattern => RegExp(r'\$\$(.*?)\$\$', multiLine: true, dotAll: true);

  @override
  bool onMatch(InlineParser parser, Match match) {
    final el = Element.text('tex', match[1] ?? '');
    el.attributes['display'] = 'block';
    parser.addNode(el);
    return true;
  }
}

class LatexInlineSyntax extends InlineSyntax {
  LatexInlineSyntax() : super('');

  @override
  RegExp get pattern => RegExp(r'(?<!\\)\$(.*?)(?<!\\)\$', multiLine: true, dotAll: true);

  @override
  bool onMatch(InlineParser parser, Match match) {
    final el = Element.text('tex', match[1] ?? '');
    el.attributes['display'] = 'inline';
    parser.addNode(el);
    return true;
  }
}

class MuninnCheckboxSyntax extends InlineSyntax {
  static int checkboxId = 0;

  MuninnCheckboxSyntax() : super('');

  @override
  RegExp get pattern => RegExp(r'^\[([ xXvV\*])\]\s+');

  @override
  bool onMatch(InlineParser parser, Match match) {
    final state = (match[1] ?? '').toLowerCase();
    final el = Element.empty('muninn-checkbox');
    el.attributes['id'] = '${checkboxId++}';
    el.attributes['state'] = state;
    parser.addNode(el);
    return true;
  }
}

class FootnoteDefSyntax extends InlineSyntax {
  FootnoteDefSyntax() : super('');

  @override
  RegExp get pattern => RegExp(r'^\[\^([^\]]+)\]:\s*(.+)$', multiLine: true);

  @override
  bool onMatch(InlineParser parser, Match match) {
    final id = match[1] ?? '';
    final content = match[2] ?? '';
    final el = Element.text('footnote-def', content);
    el.attributes['id'] = id;
    parser.addNode(el);
    return true;
  }
}
