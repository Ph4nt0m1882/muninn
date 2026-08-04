import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:munnin/core/utils/logger.dart';
import 'package:munnin/features/editor/editor.dart';
import 'package:munnin/features/explorer/models/explorer_node.dart';
import 'package:munnin/features/explorer/widgets/explorer_item.dart';
import 'package:munnin/features/editor/services/editor_manager.dart';
import 'package:munnin/features/editor/models/file_metadata.dart';
import 'package:munnin/src/rust/api/fs.dart' as rust_fs;
import 'package:munnin/src/rust/api/models.dart';

class FileExplorer extends StatefulWidget {
  final String rootPath;
  final ValueChanged<String>? onFileSelected;

  const FileExplorer({super.key, required this.rootPath, this.onFileSelected});

  @override
  State<FileExplorer> createState() => FileExplorerState();
}

class FileExplorerState extends State<FileExplorer> {
  // Map stockant l'état d'expansion des dossiers
  final Map<String, bool> _expandedState = {};

  // Chemin du nœud (dossier ou fichier) actuellement sélectionné
  String? _selectedNodePath;

  // Liste "à plat" des entités visibles (pour ListView performant)
  List<ExplorerNode> _visibleNodes = [];

  @override
  void initState() {
    super.initState();
    loadTree();
  }

