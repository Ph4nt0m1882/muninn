import 'package:markdown/markdown.dart';

/// Syntaxe personnalisée pour intercepter `!![alt](src)`
/// et générer une balise HTML custom `<munnin-img src="..." alt="..."></munnin-img>`
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
    final el = Element.empty('munnin-img');
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
