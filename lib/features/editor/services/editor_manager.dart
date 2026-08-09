import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:muninn/core/utils/logger.dart';
import 'package:muninn/src/rust/api/fs.dart' as rust_fs;
import 'package:muninn/src/rust/api/models.dart';
import 'package:muninn/src/rust/api/search.dart' as rust_search;
import 'package:muninn/src/rust/api/rag.dart' as rust_rag;
import 'package:muninn/core/modules/module_registry.dart';

import 'package:muninn/features/editor/models/opened_file.dart';
import 'package:muninn/features/editor/models/file_metadata.dart';

class EditorManager extends ChangeNotifier {
  static final EditorManager instance = EditorManager._internal();
  EditorManager._internal();

  final List<OpenedFile> _openedFiles = [];
  String? _activeFilePath;
  String? wikiRoot;

  List<OpenedFile> get openedFiles => List.unmodifiable(_openedFiles);
  String? get activeFilePath => _activeFilePath;

  OpenedFile? get activeFile {
    if (_activeFilePath == null) return null;
    try {
      return _openedFiles.firstWhere((f) => f.path == _activeFilePath);
    } catch (_) {
      return null;
    }
  }

  /// Ouvre un fichier. S'il est déjà ouvert, le met simplement au premier plan.
  Future<void> openFile(
    String path, {
    TabOpenAnimation animation = TabOpenAnimation.normal,
  }) async {
    // Vérifie si déjà ouvert
    final existingIndex = _openedFiles.indexWhere((f) => f.path == path);
    if (existingIndex != -1) {
      _activeFilePath = path;
      notifyListeners();
      return;
    }

    try {
      String content = await rust_fs.readFileAsString(path: path);
      final mode = path.toLowerCase().endsWith('.crow')
          ? EditorMode.settings
          : EditorMode.markdown;
          
      FileMetadata? metadata;
      if (mode == EditorMode.markdown) {
        final match = RegExp(r'^---\n([\s\S]*?)\n---').firstMatch(content);
        final defaultTitle = path.split(RegExp(r'[/\\]')).last.replaceAll('.md', '');
        if (match != null) {
          final yamlContent = match.group(1)!;
          metadata = FileMetadata.fromYaml(yamlContent, defaultTitle: defaultTitle);
          // Strip the frontmatter from the content shown in the editor
          content = content.substring(match.end).trimLeft();
        } else {
          metadata = FileMetadata.defaultMeta(defaultTitle);
        }
      }

      _openedFiles.add(
        OpenedFile(
          path: path,
          content: content,
          metadata: metadata,
          openAnimation: animation,
          mode: mode,
        ),
      );
      _activeFilePath = path;
      notifyListeners();
    } catch (e) {
      AppLogger.e("Erreur lors de l'ouverture du fichier : $e");
    }
  }

  /// Ouvre un fichier et scrolle jusqu'aux offsets donnés
  Future<void> teleportTo(
    String path,
    int startOffset,
    int endOffset, {
    TabOpenAnimation animation = TabOpenAnimation.normal,
  }) async {
    await openFile(path, animation: animation);
    final file = _openedFiles.where((f) => f.path == path).firstOrNull;
    if (file != null) {
      file.teleportTarget = TeleportTarget(startOffset, endOffset);
      notifyListeners();
    }
  }

  /// Ferme un fichier
  void closeFile(String path) {
    final index = _openedFiles.indexWhere((f) => f.path == path);
    if (index == -1) return;

    _openedFiles.removeAt(index);

    // Ajuster le fichier actif si on a fermé celui en cours
    if (_activeFilePath == path) {
      if (_openedFiles.isNotEmpty) {
        // On active le précédent, ou le premier s'il n'y en a pas de précédent
        final newIndex = index > 0 ? index - 1 : 0;
        _activeFilePath = _openedFiles[newIndex].path;
      } else {
        _activeFilePath = null;
      }
    }
    notifyListeners();
  }

