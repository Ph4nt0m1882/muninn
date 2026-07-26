import 'package:flutter/material.dart';
import 'package:re_highlight/styles/monokai-sublime.dart';

/// Un thème Monokai Sublime personnalisé pour ajouter de vrais styles de texte (gras, italique)
/// et rendre le rendu Markdown de l'éditeur plus "Fake Markdown" (similaire à VSCode).
final Map<String, TextStyle> customMonokaiTheme = {
  ...monokaiSublimeTheme,
  'strong': (monokaiSublimeTheme['strong'] ?? const TextStyle()).copyWith(
    fontWeight: FontWeight.bold,
    color: const Color(0xfff8f8f2), // True white/Monokai base instead of gray
  ),
  'emphasis': (monokaiSublimeTheme['emphasis'] ?? const TextStyle()).copyWith(
    fontStyle: FontStyle.italic,
    color: const Color(0xfff8f8f2), // True white/Monokai base instead of gray
  ),
  'code': (monokaiSublimeTheme['code'] ?? const TextStyle()).copyWith(
    backgroundColor: const Color(0xFF333333),
  ),
  'symbol': (monokaiSublimeTheme['symbol'] ?? const TextStyle()).copyWith(
    decoration: TextDecoration.underline,
  ),
};
