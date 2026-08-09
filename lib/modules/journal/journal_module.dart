import 'dart:io';
import 'package:flutter/material.dart';
import 'package:muninn/core/modules/muninn_module.dart';
import 'package:muninn/core/modules/module_config_manager.dart';
import 'package:path/path.dart' as p;

class JournalModule implements MuninnModule {
  @override
  String get id => 'journal';

  @override
  String get name => 'Journal Quotidien';

  @override
  String get description =>
      'Crée automatiquement une note par jour et supprime les notes vides.';

  @override
  List<ModuleFolderType> getFolderTypes() {
    return [
      ModuleFolderType(
        id: id,
        label: 'Dossier Journal (Quotidien)',
      ),
    ];
  }

  @override
  List<String> getLockedDirectories() {
    return ModuleConfigManager.instance.getPathsForModule(id);
  }

  @override
  Future<void> onFileSaved(String path, String content) async {}

  @override
  Widget? getSidebarIcon(BuildContext context) {
    return null;
  }

  @override
  Future<void> onWikiOpened(String wikiRoot) async {
    final journalPaths = ModuleConfigManager.instance.getPathsForModule(id);
    for (var relPath in journalPaths) {
      _initJournalFolder(wikiRoot, relPath);
    }
  }

  @override
  Future<void> onFolderConfigured(String wikiRoot, String relativePath) async {
    _initJournalFolder(wikiRoot, relativePath);
  }

  void _initJournalFolder(String wikiRoot, String relPath) {
    final journalRoot = Directory(p.join(wikiRoot, relPath));
    if (!journalRoot.existsSync()) {
      journalRoot.createSync(recursive: true);
    }

    // 1. Nettoyage des fichiers et dossiers vides
    _cleanupEmptyEntries(journalRoot);

    // 2. Création de l'arborescence du jour
    final now = DateTime.now();
    final year = now.year.toString();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');

    final todayDir = Directory(p.join(journalRoot.path, year, month));
    if (!todayDir.existsSync()) {
      todayDir.createSync(recursive: true);
    }

    final todayFile = File(p.join(todayDir.path, '$day.md'));
    if (!todayFile.existsSync()) {
      todayFile.writeAsStringSync('');
    }
  }

  void _cleanupEmptyEntries(Directory dir) {
    if (!dir.existsSync()) return;

    for (var entity in dir.listSync(recursive: false)) {
      if (entity is Directory) {
        // Nettoyage récursif d'abord
        _cleanupEmptyEntries(entity);
        
        // Si le dossier est maintenant vide, on le supprime
        if (entity.existsSync() && entity.listSync().isEmpty) {
          try {
            entity.deleteSync();
          } catch (_) {}
        }
      } else if (entity is File && entity.path.endsWith('.md')) {
        // Si le fichier est vide (que des espaces ou rien), on le supprime
        try {
          final content = entity.readAsStringSync().trim();
          if (content.isEmpty) {
            entity.deleteSync();
          }
        } catch (_) {}
      }
    }
  }
}