  /// Ouvre un WikiLink et crée le fichier s'il n'existe pas.
  Future<void> resolveWikiLink(
    String target,
    String header, {
    TabOpenAnimation animation = TabOpenAnimation.normal,
  }) async {
    String? foundPath;

    // 1. Chercher le fichier dans le workspace via le scan Rust
    if (wikiRoot != null) {
      try {
        final tree = await rust_fs.scanDirectory(rootPath: wikiRoot!);
        String? searchInTree(TreeNode node) {
          if (!node.isDirectory &&
              node.name.toLowerCase() == target.toLowerCase()) {
            return '$wikiRoot${Platform.pathSeparator}${node.path}'.replaceAll(
              '/',
              Platform.pathSeparator,
            );
          }
          for (var child in node.children) {
            final res = searchInTree(child);
            if (res != null) return res;
          }
          return null;
        }

        foundPath = searchInTree(tree);
      } catch (e) {
        AppLogger.e("Erreur lors de la recherche du WikiLink : $e");
      }
    }

    // 2. Créer si non trouvé
    if (foundPath == null && wikiRoot != null) {
      foundPath = '$wikiRoot${Platform.pathSeparator}$target.md';
      await rust_fs.writeFileAsString(
        path: foundPath,
        content: '# $target\n\n',
      );
    } else if (foundPath == null && _activeFilePath != null) {
      // Fallback si wikiRoot est null, on crée à côté du fichier courant
      final parent = File(_activeFilePath!).parent.path;
      foundPath = '$parent${Platform.pathSeparator}$target.md';
      await rust_fs.writeFileAsString(
        path: foundPath,
        content: '# $target\n\n',
      );
    }

    if (foundPath == null) return;

    // 3. Ouvrir le fichier
    await openFile(foundPath, animation: animation);

    // 4. Scroller au header si présent (implémentation future avec teleportTo)
    // TODO: chercher l'offset du header et appeler teleportTo si (header.isNotEmpty)
  }

  /// Met à jour le contenu d'un fichier (rend dirty)
  void updateFileContent(String path, String newContent) {
    final file = _openedFiles.where((f) => f.path == path).firstOrNull;
    if (file != null && file.content != newContent) {
      file.content = newContent;
      file.isDirty = true;
      notifyListeners();
    }
  }

  /// Marque manuellement un fichier comme propre (utile pour les sauvegardes partielles)
  void markAsClean(String path) {
    final file = _openedFiles.where((f) => f.path == path).firstOrNull;
    if (file != null && file.isDirty) {
      file.isDirty = false;
      notifyListeners();
    }
  }

  /// Remplace un bloc de code spécifique dans le fichier
  void replaceCodeBlock(
    String path,
    String oldCode,
    String newCode,
    String oldLang,
    String newLang,
  ) {
    final file = _openedFiles.where((f) => f.path == path).firstOrNull;
    if (file != null) {
      String content = file.content;

      // Nettoyage des retours chariot pour la recherche (au cas où)
      String searchCode = oldCode.endsWith('\n')
          ? oldCode.substring(0, oldCode.length - 1)
          : oldCode;
      searchCode = searchCode.replaceAll('\r\n', '\n');

      // Construction d'une RegEx tolérante aux fins de lignes (\n ou \r\n)
      String escapedSearch = RegExp.escape(
        searchCode,
      ).replaceAll('\n', r'\r?\n');

      final match = RegExp(escapedSearch).firstMatch(content);
      if (match != null) {
        int idx = match.start;
        int endIdx = match.end;

        int startBackticks = content.lastIndexOf('```', idx);
        if (startBackticks != -1) {
          int endOfLine = content.indexOf('\n', startBackticks);
          if (endOfLine != -1 && endOfLine <= idx) {
            String languageLine = content.substring(startBackticks, endOfLine);
            bool hasEdit = languageLine.contains('{edit}');
            String baseLang = newLang.replaceAll('{edit}', '').trim();
            // On conserve le nombre exact de backticks originaux (3 ou 4)
            String backticks = languageLine
                .split(RegExp(r'[a-zA-Z]'))
                .first
                .trim();
            if (backticks.isEmpty) backticks = '```';
            String newLanguageLine =
                '$backticks$baseLang${hasEdit ? ' {edit}' : ''}';

            int shift = newLanguageLine.length - (endOfLine - startBackticks);
            content = content.replaceRange(
              startBackticks,
              endOfLine,
              newLanguageLine,
            );
            content = content.replaceRange(
              idx + shift,
              endIdx + shift,
              newCode,
            );

            updateFileContent(path, content);
            return;
          }
        }

        // Si les backticks n'ont pas été trouvés mais que le code l'a été (fallback)
        content = content.replaceRange(match.start, match.end, newCode);
        updateFileContent(path, content);
        return;
      }

      // Fallback final
      updateFileContent(path, content.replaceFirst(oldCode, newCode));
    }
  }

