import 'package:flutter/material.dart';
import 'package:muninn/features/editor/services/editor_manager.dart';
import 'package:muninn/src/rust/api/fs.dart' as rust_fs;
import 'package:muninn/src/rust/api/models.dart';
import 'package:muninn/core/utils/logger.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_writer/yaml_writer.dart';
import 'package:muninn/features/settings/services/settings_manager.dart';

class WikiSettingsScreen extends StatefulWidget {
  const WikiSettingsScreen({super.key});

  @override
  State<WikiSettingsScreen> createState() => _WikiSettingsScreenState();
}

class _WikiSettingsScreenState extends State<WikiSettingsScreen> {
  bool _isLoading = true;
  CrowFile? _crowFile;

  // Metadata
  final TextEditingController _titleController = TextEditingController();

  // Settings map
  Map<String, dynamic> _settingsMap = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final wikiRoot = EditorManager.instance.wikiRoot;
    if (wikiRoot == null) return;

    try {
      final file = await rust_fs.readAnchor(rootPath: wikiRoot);

      // Parse YAML settings
      Map<String, dynamic> parsedSettings = {};
      try {
        if (file.settings.trim().isNotEmpty) {
          final doc = loadYaml(file.settings);
          if (doc is YamlMap) {
            // Convert to a modifiable map
            parsedSettings = Map<String, dynamic>.from(doc);
          }
        }
      } catch (e) {
        AppLogger.e("Erreur de parsing YAML : $e");
      }

      setState(() {
        _crowFile = file;
        _titleController.text = file.metadata.title;
        _settingsMap = parsedSettings;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.e("Erreur de chargement des paramètres : $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    if (_crowFile == null) return;
    final wikiRoot = EditorManager.instance.wikiRoot;
    if (wikiRoot == null) return;

    try {
      // Serialize settings map to YAML
      final writer = YamlWriter();
      final newYamlString = _settingsMap.isEmpty
          ? ""
          : writer.write(_settingsMap);

      final updatedCrowFile = CrowFile(
        metadata: CrowMetadata(
          title: _titleController.text,
          version: _crowFile!.metadata.version,
          createdAt: _crowFile!.metadata.createdAt,
          updatedAt: _crowFile!.metadata.updatedAt,
        ),
        settings: newYamlString,
        modules: _crowFile!.modules,
      );

      await rust_fs.writeAnchor(rootPath: wikiRoot, crowFile: updatedCrowFile);
      SettingsManager.instance.updateSettings(newYamlString);

      setState(() {
        _crowFile = updatedCrowFile;
      });

      AppLogger.i("Paramètres sauvegardés avec succès !");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paramètres sauvegardés !')),
        );
      }
    } catch (e) {
      AppLogger.e("Erreur lors de la sauvegarde : $e");
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _updateSetting(String key, dynamic value) {
    setState(() {
      _settingsMap[key] = value;
    });
  }

  dynamic _getSetting(String key, dynamic defaultValue) {
    return _settingsMap[key] ?? defaultValue;
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 16),
      child: Text(
        title,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTextFieldSetting(
    String label,
    String key,
    String defaultValue, {
    String? helperText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (helperText != null) ...[
            const SizedBox(height: 4),
            Text(
              helperText,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
          const SizedBox(height: 8),
          TextFormField(
            initialValue: _getSetting(key, defaultValue).toString(),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            onChanged: (val) => _updateSetting(key, val),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchSetting(
    String label,
    String key,
    bool defaultValue, {
    String? helperText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (helperText != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    helperText,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: _getSetting(key, defaultValue) as bool,
            onChanged: (val) => _updateSetting(key, val),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_crowFile == null) {
      return const Center(child: Text("Impossible de charger les paramètres."));
    }

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Row(
        children: [
          // Left Sidebar (Categories)
          Container(
            width: 250,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    "PARAMÈTRES",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline, size: 20),
                  title: const Text("Général"),
                  selected: true,
                  selectedTileColor: theme.colorScheme.primary.withValues(
                    alpha: 0.1,
                  ),
                  onTap: () {},
                ),
              ],
            ),
          ),

          // Main Settings Area
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: theme.scaffoldBackgroundColor,
                  elevation: 0,
                  title: Text(
                    "Paramètres du Wiki",
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 16.0),
                      child: ElevatedButton.icon(
                        onPressed: _saveSettings,
                        icon: const Icon(Icons.save, size: 18),
                        label: const Text("Sauvegarder"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader("Métadonnées", theme),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Titre du Wiki",
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _titleController,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          "Version du moteur: ${_crowFile!.metadata.version}",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey,
                          ),
                        ),

                        const Divider(height: 48),

                        _buildSectionHeader("Éditeur (YAML)", theme),
                        _buildSwitchSetting(
                          "Sauvegarde Automatique",
                          "editor.autoSave",
                          true,
                          helperText:
                              "Sauvegarde les fichiers automatiquement lors des modifications.",
                        ),
                        _buildSwitchSetting(
                          "Minimap",
                          "editor.minimap.enabled",
                          false,
                          helperText:
                              "Affiche la minimap sur le côté de l'éditeur.",
                        ),

                        const Divider(height: 48),

                        _buildSectionHeader("Apparence", theme),
                        _buildTextFieldSetting(
                          "Thème principal",
                          "appearance.theme",
                          "dark",
                          helperText:
                              "Définit le thème global (light, dark, system).",
                        ),

                        const SizedBox(height: 60),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
