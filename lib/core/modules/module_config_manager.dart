import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:munnin/core/utils/logger.dart';
import 'package:munnin/src/rust/api/fs.dart' as rust_fs;
import 'package:munnin/src/rust/api/models.dart';

class ModuleConfigManager extends ChangeNotifier {
  static final ModuleConfigManager instance = ModuleConfigManager._internal();
  ModuleConfigManager._internal();

  Map<String, dynamic> _config = {};
  String? _currentWikiRoot;

  /// Charge la configuration des modules depuis la section `modules` du fichier `.crow`
  Future<void> loadConfig(String wikiRoot) async {
    _currentWikiRoot = wikiRoot;
    try {
      final file = await rust_fs.readAnchor(rootPath: wikiRoot);
      if (file.modules.trim().isNotEmpty) {
        _config = jsonDecode(file.modules) as Map<String, dynamic>;
      } else {
        _config = {};
      }
      notifyListeners();
    } catch (e) {
      AppLogger.e("Erreur lors du chargement de la config des modules: $e");
      _config = {};
      notifyListeners();
    }
  }

  /// Retourne la configuration spécifique pour un chemin de dossier donné
  /// Le chemin doit être relatif au wiki Root
  Map<String, dynamic>? getConfigForPath(String relPath) {
    if (_config.containsKey('directories')) {
      final dirs = _config['directories'] as Map<String, dynamic>;
      return dirs[relPath] as Map<String, dynamic>?;
    }
    return null;
  }

  /// Retourne tous les chemins relatifs (clés) qui sont associés à un module donné
  List<String> getPathsForModule(String moduleId) {
    final List<String> paths = [];
    if (_config.containsKey('directories')) {
      final dirs = _config['directories'] as Map<String, dynamic>;
      dirs.forEach((path, data) {
        if (data is Map<String, dynamic> && data['type'] == moduleId) {
          paths.add(path);
        }
      });
    }
    return paths;
  }

  /// Associe une configuration de module à un chemin de dossier
  Future<void> setConfigForPath(String relPath, String moduleId, Map<String, dynamic> data) async {
    if (_currentWikiRoot == null) return;

    if (!_config.containsKey('directories')) {
      _config['directories'] = <String, dynamic>{};
    }
    final dirs = _config['directories'] as Map<String, dynamic>;
    
    // On fusionne le type (moduleId) avec les données
    final moduleData = Map<String, dynamic>.from(data);
    moduleData['type'] = moduleId;
    
    dirs[relPath] = moduleData;

    await _saveConfig();
    notifyListeners();
  }

  /// Supprime la configuration associée à un chemin
  Future<void> removeConfigForPath(String relPath) async {
    if (_currentWikiRoot == null) return;
    
    if (_config.containsKey('directories')) {
      final dirs = _config['directories'] as Map<String, dynamic>;
      if (dirs.containsKey(relPath)) {
        dirs.remove(relPath);
        await _saveConfig();
        notifyListeners();
      }
    }
  }

  /// Renomme un chemin dans la configuration
  Future<void> renameConfigPath(String oldRelPath, String newRelPath) async {
    if (_currentWikiRoot == null) return;

    if (_config.containsKey('directories')) {
      final dirs = _config['directories'] as Map<String, dynamic>;
      if (dirs.containsKey(oldRelPath)) {
        final data = dirs.remove(oldRelPath);
        dirs[newRelPath] = data;
        await _saveConfig();
        notifyListeners();
      }
    }
  }


  Future<void> _saveConfig() async {
    if (_currentWikiRoot == null) return;

    try {
      final jsonString = jsonEncode(_config);
      
      // On lit l'anchor complet pour ne pas écraser les metadatas/settings
      final currentFile = await rust_fs.readAnchor(rootPath: _currentWikiRoot!);
      
      final updatedFile = CrowFile(
        metadata: currentFile.metadata,
        settings: currentFile.settings,
        modules: jsonString,
      );

      await rust_fs.writeAnchor(
        rootPath: _currentWikiRoot!,
        crowFile: updatedFile,
      );
    } catch (e) {
      AppLogger.e("Erreur lors de la sauvegarde de la config des modules: $e");
    }
  }
}