  @override
  void didUpdateWidget(covariant FileExplorer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rootPath != widget.rootPath) {
      _expandedState.clear();
      _selectedNodePath = null;
      loadTree();
    }
  }

  Future<void> loadTree() async {
    try {
      final tree = await rust_fs.scanDirectory(rootPath: widget.rootPath);
      final newNodes = _flattenTree(tree, 0, widget.rootPath);
      if (mounted) {
        setState(() {
          _visibleNodes = newNodes;
        });
      }
    } catch (e) {
      AppLogger.e("Erreur loadTree: $e");
    }
  }

  List<ExplorerNode> _flattenTree(TreeNode node, int depth, String rootPath) {
    List<ExplorerNode> nodes = [];

    for (var child in node.children) {
      final absPath = '$rootPath${Platform.pathSeparator}${child.path}'
          .replaceAll('/', Platform.pathSeparator);
      final isExpanded = _expandedState[absPath] ?? false;

      nodes.add(
        ExplorerNode(
          entity: child.isDirectory ? Directory(absPath) : File(absPath),
          depth: depth,
          isExpanded: isExpanded,
          isDirectory: child.isDirectory,
        ),
      );

      if (child.isDirectory && isExpanded) {
        nodes.addAll(_flattenTree(child, depth + 1, rootPath));
      }
    }
    return nodes;
  }

  void _toggleDirectory(ExplorerNode node) {
    setState(() {
      final isNowExpanded = !node.isExpanded;
      _expandedState[node.entity.path] = isNowExpanded;

      if (isNowExpanded) {
        _selectedNodePath = node.entity.path;
      } else {
        // Si on ferme le dossier, on annule la sélection (ou on sélectionne son parent si on voulait être précis, mais null c'est plus simple)
        if (_selectedNodePath == node.entity.path) {
          _selectedNodePath = null;
        }
      }
    });
    // On recharge l'arbre plat
    loadTree();
  }

  void _collapseAll() {
    setState(() {
      _expandedState.clear();
    });
    loadTree();
  }

  Future<void> _createNewEntity(bool isDirectory) async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isDirectory ? 'Nouveau dossier' : 'Nouveau fichier'),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            hintText: isDirectory ? 'Nom du dossier' : 'Nom du fichier',
          ),
          autofocus: true,
          onSubmitted: (val) => Navigator.pop(context, val),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, nameController.text),
            child: const Text('Créer'),
          ),
        ],
      ),
    );

    if (name == null || name.trim().isEmpty) return;

    String finalName = name.trim();
    if (!isDirectory && !finalName.toLowerCase().endsWith('.md')) {
      finalName = '$finalName.md';
    }

    // Déterminer le parent
    String parentPath = widget.rootPath;
    if (_selectedNodePath != null) {
      final selectedEntity =
          FileSystemEntity.isDirectorySync(_selectedNodePath!)
          ? Directory(_selectedNodePath!)
          : File(_selectedNodePath!).parent;
      parentPath = selectedEntity.path;
    }

    final entityPath = '$parentPath${Platform.pathSeparator}$finalName';

    try {
      if (isDirectory) {
        await rust_fs.createDirectory(path: entityPath);
        // Ouvre et sélectionne le nouveau dossier
        _expandedState[entityPath] = true;
        _selectedNodePath = entityPath;
      } else {
        await rust_fs.createFile(path: entityPath);
        if (entityPath.endsWith('.md')) {
          final defaultTitle = finalName.replaceAll('.md', '');
          final defaultMetadata = FileMetadata.defaultMeta(defaultTitle);
          final yamlStr = defaultMetadata.toYamlString();
          await rust_fs.writeFileAsString(
            path: entityPath,
            content: '---\n$yamlStr\n---\n\n',
          );
        }
      }
      loadTree();
    } catch (e) {
      AppLogger.e("Erreur lors de la création: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showContextMenu(Offset position, ExplorerNode node) {
    setState(() {
      _selectedNodePath = node.entity.path;
    });

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem(
          value: 'rename',
          child: Row(
            children: const [
              Icon(Icons.edit, size: 18),
              SizedBox(width: 8),
              Text('Renommer'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(
                Icons.delete,
                size: 18,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 8),
              Text(
                'Supprimer',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'rename') {
        _renameNode(node);
      } else if (value == 'delete') {
        _deleteNode(node);
      }
    });
  }

  Future<void> _renameNode(ExplorerNode node) async {
    final oldName = node.entity.path.split(RegExp(r'[/\\]')).last;
    final isMd = !node.isDirectory && oldName.toLowerCase().endsWith('.md');
    final displayName = isMd
        ? oldName.substring(0, oldName.length - 3)
        : oldName;

    final nameController = TextEditingController(text: displayName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renommer'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          onSubmitted: (val) => Navigator.pop(context, val),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, nameController.text),
            child: const Text('Renommer'),
          ),
        ],
      ),
    );

    if (newName == null ||
        newName.trim().isEmpty ||
        newName.trim() == displayName) {
      return;
    }

    String finalName = newName.trim();
    if (!node.isDirectory && !finalName.toLowerCase().endsWith('.md')) {
      finalName = '$finalName.md';
    }

    final parentPath = File(node.entity.path).parent.path;
    final newPath = '$parentPath${Platform.pathSeparator}$finalName';

    try {
      await rust_fs.renameItem(oldPath: node.entity.path, newPath: newPath);
      // Mise à jour de l'éditeur si ouvert
      EditorManager.instance.renameOpenedFile(node.entity.path, newPath);

      if (_selectedNodePath == node.entity.path) {
        _selectedNodePath = newPath;
      }
      loadTree();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  Future<void> _deleteNode(ExplorerNode node) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer'),
        content: Text(
          'Voulez-vous vraiment supprimer "${node.entity.path.split(RegExp(r'[/\\]')).last}" ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await rust_fs.deleteItem(path: node.entity.path);
      EditorManager.instance.closeFile(node.entity.path);
      if (_selectedNodePath == node.entity.path) _selectedNodePath = null;
      loadTree();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  Future<void> _handleDrop(
    String sourcePath,
    String targetDirectoryPath,
  ) async {
    final sourceName = sourcePath.split(RegExp(r'[/\\]')).last;
    final newPath = '$targetDirectoryPath${Platform.pathSeparator}$sourceName';

    if (sourcePath == newPath) return; // Même endroit

    try {
      await rust_fs.renameItem(oldPath: sourcePath, newPath: newPath);
      EditorManager.instance.renameOpenedFile(sourcePath, newPath);
      loadTree();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur de déplacement: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rootName = widget.rootPath.split(RegExp(r'[/\\]')).last;

    return Container(
      width: 250,
      color: theme.scaffoldBackgroundColor, // Fond standard
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header avec actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Text(
                      rootName.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                // Actions
                _buildHeaderIcon(
                  Icons.note_add_outlined,
                  'Nouveau fichier',
                  () => _createNewEntity(false),
                  theme,
                ),
                _buildHeaderIcon(
                  Icons.create_new_folder_outlined,
                  'Nouveau dossier',
                  () => _createNewEntity(true),
                  theme,
                ),
                _buildHeaderIcon(
                  Icons.unfold_less,
                  'Réduire tout',
                  _collapseAll,
                  theme,
                ),
              ],
            ),
          ),

          // Arbre de fichiers
          Expanded(
            child: _visibleNodes.isEmpty
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : DragTarget<String>(
                    onWillAcceptWithDetails: (details) {
                      final source = details.data;
                      return p.dirname(source) != widget.rootPath;
                    },
                    onAcceptWithDetails: (details) {
                      _handleDrop(details.data, widget.rootPath);
                    },
                    builder: (context, candidateData, rejectedData) {
                      return ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: _visibleNodes.length,
                        itemBuilder: (context, index) {
                          final node = _visibleNodes[index];
                          return ExplorerItem(
                            node: node,
                            isSelected: node.entity.path == _selectedNodePath,
                            onTap: () {
                              if (node.isDirectory) {
                                _toggleDirectory(node);
                              } else {
                                setState(() {
                                  _selectedNodePath = node.entity.path;
                                });
                                widget.onFileSelected?.call(node.entity.path);
                              }
                            },
                            onSecondaryTap: (pos) => _showContextMenu(pos, node),
                            onDroppedOn: (source) => _handleDrop(source, node.entity.path),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIcon(
    IconData icon,
    String tooltip,
    VoidCallback onPressed,
    ThemeData theme,
  ) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Icon(
            icon,
            size: 18,
            color: theme.iconTheme.color?.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}
