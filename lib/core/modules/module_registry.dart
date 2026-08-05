// CE FICHIER EST GÉNÉRÉ AUTOMATIQUEMENT. NE PAS MODIFIER.
import 'package:munnin/core/modules/munnin_module.dart';
import 'package:munnin/modules/drive_sync/drive_sync_module.dart';
import 'package:munnin/modules/journal/journal_module.dart';

class ModuleRegistry {
  static final ModuleRegistry instance = ModuleRegistry._internal();
  ModuleRegistry._internal();

  final List<MunninModule> _modules = [
    DriveSyncModule(),
    JournalModule(),
  ];

  List<MunninModule> get modules => _modules;
}
