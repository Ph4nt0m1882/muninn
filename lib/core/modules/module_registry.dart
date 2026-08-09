// CE FICHIER EST GÉNÉRÉ AUTOMATIQUEMENT. NE PAS MODIFIER.
import 'package:muninn/core/modules/muninn_module.dart';
import 'package:muninn/modules/drive_sync/drive_sync_module.dart';
import 'package:muninn/modules/journal/journal_module.dart';

class ModuleRegistry {
  static final ModuleRegistry instance = ModuleRegistry._internal();
  ModuleRegistry._internal();

  final List<MuninnModule> _modules = [
    DriveSyncModule(),
    JournalModule(),
  ];

  List<MuninnModule> get modules => _modules;
}
