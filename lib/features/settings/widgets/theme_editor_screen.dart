import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:muninn/core/theme/theme.dart';
import 'package:muninn/core/theme/watermark_background.dart';

const List<String> availableSyntaxThemes = [
  'atom-one-dark',
  'atom-one-light',
  'darcula',
  'dracula',
  'github',
  'monokai',
  'monokai-sublime',
  'night-owl',
  'nord',
  'obsidian',
  'ocean',
  'solarized-dark',
  'solarized-light',
  'tomorrow',
  'tomorrow-night',
  'vs',
  'vs2015',
  'zenburn'
];

class ThemeEditorScreen extends StatefulWidget {
  final CrowStyle? initialTheme; // S'il est fourni, on le modifie directement

  const ThemeEditorScreen({super.key, this.initialTheme});

  @override
  State<ThemeEditorScreen> createState() => _ThemeEditorScreenState();
}

class _ThemeEditorScreenState extends State<ThemeEditorScreen> {
  late CrowStyle _currentTheme;
  late List<CrowStyle> _baseThemes;

  @override
  void initState() {
    super.initState();
    // Les thèmes de base pour le sélecteur (Builtin + Custom éventuellement)
    _baseThemes = BuiltinThemes.all;

    // Si on édite un thème existant, on l'utilise, sinon on part du thème par défaut
    _currentTheme = widget.initialTheme ?? BuiltinThemes.light;
  }

  void _onBaseThemeSelected(CrowStyle? baseTheme) {
    if (baseTheme != null) {
      setState(() {
        // Copie les propriétés du thème de base, mais on peut garder un ID unique plus tard
        _currentTheme = CrowStyle(
          id: widget.initialTheme?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
          name: '${baseTheme.name} (Copie)',
          ui: CrowStyleUI(
            background: baseTheme.ui.background,
            surface: baseTheme.ui.surface,
            surfaceHighlight: baseTheme.ui.surfaceHighlight,
            textPrimary: baseTheme.ui.textPrimary,
            textSecondary: baseTheme.ui.textSecondary,
            accent: baseTheme.ui.accent,
            brightness: baseTheme.ui.brightness,
            backgroundImage: baseTheme.ui.backgroundImage,
          ),
          render: baseTheme.render,
        );
      });
    }
  }

  void _updateUI({
    Color? background,
    Color? surface,
    Color? surfaceHighlight,
    Color? textPrimary,
    Color? textSecondary,
    Color? accent,
    Brightness? brightness,
    String? baseThemeSeed,
    String? contrastSeed,
    String? backgroundImage,
    double? backgroundImageOpacity,
    String? markdownTheme,
    String? codeTheme,
    Color? ravenColor,
    double? lineHeight,
    bool? titleSeparators,
  }) {
    setState(() {
      _currentTheme = CrowStyle(
        id: _currentTheme.id,
        name: _currentTheme.name,
        ui: CrowStyleUI(
          background: background ?? _currentTheme.ui.background,
          surface: surface ?? _currentTheme.ui.surface,
          surfaceHighlight: surfaceHighlight ?? _currentTheme.ui.surfaceHighlight,
          textPrimary: textPrimary ?? _currentTheme.ui.textPrimary,
          textSecondary: textSecondary ?? _currentTheme.ui.textSecondary,
          accent: accent ?? _currentTheme.ui.accent,
          brightness: brightness ?? _currentTheme.ui.brightness,
          baseThemeSeed: baseThemeSeed ?? _currentTheme.ui.baseThemeSeed,
          contrastSeed: contrastSeed ?? _currentTheme.ui.contrastSeed,
          backgroundImage: backgroundImage ?? _currentTheme.ui.backgroundImage,
          backgroundImageOpacity: backgroundImageOpacity ?? _currentTheme.ui.backgroundImageOpacity,
          markdownTheme: markdownTheme ?? _currentTheme.ui.markdownTheme,
          codeTheme: codeTheme ?? _currentTheme.ui.codeTheme,
          ravenColor: ravenColor ?? _currentTheme.ui.ravenColor,
          lineHeight: lineHeight ?? _currentTheme.ui.lineHeight,
        ),
        render: CrowStyleRender(
          elements: _currentTheme.render.elements,
          fullRender: _currentTheme.render.fullRender,
          blocCode: _currentTheme.render.blocCode,
          rawCss: _currentTheme.render.rawCss,
          titleSeparators: titleSeparators ?? _currentTheme.render.titleSeparators,
        ),
      );
    });
  }

