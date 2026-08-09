import 'package:flutter/material.dart';

/// L'interface de base que tout module Muninn doit implémenter.
abstract class MuninnModule {
  /// L'identifiant unique du module (ex: "journal")
  String get id;

  /// Le nom d'affichage du module
  String get name;

  /// La description de ce que fait le module
  String get description;

  /// Appelé lors de l'ouverture du wiki, avant l'affichage de l'UI
  Future<void> onWikiOpened(String wikiRoot) async {}

  /// Liste des dossiers dans lesquels la création de fichier MANUELLE (via l'UI) est interdite.
  /// Le module peut toujours y créer des fichiers programmatiquement.
  List<String> getLockedDirectories() {
    return [];
  }

  /// Liste des types de dossiers spéciaux proposés par ce module
  List<ModuleFolderType> getFolderTypes() {
    return [];
  }

  /// Appelé lorsqu'un dossier est configuré pour ce module via l'UI
  Future<void> onFolderConfigured(String wikiRoot, String relativePath) async {}

  /// Appelé à chaque fois qu'un fichier Markdown est sauvegardé
  Future<void> onFileSaved(String path, String content) async {}

  /// (Optionnel) Retourne une icône à ajouter dans la barre latérale gauche
  /// Si cliquée, elle pourra ouvrir une interface spécifique ou déclencher une action.
  Widget? getSidebarIcon(BuildContext context) {
    return null;
  }
}

/// Représente un type de dossier spécial qu'un module peut gérer
class ModuleFolderType {
  final String id;
  final String label;
  final List<ModuleFolderField> fields;

  ModuleFolderType({
    required this.id,
    required this.label,
    this.fields = const [],
  });
}

class ModuleFolderField {
  final String key;
  final String label;
  final String? hint;
  final bool isDirectoryPicker;

  ModuleFolderField({
    required this.key,
    required this.label,
    this.hint,
    this.isDirectoryPicker = false,
  });
}
