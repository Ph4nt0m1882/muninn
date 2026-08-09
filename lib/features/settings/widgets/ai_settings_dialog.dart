import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:munnin/features/settings/widgets/api_key_dialog.dart';
import 'package:munnin/features/settings/services/settings_manager.dart';
import 'package:munnin/core/services/ai_service.dart';
import 'package:munnin/features/editor/services/editor_manager.dart';
import 'package:munnin/core/utils/uv_installer.dart';
import 'package:munnin/core/services/mcp_service.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

class AiSettingsDialog extends StatefulWidget {
  const AiSettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const AiSettingsDialog(),
    );
  }

  @override
  State<AiSettingsDialog> createState() => _AiSettingsDialogState();
}

class _AiSettingsDialogState extends State<AiSettingsDialog> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 1000,
        height: 700,
        child: Row(
          children: [
            // Menu latéral
            Container(
              width: 250,
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      children: [
                        Icon(Icons.smart_toy, color: theme.colorScheme.primary),
                        const SizedBox(width: 12),
                        Text(
                          'Gestion IA',
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  _buildNavItem(0, 'Général', LucideIcons.settings),
                  _buildNavItem(1, 'Règles (Rules)', LucideIcons.scale),
                  _buildNavItem(2, 'Commandes', LucideIcons.terminal),
                  _buildNavItem(3, 'MCPs', LucideIcons.blocks),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(LucideIcons.arrow_left),
                      label: const Text('Fermer'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  )
                ],
              ),
            ),
            // Contenu principal
            Expanded(
              child: Container(
                color: theme.colorScheme.surface,
                child: _buildContent(theme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, String title, IconData icon) {
    final theme = Theme.of(context);
    final isSelected = _selectedIndex == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                width: 4,
              ),
            ),
            color: isSelected ? theme.colorScheme.primary.withOpacity(0.1) : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                size: 20,
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    switch (_selectedIndex) {
      case 0:
        return _buildGeneralTab();
      case 1:
        return _buildFileTab(
          title: 'Règles (Rules)',
          description: 'Les règles définissent le comportement global de l\'IA (ton, format, etc.).',
          subDirectory: 'rules',
          isFileBased: true,
        );
      case 2:
        return _buildFileTab(
          title: 'Commandes Slash',
          description: 'Les commandes slash permettent de déclencher des workflows complexes (ex: /create-rules).',
          subDirectory: 'commands',
          isFileBased: false,
        );
      case 3:
        return _buildFileTab(
          title: 'Serveurs MCP',
          description: 'Model Context Protocol: Connecter l\'IA à des outils locaux ou distants.',
          subDirectory: 'mcp',
          isFileBased: false,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildGeneralTab() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Configuration de l\'API', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          const Text('Gérez votre clé API Gemini ici. Vous pouvez également configurer le modèle par défaut.'),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              ApiKeyDialog.show(context);
            },
            icon: const Icon(LucideIcons.key),
            label: const Text('Ouvrir la configuration de la clé API'),
          )
        ],
      ),
    );
  }

  Widget _buildFileTab({
    required String title,
    required String description,
    required String subDirectory,
    required bool isFileBased, // True for rules (files), False for commands/mcp (folders)
  }) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (subDirectory == 'mcp') ...[
                    OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final globalDir = Directory(p.join(getGlobalMunninDir(), '.munnin', 'mcp'));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Réinstallation de Munnin Tools en cours...')));
                          McpService.instance.stopAll();
                          await UvInstaller.installMunninTools(globalDir.path);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Munnin Tools réinstallé avec succès !')));
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: \$e')));
                        }
                      },
                      icon: const Icon(LucideIcons.refresh_cw, size: 16),
                      label: const Text('Réinstaller Munnin Tools'),
                    ),
                    const SizedBox(width: 8),
                  ],
                  PopupMenuButton<String>(
                    tooltip: 'Créer',
                    child: ElevatedButton.icon(
                      onPressed: null, // Let PopupMenuButton handle it
                      icon: const Icon(LucideIcons.plus),
                      label: const Text('Créer'),
                    ),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'manual',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Manuellement'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'ai',
                        child: Row(
                          children: [
                            Icon(LucideIcons.sparkles, size: 18),
                            SizedBox(width: 8),
                            Text('Générer avec l\'IA'),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'manual') {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Création manuelle bientôt disponible.')));
                      } else if (value == 'ai') {
                        Navigator.of(context).pop(); // Ferme le dialogue
                        // TODO: call the chat panel with specific command based on isFileBased and subDirectory
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ouvrez le panneau de discussion et tapez votre demande.')));
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(description, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: _buildToggleSwitch(),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _buildFileList(
                    path: _isGlobalSelected 
                        ? p.join(getGlobalMunninDir(), '.munnin', subDirectory)
                        : EditorManager.instance.wikiRoot != null 
                            ? p.join(EditorManager.instance.wikiRoot!, '.munnin', subDirectory)
                            : null,
                    isFileBased: isFileBased,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  bool _isGlobalSelected = true;

  Widget _buildToggleSwitch() {
    final theme = Theme.of(context);
    final hasWiki = EditorManager.instance.wikiRoot != null;
    
    // Ensure we don't stay on Wiki if it's closed
    if (!hasWiki && !_isGlobalSelected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _isGlobalSelected = true);
      });
    }

    return Container(
      width: 300,
      height: 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment: _isGlobalSelected ? Alignment.centerLeft : Alignment.centerRight,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: Container(
              width: 150,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _isGlobalSelected = true);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Text(
                      'Global',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: _isGlobalSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: hasWiki ? () {
                    setState(() => _isGlobalSelected = false);
                  } : null,
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Text(
                      'Wiki',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: hasWiki 
                            ? (!_isGlobalSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant)
                            : theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFileList({required String? path, required bool isFileBased}) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.surfaceContainerHighest),
        borderRadius: BorderRadius.circular(8),
      ),
      child: path == null 
        ? const Center(child: Text("Wiki non ouvert"))
        : FutureBuilder<List<FileSystemEntity>>(
            future: _loadEntities(path, isFileBased),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const Center(child: Text("Erreur de chargement."));
              }
              final entities = snapshot.data ?? [];
              if (entities.isEmpty) {
                return const Center(child: Text("Aucun élément trouvé.", style: TextStyle(fontStyle: FontStyle.italic)));
              }
              
              return ListView.separated(
                padding: const EdgeInsets.all(8),
                itemCount: entities.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final entity = entities[index];
                  final name = p.basename(entity.path);
                  return ListTile(
                    leading: Icon(isFileBased ? LucideIcons.file_text : LucideIcons.folder, size: 20),
                    title: Text(name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          tooltip: 'Ouvrir',
                          onPressed: () {
                            if (isFileBased) {
                              EditorManager.instance.openFile(entity.path);
                              Navigator.of(context).pop();
                            } else {
                              final promptFile = p.join(entity.path, 'prompt.md');
                              if (File(promptFile).existsSync()) {
                                EditorManager.instance.openFile(promptFile);
                                Navigator.of(context).pop();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fichier prompt.md introuvable.")));
                              }
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.trash_2, size: 18, color: Colors.red),
                          tooltip: 'Supprimer',
                          onPressed: () async {
                            // Suppression (sans confirmation pour simplifier pour l'instant)
                            McpService.instance.stopAll();
                            if (await FileSystemEntity.isDirectory(entity.path)) {
                              await Directory(entity.path).delete(recursive: true);
                            } else {
                              await File(entity.path).delete();
                            }
                            setState(() {}); // Rafraîchit l'interface
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
    );
  }

  Future<List<FileSystemEntity>> _loadEntities(String path, bool isFileBased) async {
    final dir = Directory(path);
    if (!await dir.exists()) return [];
    
    final entities = await dir.list().toList();
    List<FileSystemEntity> filtered = [];
    
    for (var entity in entities) {
      if (isFileBased) {
        if (await FileSystemEntity.isFile(entity.path) && entity.path.endsWith('.md')) {
          filtered.add(entity);
        }
      } else {
        if (await FileSystemEntity.isDirectory(entity.path)) {
          filtered.add(entity);
        }
      }
    }
    
    filtered.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
    return filtered;
  }
}
