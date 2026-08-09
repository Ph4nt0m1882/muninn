import 'package:flutter/foundation.dart';
import 'package:yaml/yaml.dart';
import 'package:muninn/src/rust/api/fs.dart' as rust_fs;
import 'package:muninn/core/utils/logger.dart';

class SettingsManager extends ChangeNotifier {
  static final SettingsManager instance = SettingsManager._internal();
  SettingsManager._internal();

  Map<String, dynamic> _settings = {};

  /// Charge les paramètres depuis le fichier .crow d'un wiki
  Future<void> loadSettings(String wikiRoot) async {
    try {
      final file = await rust_fs.readAnchor(rootPath: wikiRoot);
      _parseYamlSettings(file.settings);
    } catch (e) {
      AppLogger.e("Erreur lors du chargement des paramètres du wiki : $e");
    }
  }

  /// Met à jour les paramètres (appelé depuis l'écran de configuration)
  void updateSettings(String yamlString) {
    _parseYamlSettings(yamlString);
  }

  void _parseYamlSettings(String yamlString) {
    if (yamlString.trim().isEmpty) {
      _settings = {};
      notifyListeners();
      return;
    }

    try {
      final doc = loadYaml(yamlString);
      if (doc is YamlMap) {
        _settings = Map<String, dynamic>.from(doc);
        notifyListeners();
      }
    } catch (e) {
      AppLogger.e("Erreur de parsing YAML dans SettingsManager : $e");
    }
  }

  /// Récupère un paramètre spécifique avec une valeur par défaut
  T getValue<T>(String key, T defaultValue) {
    final value = _settings[key];
    if (value != null && value is T) {
      return value;
    }
    return defaultValue;
  }
}
