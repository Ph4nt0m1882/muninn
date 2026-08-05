import 'dart:io';

void main() {
  final modulesDir = Directory('lib/modules');
  if (!modulesDir.existsSync()) {
    modulesDir.createSync(recursive: true);
  }

  final moduleFiles = <String>[];
  final moduleClasses = <String>[];

  // Parcourt les sous-dossiers de lib/modules/
  for (var entity in modulesDir.listSync(recursive: false)) {
    if (entity is Directory) {
      final moduleName = entity.path.split(Platform.pathSeparator).last;
      final mainModuleFile = File('${entity.path}/${moduleName}_module.dart');
      
      if (mainModuleFile.existsSync()) {
        moduleFiles.add('package:munnin/modules/$moduleName/${moduleName}_module.dart');
        
        // On lit le fichier pour trouver le nom de la classe qui étend MunninModule
        final lines = mainModuleFile.readAsLinesSync();
        for (var line in lines) {
          if (line.contains('class') && line.contains('implements MunninModule')) {
            final parts = line.trim().split(RegExp(r'\s+'));
            final classIndex = parts.indexOf('class');
            if (classIndex != -1 && classIndex + 1 < parts.length) {
              moduleClasses.add(parts[classIndex + 1]);
              break;
            }
          }
        }
      }
    }
  }

  // Génération du fichier module_registry.dart
  final buffer = StringBuffer();
  buffer.writeln('// CE FICHIER EST GÉNÉRÉ AUTOMATIQUEMENT. NE PAS MODIFIER.');
  buffer.writeln("import 'package:munnin/core/modules/munnin_module.dart';");
  
  for (var file in moduleFiles) {
    buffer.writeln("import '$file';");
  }

  buffer.writeln();
  buffer.writeln('class ModuleRegistry {');
  buffer.writeln('  static final ModuleRegistry instance = ModuleRegistry._internal();');
  buffer.writeln('  ModuleRegistry._internal();');
  buffer.writeln();
  buffer.writeln('  final List<MunninModule> _modules = [');
  for (var className in moduleClasses) {
    buffer.writeln('    $className(),');
  }
  buffer.writeln('  ];');
  buffer.writeln();
  buffer.writeln('  List<MunninModule> get modules => _modules;');
  buffer.writeln('}');

  final registryFile = File('lib/core/modules/module_registry.dart');
  registryFile.writeAsStringSync(buffer.toString());
  
  print('Généré module_registry.dart avec ${moduleClasses.length} module(s).');
}
