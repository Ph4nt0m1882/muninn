import 'package:flutter/material.dart';
import 'package:re_highlight/styles/all.dart';

/// Récupère un thème de coloration syntaxique par son nom.
Map<String, TextStyle> getSyntaxTheme(String themeName) {
  return builtinAllThemes[themeName] ?? builtinAllThemes['monokai-sublime']!;
}

/// Applique des styles personnalisés (gras, italique) au-dessus d'un thème de base
/// pour rendre le rendu Markdown de l'éditeur plus "Fake Markdown" (similaire à VSCode).
Map<String, TextStyle> getCustomMarkdownTheme(String themeName) {
  final baseTheme = getSyntaxTheme(themeName);
  
  return {
    ...baseTheme,
    'strong': (baseTheme['strong'] ?? const TextStyle()).copyWith(
      fontWeight: FontWeight.bold,
      color: const Color(0xfff8f8f2), // Ou une autre couleur par défaut
    ),
    'emphasis': (baseTheme['emphasis'] ?? const TextStyle()).copyWith(
      fontStyle: FontStyle.italic,
      color: const Color(0xfff8f8f2),
    ),
    'code': (baseTheme['code'] ?? const TextStyle()).copyWith(
      backgroundColor: const Color(0xFF333333),
    ),
    'symbol': (baseTheme['symbol'] ?? const TextStyle()).copyWith(
      decoration: TextDecoration.underline,
    ),
  };
}
