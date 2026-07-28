import 'package:flutter/material.dart';

/// Représente les couleurs de l'interface utilisateur
class CrowStyleUI {
  final Color background;
  final Color surface;
  final Color surfaceHighlight;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final Brightness brightness;

  final String? baseThemeSeed; // "#000000"
  final String? contrastSeed; // "#6FC3DF"
  final String? backgroundImage; // Chemin vers l'image de fond (ex: SVG)
  final double backgroundImageOpacity; // Opacité de l'image de fond (défaut 0.05)
  
  // Paramètres avancés
  final String markdownTheme;
  final String codeTheme;
  final Color? ravenColor;
  final double lineHeight;

  const CrowStyleUI({
    required this.background,
    required this.surface,
    required this.surfaceHighlight,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.brightness,
    this.baseThemeSeed,
    this.contrastSeed,
    this.backgroundImage,
    this.backgroundImageOpacity = 0.05,
    this.markdownTheme = 'monokai-sublime',
    this.codeTheme = 'monokai-sublime',
    this.ravenColor,
    this.lineHeight = 1.5,
  });

  Map<String, dynamic> toJson() => {
        'background': background.toHex(),
        'surface': surface.toHex(),
        'surfaceHighlight': surfaceHighlight.toHex(),
        'textPrimary': textPrimary.toHex(),
        'textSecondary': textSecondary.toHex(),
        'accent': accent.toHex(),
        'brightness': brightness.name,
        'baseThemeSeed': baseThemeSeed,
        'contrastSeed': contrastSeed,
        'backgroundImage': backgroundImage,
        'backgroundImageOpacity': backgroundImageOpacity,
        'markdownTheme': markdownTheme,
        'codeTheme': codeTheme,
        'ravenColor': ravenColor?.toHex(),
        'lineHeight': lineHeight,
      };

  factory CrowStyleUI.fromJson(Map<String, dynamic> json) => CrowStyleUI(
        background: _ColorExt.fromHex(json['background']),
        surface: _ColorExt.fromHex(json['surface']),
        surfaceHighlight: _ColorExt.fromHex(json['surfaceHighlight']),
        textPrimary: _ColorExt.fromHex(json['textPrimary']),
        textSecondary: _ColorExt.fromHex(json['textSecondary']),
        accent: _ColorExt.fromHex(json['accent']),
        brightness: json['brightness'] == 'dark' ? Brightness.dark : Brightness.light,
        baseThemeSeed: json['baseThemeSeed'],
        contrastSeed: json['contrastSeed'],
        backgroundImage: json['backgroundImage'],
        backgroundImageOpacity: (json['backgroundImageOpacity'] as num?)?.toDouble() ?? 0.05,
        markdownTheme: json['markdownTheme'] ?? 'monokai-sublime',
        codeTheme: json['codeTheme'] ?? 'monokai-sublime',
        ravenColor: json['ravenColor'] != null ? _ColorExt.fromHex(json['ravenColor']) : null,
        lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.5,
      );
}

/// Représente les règles de rendu (Markdown -> HTML) et le CSS associé
class CrowStyleRender {
  final Map<String, dynamic>
  elements; // ex: {'title': {'H1': '<span class="...">', ...}}
  final bool fullRender;
  final Map<String, dynamic> blocCode;
  final String rawCss;
  final bool titleSeparators;

  const CrowStyleRender({
    this.elements = const {},
    this.fullRender = true,
    this.blocCode = const {},
    this.rawCss = '',
    this.titleSeparators = true,
  });

  Map<String, dynamic> toJson() => {
        'elements': elements,
        'fullRender': fullRender,
        'blocCode': blocCode,
        'rawCss': rawCss,
        'titleSeparators': titleSeparators,
      };

  factory CrowStyleRender.fromJson(Map<String, dynamic> json) => CrowStyleRender(
        elements: json['elements'] ?? const {},
        fullRender: json['fullRender'] ?? true,
        blocCode: json['blocCode'] ?? const {},
        rawCss: json['rawCss'] ?? '',
        titleSeparators: json['titleSeparators'] ?? true,
      );
}

/// La définition complète d'un thème CrowStyle
class CrowStyle {
  final String id;
  final String name;
  final String? model; // ex: 'dark_HC'
  final CrowStyleUI ui;
  final CrowStyleRender render;

  const CrowStyle({
    required this.id,
    required this.name,
    this.model,
    required this.ui,
    this.render = const CrowStyleRender(),
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'model': model,
        'ui': ui.toJson(),
        'render': render.toJson(),
      };

  factory CrowStyle.fromJson(Map<String, dynamic> json) => CrowStyle(
        id: json['id'],
        name: json['name'],
        model: json['model'],
        ui: CrowStyleUI.fromJson(json['ui']),
        render: json['render'] != null 
            ? CrowStyleRender.fromJson(json['render'])
            : const CrowStyleRender(),
      );
}

extension _ColorExt on Color {
  String toHex() => '#${value.toRadixString(16).padLeft(8, '0')}';

  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
