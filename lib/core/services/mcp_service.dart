import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:munnin/core/utils/logger.dart';
import 'package:munnin/core/utils/uv_installer.dart';
import 'package:path/path.dart' as p;
import 'package:munnin/core/services/ai_service.dart';

class McpTool {
  final String serverName;
  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;

  McpTool({
    required this.serverName,
    required this.name,
    required this.description,
    required this.inputSchema,
  });
}

class McpClient {
  final String name;
  final String scriptPath;
  final String venvPath;
  
  Process? _process;
  int _requestId = 1;
  final Map<int, Completer<dynamic>> _pendingRequests = {};
  bool isInitialized = false;

  McpClient({required this.name, required this.scriptPath, required this.venvPath});

  Future<void> start() async {
    try {
      final pythonExe = Platform.isWindows 
          ? p.join(venvPath, 'Scripts', 'python.exe')
          : p.join(venvPath, 'bin', 'python');
          
      if (!File(pythonExe).existsSync()) {
        AppLogger.w("MCP $name: Python executable introuvable dans le venv.");
        return;
      }

      _process = await Process.start(pythonExe, [scriptPath]);
      
      _process!.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen(_handleMessage);
      _process!.stderr.transform(utf8.decoder).listen((err) {
        AppLogger.d("MCP $name: $err");
      });

      _process!.exitCode.then((code) {
        AppLogger.w("MCP $name s'est arrêté avec le code $code");
        for (var completer in _pendingRequests.values) {
          if (!completer.isCompleted) {
            completer.completeError("Le processus MCP s'est arrêté inopinément (code $code).");
          }
        }
        _pendingRequests.clear();
        isInitialized = false;
        _process = null;
      });

      // 1. Initialisation MCP
      await _sendRequest('initialize', {
        'protocolVersion': '2024-11-05',
        'capabilities': {},
        'clientInfo': {'name': 'munnin', 'version': '1.0.0'}
      });

      // 2. Notification initialized
      _sendNotification('notifications/initialized', {});
      
      isInitialized = true;
      AppLogger.i("MCP $name initialisé avec succès.");
    } catch (e) {
      AppLogger.e("Erreur de démarrage MCP $name : $e");
    }
  }

  void _handleMessage(String message) {
    if (message.trim().isEmpty) return;
    try {
      final data = jsonDecode(message);
      if (data.containsKey('id')) {
        final id = data['id'] as int;
        if (_pendingRequests.containsKey(id)) {
          if (data.containsKey('error')) {
            _pendingRequests[id]!.completeError(data['error']);
          } else {
            _pendingRequests[id]!.complete(data['result']);
          }
          _pendingRequests.remove(id);
        }
      }
    } catch (e) {
      // Ignorer les logs non JSON
      AppLogger.w("MCP $name non-JSON: $message");
    }
  }

  void _sendMessage(Map<String, dynamic> message) {
    if (_process == null) return;
    final jsonStr = jsonEncode(message);
    _process!.stdin.writeln(jsonStr);
  }

  Future<dynamic> _sendRequest(String method, [Map<String, dynamic>? params]) {
    final id = _requestId++;
    final completer = Completer<dynamic>();
    _pendingRequests[id] = completer;

    final Map<String, dynamic> msg = {
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
    };
    if (params != null) msg['params'] = params;

    _sendMessage(msg);
    return completer.future;
  }

  void _sendNotification(String method, [Map<String, dynamic>? params]) {
    final Map<String, dynamic> msg = {
      'jsonrpc': '2.0',
      'method': method,
    };
    if (params != null) msg['params'] = params;
    _sendMessage(msg);
  }

  Future<List<McpTool>> getTools() async {
    if (!isInitialized) return [];
    try {
      final result = await _sendRequest('tools/list');
      final tools = result['tools'] as List<dynamic>;
      return tools.map((t) => McpTool(
        serverName: name,
        name: t['name'],
        description: t['description'],
        inputSchema: t['inputSchema'],
      )).toList();
    } catch (e) {
      AppLogger.e("Erreur getTools pour \$name : \$e");
      return [];
    }
  }

