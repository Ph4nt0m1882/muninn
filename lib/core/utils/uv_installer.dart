import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import 'package:munnin/core/utils/logger.dart';
import 'package:flutter/services.dart';

class UvInstaller {
  static Future<String> getUvExecutablePath(String targetDir) async {
    final exeName = Platform.isWindows ? 'uv.exe' : 'uv';
    final uvPath = p.join(targetDir, exeName);
    
    if (await File(uvPath).exists()) {
      return uvPath;
    }

    AppLogger.i("Téléchargement de uv dans \$targetDir...");
    
    // Construire l'URL de téléchargement selon l'OS et l'architecture
    String url = '';
    bool isZip = false;
    
    // UV Releases GitHub: https://github.com/astral-sh/uv/releases/latest
    if (Platform.isWindows) {
      url = 'https://github.com/astral-sh/uv/releases/latest/download/uv-x86_64-pc-windows-msvc.zip';
      isZip = true;
    } else if (Platform.isMacOS) {
      // macOS M1/M2 = aarch64, Intel = x86_64
      // Dans le doute, on pourrait faire un fallback, mais on suppose aarch64 pour les Macs modernes
      final isArm = Platform.version.contains('arm64') || true; // Simplification, le mieux serait SysInfo mais ce n'est pas dispo de base
      url = isArm 
          ? 'https://github.com/astral-sh/uv/releases/latest/download/uv-aarch64-apple-darwin.tar.gz'
          : 'https://github.com/astral-sh/uv/releases/latest/download/uv-x86_64-apple-darwin.tar.gz';
    } else if (Platform.isLinux) {
      url = 'https://github.com/astral-sh/uv/releases/latest/download/uv-x86_64-unknown-linux-gnu.tar.gz';
    } else {
      throw Exception("Système d'exploitation non supporté pour l'installation auto de uv");
    }

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception("Échec du téléchargement HTTP \$url: \${response.statusCode}");
      }
      
      final archiveBytes = response.bodyBytes;
      
      if (isZip) {
        final archive = ZipDecoder().decodeBytes(archiveBytes);
        for (final file in archive) {
          if (file.isFile && file.name.endsWith('uv.exe')) {
            final outFile = File(uvPath);
            await outFile.writeAsBytes(file.content as List<int>);
            break;
          }
        }
      } else {
        // tar.gz
        final tarBytes = GZipDecoder().decodeBytes(archiveBytes);
        final archive = TarDecoder().decodeBytes(tarBytes);
        for (final file in archive) {
          if (file.isFile && (file.name.endsWith('/uv') || file.name == 'uv')) {
            final outFile = File(uvPath);
            await outFile.writeAsBytes(file.content as List<int>);
            
            // Rendre exécutable sur Mac/Linux
            if (!Platform.isWindows) {
              await Process.run('chmod', ['+x', uvPath]);
            }
            break;
          }
        }
      }
      
      if (!await File(uvPath).exists()) {
        throw Exception("L'exécutable uv n'a pas été trouvé dans l'archive téléchargée.");
      }
      
      AppLogger.i("uv installé avec succès dans \$uvPath");
      return uvPath;
      
    } catch (e) {
      AppLogger.e("Erreur lors de l'installation de uv: \$e");
      rethrow;
    }
  }

  static Future<void> installMunninTools(String mcpGlobalDir) async {
    final toolsDir = Directory(p.join(mcpGlobalDir, 'munnin_tools'));
    if (!await toolsDir.exists()) {
      await toolsDir.create(recursive: true);
    }
    
    // 1. Extraire les assets
    AppLogger.i("Extraction des assets Python pour munnin_tools...");
    final serverContent = await rootBundle.loadString('assets/mcp/munnin_tools/server.py');
    final reqContent = await rootBundle.loadString('assets/mcp/munnin_tools/requirements.txt');
    
    await File(p.join(toolsDir.path, 'server.py')).writeAsString(serverContent);
    await File(p.join(toolsDir.path, 'requirements.txt')).writeAsString(reqContent);
    
    // 2. S'assurer que uv est présent
    final uvPath = await getUvExecutablePath(mcpGlobalDir);
    
    // 3. Créer le venv et installer les dépendances (silencieusement)
    AppLogger.i("Création du venv Python avec uv...");
    
    // Créer un environnement virtuel Python 3.12 
    final venvResult = await Process.run(uvPath, ['venv', '--python', '3.12'], workingDirectory: toolsDir.path);
    if (venvResult.exitCode != 0) {
      throw Exception("Erreur création venv: \${venvResult.stderr}");
    }
    
    AppLogger.i("Installation des dépendances avec uv...");
    // Installer les requirements
    final pipResult = await Process.run(uvPath, ['pip', 'install', '-r', 'requirements.txt'], workingDirectory: toolsDir.path);
    if (pipResult.exitCode != 0) {
      throw Exception("Erreur installation dépendances: \${pipResult.stderr}");
    }
    
    AppLogger.i("Environnement munnin_tools installé avec succès !");
  }
}
