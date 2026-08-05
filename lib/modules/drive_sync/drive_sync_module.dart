import 'dart:io';
import 'package:flutter/material.dart';
import 'package:munnin/core/modules/munnin_module.dart';
import 'package:munnin/core/modules/module_config_manager.dart';
import 'package:path/path.dart' as p;

class DriveSyncModule implements MunninModule {
  @override
  String get id => 'drive_sync';

  @override
  String get name => 'Drive Sync';

  @override
  String get description =>
      'Synchronise automatiquement le sous-dossier DriveSync lors d\'une sauvegarde.';

  @override
  List<ModuleFolderType> getFolderTypes() {
    return [
      ModuleFolderType(
        id: id,
        label: 'Dossier synchronisé (Local/Drive)',
        fields: [
          ModuleFolderField(
            key: 'local_drive_path',
            label: 'Chemin du dossier de destination (ex: G:\\Mon Drive\\Notes)',
            hint: r'C:\Users\nom\Google Drive\Munnin',
            isDirectoryPicker: true,
          ),
        ],
      ),
    ];
  }

  @override
  List<String> getLockedDirectories() {
    return [];
  }

  @override
  Future<void> onWikiOpened(String wikiRoot) async {
    // Rien de spécifique à faire à l'ouverture, le dossier est créé par l'UI
  }

  @override
  Future<void> onFolderConfigured(String wikiRoot, String relativePath) async {
    final config = ModuleConfigManager.instance.getConfigForPath(relativePath);
    if (config == null) return;
    
    var localDrivePath = config['local_drive_path'] as String?;
    if (localDrivePath == null || localDrivePath.isEmpty) return;
    
    // Normalisation du chemin local
    localDrivePath = p.normalize(localDrivePath);
    
    // Le nom du dossier que l'utilisateur a donné (ex: "MesNotes")
    final folderName = relativePath.split('/').last;

    // Si le dossier choisi ne finit pas par .munnin, on crée un sous-dossier .munnin
    if (!localDrivePath.endsWith('.munnin')) {
      localDrivePath = p.join(localDrivePath, '.$folderName.munnin');
      
      // Mise à jour de la configuration avec ce nouveau chemin
      final newConfig = Map<String, dynamic>.from(config);
      newConfig['local_drive_path'] = localDrivePath;
      await ModuleConfigManager.instance.setConfigForPath(relativePath, id, newConfig);
    }
    
    // On s'assure que le dossier cible existe sur le Drive
    final targetDir = Directory(localDrivePath);
    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }
    
    // Le dossier créé par l'explorateur Munnin
    final munninDir = Directory(p.join(wikiRoot, relativePath));
    
    // On supprime le dossier vide créé par l'UI pour laisser la place au lien
    if (munninDir.existsSync()) {
      munninDir.deleteSync(recursive: true);
    }
    
    // Création du Junction Point (mklink /J "chemin_munnin" "chemin_drive")
    try {
      final result = await Process.run(
        'cmd',
        ['/c', 'mklink', '/J', munninDir.path, targetDir.path],
      );
      
      if (result.exitCode == 0) {
        debugPrint('[DriveSyncModule] ✅ Jonction créée avec succès vers $localDrivePath');
      } else {
        debugPrint('[DriveSyncModule] ❌ Erreur lors de la création de la jonction : ${result.stderr}');
      }
    } catch (e) {
      debugPrint('[DriveSyncModule] ❌ Exception lors de la création de la jonction : $e');
    }
  }

  @override
  Future<void> onFileSaved(String path, String content) async {
    // La synchronisation est gérée à 100% par le système d'exploitation via la Jonction !
    // Zéro code nécessaire.
  }

  @override
  Widget? getSidebarIcon(BuildContext context) {
    return null;
  }
}