  Future<String> callTool(String toolName, Map<String, dynamic> arguments) async {
    try {
      final result = await _sendRequest('tools/call', {
        'name': toolName,
        'arguments': arguments,
      });
      final content = result['content'] as List<dynamic>;
      if (content.isNotEmpty) {
        return content.first['text'] ?? '';
      }
      return "Aucun contenu renvoyé par l'outil.";
    } catch (e) {
      return "Erreur lors de l'exécution de \$toolName: \$e";
    }
  }

  void stop() {
    _process?.kill();
    _process = null;
    isInitialized = false;
  }
}

class McpService {
  McpService._privateConstructor();
  static final McpService instance = McpService._privateConstructor();

  final List<McpClient> _clients = [];
  String? currentWikiRoot;

  void stopAll() {
    for (var client in _clients) {
      client.stop();
    }
    _clients.clear();
    currentWikiRoot = null;
  }

  Future<void> initialize(String? wikiRoot) async {
    if (currentWikiRoot == wikiRoot && _clients.isNotEmpty) return; // Déjà initialisé pour ce wiki
    
    stopAll();
    currentWikiRoot = wikiRoot;

    // Démarrer les clients globaux
    final globalDir = Directory(p.join(getGlobalMunninDir(), '.munnin', 'mcp'));
    
    try {
      if (!await globalDir.exists()) {
        await globalDir.create(recursive: true);
      }
      final toolsDir = Directory(p.join(globalDir.path, 'munnin_tools'));
      if (!await toolsDir.exists() || !await File(p.join(toolsDir.path, 'server.py')).exists()) {
        await UvInstaller.installMunninTools(globalDir.path);
      }
    } catch (e) {
      AppLogger.e("Erreur auto-install munnin_tools: \$e");
    }

    await _scanAndStart(globalDir);

    // Démarrer les clients locaux
    if (wikiRoot != null) {
      final localDir = Directory(p.join(wikiRoot, '.munnin', 'mcp'));
      await _scanAndStart(localDir);
    }
  }

  Future<void> _scanAndStart(Directory rootDir) async {
    if (!await rootDir.exists()) return;

    final dirs = await rootDir.list().toList();
    for (var entity in dirs) {
      if (await FileSystemEntity.isDirectory(entity.path)) {
        final serverFile = File(p.join(entity.path, 'server.py'));
        final venvDir = Directory(p.join(entity.path, '.venv'));

        if (await serverFile.exists() && await venvDir.exists()) {
          final client = McpClient(
            name: entity.path.split(Platform.pathSeparator).last,
            scriptPath: serverFile.path,
            venvPath: venvDir.path,
          );
          await client.start();
          _clients.add(client);
        }
      }
    }
  }

  Future<List<McpTool>> getAllTools() async {
    List<McpTool> allTools = [];
    for (var client in _clients) {
      allTools.addAll(await client.getTools());
    }
    return allTools;
  }

  Future<String?> executeTool(String toolName, Map<String, dynamic> arguments) async {
    final client = _toolToClient[toolName];
    if (client == null) {
      AppLogger.w("Outil MCP introuvable: $toolName");
      return null;
    }
    try {
      return await client.callTool(toolName, arguments);
    } catch (e) {
      AppLogger.e("Erreur lors de l'exécution de l'outil MCP $toolName : $e");
      return "Erreur d'exécution: $e";
    }
  }

  // Optimize execution by mapping tool names to clients
  final Map<String, McpClient> _toolToClient = {};

  Future<List<McpTool>> getAndRegisterTools() async {
    _toolToClient.clear();
    List<McpTool> allTools = [];
    for (var client in _clients) {
      final tools = await client.getTools();
      for (var tool in tools) {
        _toolToClient[tool.name] = client;
        allTools.add(tool);
      }
    }
    return allTools;
  }

  Future<String> callRegisteredTool(String toolName, Map<String, dynamic> arguments) async {
    if (_toolToClient.containsKey(toolName)) {
      return await _toolToClient[toolName]!.callTool(toolName, arguments);
    }
    return "Erreur: Outil \$toolName introuvable.";
  }
}