  /// Sauvegarde le fichier actif
  Future<void> saveActiveFile() async {
    final file = activeFile;
    if (file != null && file.isDirty) {
      await _saveFileToDisk(file);
    }
  }

  /// Sauvegarde tous les fichiers modifiés
  Future<void> saveAll() async {
    for (var file in _openedFiles.where((f) => f.isDirty)) {
      await _saveFileToDisk(file);
    }
  }

  Future<void> _saveFileToDisk(OpenedFile openedFile) async {
    try {
      String contentToSave = openedFile.content;
      if (openedFile.mode == EditorMode.markdown && openedFile.metadata != null) {
        final yamlStr = openedFile.metadata!.toYamlString();
        contentToSave = '---\n$yamlStr\n---\n\n${openedFile.content}';
      }

      await rust_fs.writeFileAsString(
        path: openedFile.path,
        content: contentToSave,
      );
      openedFile.isDirty = false;

      if (openedFile.path.endsWith('.md')) {
        // Indexation pour la recherche texte (FTS)
        rust_search.indexDocument(
          filePath: openedFile.path,
          rawMarkdown: contentToSave,
        );

        // Indexation vectorielle (RAG) si on a un wiki
        if (wikiRoot != null) {
          await rust_rag.indexFile(
            wikiRoot: wikiRoot!,
            filePath: openedFile.path,
            content: contentToSave,
          );
        }
      }

      // Notification aux modules
      for (var module in ModuleRegistry.instance.modules) {
        module.onFileSaved(openedFile.path, contentToSave).catchError((e) {
          if (kDebugMode) {
            AppLogger.e("Erreur dans le module ${module.name} lors de la sauvegarde : $e");
          }
        });
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        AppLogger.e("Erreur lors de la sauvegarde de ${openedFile.path} : $e");
      }
    }
  }

  /// Renomme un fichier ouvert
  void renameOpenedFile(String oldPath, String newPath) {
    final index = _openedFiles.indexWhere((f) => f.path == oldPath);
    if (index != -1) {
      final file = _openedFiles[index];
      _openedFiles[index] = OpenedFile(
        path: newPath,
        content: file.content,
        isDirty: file.isDirty,
        mode: file.mode,
      );
      if (_activeFilePath == oldPath) {
        _activeFilePath = newPath;
      }
      notifyListeners();
    }
  }

  /// Change le mode d'un fichier ouvert (markdown/render)
  void setFileMode(String path, EditorMode mode) {
    final file = _openedFiles.where((f) => f.path == path).firstOrNull;
    if (file != null && file.mode != mode) {
      file.mode = mode;
      notifyListeners();
    }
  }

  /// Change le mode de tous les fichiers
  void setAllFilesMode(EditorMode mode) {
    bool changed = false;
    for (var file in _openedFiles) {
      if (file.mode != mode) {
        file.mode = mode;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  /// Ferme tous les fichiers (lors de la fermeture du wiki par exemple)
  void closeAll() {
    _openedFiles.clear();
    _activeFilePath = null;
    notifyListeners();
  }
}