  void _showColorPicker(BuildContext context, String title, Color currentColor, ValueChanged<Color> onColorChanged) {
    HSVColor pickerHsvColor = HSVColor.fromColor(currentColor);
    final TextEditingController hexController = TextEditingController(
      text: currentColor.value.toRadixString(16).substring(2).toUpperCase(),
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(title),
              content: SingleChildScrollView(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Carré de gradient à gauche (Saturation / Value)
                    SizedBox(
                      width: 250,
                      height: 250,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: ColorPickerArea(
                          pickerHsvColor,
                          (HSVColor color) {
                            setStateDialog(() {
                              pickerHsvColor = color;
                              hexController.text = color.toColor().value.toRadixString(16).substring(2).toUpperCase();
                            });
                          },
                          PaletteType.hsv,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Anneau chromatique à droite avec notre champ au centre
                    SizedBox(
                      width: 250,
                      height: 250,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: ColorPickerHueRing(
                              pickerHsvColor,
                              (HSVColor color) {
                                setStateDialog(() {
                                  pickerHsvColor = color;
                                  hexController.text = color.toColor().value.toRadixString(16).substring(2).toUpperCase();
                                });
                              },
                              strokeWidth: 20.0,
                            ),
                          ),
                          // Éléments centraux
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: pickerHsvColor.toColor(),
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                width: 100,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: TextField(
                                  controller: hexController,
                                  maxLength: 6,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  decoration: const InputDecoration(
                                    counterText: '',
                                    contentPadding: EdgeInsets.zero,
                                    border: InputBorder.none,
                                    prefixText: '#',
                                    prefixStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  onChanged: (value) {
                                    if (value.length == 6) {
                                      final newColor = Color(int.tryParse('FF$value', radix: 16) ?? pickerHsvColor.toColor().value);
                                      setStateDialog(() {
                                        pickerHsvColor = HSVColor.fromColor(newColor);
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Annuler'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
                  child: const Text('Valider'),
                  onPressed: () {
                    onColorChanged(pickerHsvColor.toColor());
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewTheme = ThemeManager.buildThemeData(_currentTheme);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Éditeur de Thème'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Split button pour la sauvegarde
          _buildSaveButton(),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Theme(
            data: previewTheme,
            child: ListView(
              padding: const EdgeInsets.all(24.0),
              children: [
                // Sélecteur de Thème de Base
                Card(
                  color: theme.colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Thème de départ', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        DropdownButton<CrowStyle>(
                          isExpanded: true,
                          value: _baseThemes.firstWhere(
                            (t) => t.id == _currentTheme.id,
                            orElse: () => _baseThemes.first,
                          ),
                          items: _baseThemes.map((t) {
                            return DropdownMenuItem<CrowStyle>(
                              value: t,
                              child: Text(t.name),
                            );
                          }).toList(),
                          onChanged: _onBaseThemeSelected,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Section : Image de fond
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Arrière-plan et Surfaces', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    // Switch de luminosité (Thème clair/sombre)
                    Row(
                      children: [
                        Icon(Icons.light_mode, size: 20, color: theme.colorScheme.onSurface),
                        Switch(
                          value: _currentTheme.ui.brightness == Brightness.dark,
                          onChanged: (isDark) {
                            _updateUI(brightness: isDark ? Brightness.dark : Brightness.light);
                          },
                        ),
                        Icon(Icons.dark_mode, size: 20, color: theme.colorScheme.onSurface),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  color: previewTheme.colorScheme.surface,
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Aperçu Image de Fond + Surfaces
                      Container(
                        height: 200,
                        color: previewTheme.scaffoldBackgroundColor,
                        child: Stack(
                          children: [
                            if (_currentTheme.ui.backgroundImage != null)
                              Positioned.fill(
                                child: WatermarkBackground(
                                  imagePath: _currentTheme.ui.backgroundImage!,
                                  inkColor: previewTheme.colorScheme.onSurface,
                                  opacity: _currentTheme.ui.backgroundImageOpacity,
                                ),
                              ),
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: previewTheme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('Surface Principale', style: previewTheme.textTheme.titleMedium),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        color: theme.colorScheme.surface,
                        padding: const EdgeInsets.all(16),
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () { 
                                _showColorPicker(context, 'Couleur de fond', _currentTheme.ui.background, (color) {
                                  _updateUI(background: color);
                                });
                              },
                              icon: const Icon(Icons.color_lens),
                              label: const Text('Fond'),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                _showColorPicker(context, 'Couleur de surface', _currentTheme.ui.surface, (color) {
                                  _updateUI(surface: color);
                                });
                              },
                              icon: const Icon(Icons.layers),
                              label: const Text('Surface'),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                _showColorPicker(context, 'Surface survolée', _currentTheme.ui.surfaceHighlight, (color) {
                                  _updateUI(surfaceHighlight: color);
                                });
                              },
                              icon: const Icon(Icons.highlight),
                              label: const Text('Survol'),
                            ),
                            Container(width: double.infinity, height: 0), // Ligne suivante pour l'image
                            ElevatedButton.icon(
                              onPressed: () async {
                                FilePickerResult? result = await FilePicker.pickFiles(
                                  type: FileType.custom,
                                  allowedExtensions: ['png', 'svg', 'webp', 'jpg', 'jpeg'],
                                );
                                if (result != null && result.files.single.path != null) {
                                  _updateUI(backgroundImage: result.files.single.path!);
                                }
                              },
                              icon: const Icon(Icons.image),
                              label: const Text('Image de fond'),
                            ),
                            if (_currentTheme.ui.backgroundImage != null) ...[
                              Column(
                                children: [
                                  const Text('Opacité du filigrane', style: TextStyle(fontSize: 12)),
                                  SizedBox(
                                    width: 150,
                                    height: 30,
                                    child: Slider(
                                      value: _currentTheme.ui.backgroundImageOpacity,
                                      min: 0.0,
                                      max: 1.0,
                                      divisions: 20,
                                      label: '${(_currentTheme.ui.backgroundImageOpacity * 100).round()}%',
                                      onChanged: (value) {
                                        _updateUI(backgroundImageOpacity: value);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Section : Typographie / Titres
                Text('Typographie et Couleurs', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Card(
                  color: previewTheme.scaffoldBackgroundColor,
                  child: Column(
                    children: [
                      // Aperçu Titres
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Titre Niveau 1 (H1)', style: previewTheme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('Titre Niveau 2 (H2)', style: previewTheme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('Titre Niveau 3 (H3)', style: previewTheme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            Text(
                              'Ceci est un exemple de paragraphe classique. Il utilise la couleur de texte principale (Text Primary).',
                              style: previewTheme.textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Ceci est un texte secondaire, souvent utilisé pour les dates, les notes ou les légendes.',
                              style: previewTheme.textTheme.bodyMedium?.copyWith(color: previewTheme.colorScheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Texte avec couleur d\'accentuation',
                              style: previewTheme.textTheme.bodyLarge?.copyWith(color: previewTheme.colorScheme.primary, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      // Paramètres
                      Container(
                        color: theme.colorScheme.surface,
                        padding: const EdgeInsets.all(16),
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          alignment: WrapAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                _showColorPicker(context, 'Texte Principal', _currentTheme.ui.textPrimary, (color) {
                                  _updateUI(textPrimary: color);
                                });
                              },
                              icon: const Icon(Icons.format_color_text),
                              label: const Text('Principal'),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                _showColorPicker(context, 'Texte Secondaire', _currentTheme.ui.textSecondary, (color) {
                                  _updateUI(textSecondary: color);
                                });
                              },
                              icon: const Icon(Icons.text_format),
                              label: const Text('Secondaire'),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                _showColorPicker(context, 'Accentuation', _currentTheme.ui.accent, (color) {
                                  _updateUI(accent: color);
                                });
                              },
                              icon: const Icon(Icons.brush),
                              label: const Text('Accentuation'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Section : Éditeur & Markdown
                Text('Éditeur & Markdown', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Card(
                  color: theme.colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 24,
                      runSpacing: 24,
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Thème Markdown
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Thème Markdown', style: TextStyle(fontSize: 12)),
                            const SizedBox(height: 4),
                            DropdownButton<String>(
                              value: _currentTheme.ui.markdownTheme,
                              items: availableSyntaxThemes.map((String themeName) {
                                return DropdownMenuItem<String>(
                                  value: themeName,
                                  child: Text(themeName),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) _updateUI(markdownTheme: newValue);
                              },
                            ),
                          ],
                        ),
                        // Thème Code
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Thème Code', style: TextStyle(fontSize: 12)),
                            const SizedBox(height: 4),
                            DropdownButton<String>(
                              value: _currentTheme.ui.codeTheme,
                              items: availableSyntaxThemes.map((String themeName) {
                                return DropdownMenuItem<String>(
                                  value: themeName,
                                  child: Text(themeName),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) _updateUI(codeTheme: newValue);
                              },
                            ),
                          ],
                        ),
                        // Corbeau
                        ElevatedButton.icon(
                          onPressed: () {
                            final isDark = Theme.of(context).brightness == Brightness.dark;
                            _showColorPicker(context, 'Couleur du Corbeau', _currentTheme.ui.ravenColor ?? (isDark ? Colors.white : Colors.black), (color) {
                              _updateUI(ravenColor: color);
                            });
                          },
                          icon: const Icon(Icons.animation),
                          label: const Text('Corbeau'),
                        ),
                        // Interligne
                        Column(
                          children: [
                            const Text('Interligne', style: TextStyle(fontSize: 12)),
                            SizedBox(
                              width: 150,
                              height: 30,
                              child: Slider(
                                value: _currentTheme.ui.lineHeight,
                                min: 1.0,
                                max: 2.5,
                                divisions: 15,
                                label: _currentTheme.ui.lineHeight.toStringAsFixed(1),
                                onChanged: (value) {
                                  _updateUI(lineHeight: value);
                                },
                              ),
                            ),
                          ],
                        ),
                        // Séparateurs Titres
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Lignes sous Titres 1&2', style: TextStyle(fontSize: 12)),
                            Switch(
                              value: _currentTheme.render.titleSeparators,
                              onChanged: (value) {
                                _updateUI(titleSeparators: value);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
      // Bouton en bas pour enregistrer (identique à celui d'en haut)
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        color: theme.colorScheme.surface,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return PopupMenuButton<String>(
      tooltip: 'Options de sauvegarde',
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.save, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Sauvegarder',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_drop_down, color: Colors.white),
          ],
        ),
      ),
      onSelected: (value) {
        if (value == 'global') {
          // TODO: Save to App Data
        } else if (value == 'wiki') {
          // TODO: Integrer au wiki
        } else if (value == 'export') {
          // TODO: Exporter (télécharger)
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'global',
          child: Text('Sauvegarder Globalement'),
        ),
        const PopupMenuItem<String>(
          value: 'wiki',
          child: Text('Intégrer au Wiki courant'),
        ),
        const PopupMenuItem<String>(
          value: 'export',
          child: Text('Exporter le .crowstyle'),
        ),
      ],
    );
  }
}
