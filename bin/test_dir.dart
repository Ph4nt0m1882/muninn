import 'dart:io';

void main() async {
  String appData = Platform.environment['APPDATA'] ?? '';
  String globalPath = '$appData\\Munnin/.munnin/commands';
  
  print('Path: $globalPath');
  var dir = Directory(globalPath);
  print('Exists: ${await dir.exists()}');
  
  if (await dir.exists()) {
    var list = await dir.list().toList();
    print('Entities: ${list.length}');
    for (var e in list) {
      print('- ${e.path} | isFile: ${await FileSystemEntity.isFile(e.path)} | isDir: ${await FileSystemEntity.isDirectory(e.path)}');
    }
  }
}
