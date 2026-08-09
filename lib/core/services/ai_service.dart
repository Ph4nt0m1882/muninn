import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:muninn/src/rust/api/settings.dart';
import 'package:muninn/src/rust/api/rag.dart';
import 'package:muninn/core/utils/logger.dart';
import 'package:muninn/core/services/mcp_service.dart';
import 'package:muninn/features/editor/services/editor_manager.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class ChatResult {
  final String text;
  final List<String> sources;

  ChatResult(this.text, this.sources);
}

String getGlobalMuninnDir() {
  if (Platform.isWindows) {
    return p.join(Platform.environment['APPDATA'] ?? '', 'Muninn');
  } else if (Platform.isLinux) {
    return p.join(Platform.environment['HOME'] ?? '', '.config', 'muninn');
  } else if (Platform.isMacOS) {
    return p.join(Platform.environment['HOME'] ?? '', 'Library', 'Application Support', 'Muninn');
  }
  return '';
}

class AIService {
  static final AIService instance = AIService._internal();
  
  // Modèle d'IA actuellement sélectionné
  static final ValueNotifier<String> selectedModelNotifier = ValueNotifier<String>('gemini-3.5-flash-lite');

  GenerativeModel? _model;
  
  AIService._internal();

  /// Initialise le client Gemini
  void initialize() {
    final settings = loadSettings();
    final apiKey = settings.googleApiKey;

    if (apiKey != null && apiKey.isNotEmpty) {
      _model = GenerativeModel(
        model: 'gemini-3.5-flash-lite',
        apiKey: apiKey,
      );
      AppLogger.i("Client Gemini (AI Service) initialisé avec succès.");
    } else {
      AppLogger.w("Impossible d'initialiser Gemini: Aucune clé d'API Google configurée.");
      _model = null;
    }
  }

  /// Appelle l'API Gemini pour générer un résumé
  Future<String> summarize(String text) async {
    if (_model == null) {
      // Tenter une réinitialisation au cas où la clé viendrait d'être ajoutée
      initialize();
      if (_model == null) {
        throw Exception("Clé d'API manquante. Veuillez la configurer dans la palette de commandes (Configuration IA).");
      }
    }

    final prompt = 'Fais un résumé très concis du texte Markdown suivant :\n\n$text';
    final content = [Content.text(prompt)];
    
    try {
      final response = await _model!.generateContent(content);
      return response.text ?? "Aucune réponse générée.";
    } catch (e) {
      AppLogger.e("Erreur de l'API Gemini : $e");
      rethrow;
    }
  }

  /// Construit les System Instructions à partir des fichiers Markdown
  Future<Content?> _buildSystemInstruction(String? actionPrefix) async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      
      final allSystemPrompts = manifest.listAssets()
          .where((String key) => key.startsWith('assets/system_prompts/'))
          .toList()
          ..sort(); // Trie par ordre alphabétique

      String finalPrompt = '';

      if (actionPrefix == null || actionPrefix.isEmpty) {
        // Chat par défaut : charger tous les fichiers globaux (racine de system_prompts)
        final globalFiles = allSystemPrompts.where((path) {
          final parts = path.split('/');
          return parts.length == 3 && path.endsWith('.md');
        }).toList();

        for (final assetPath in globalFiles) {
          final filename = assetPath.split('/').last;
          final content = await rootBundle.loadString(assetPath);
          finalPrompt += '--- DEBUT FICHIER CONTEXTE : $filename ---\n$content\n--- FIN FICHIER CONTEXTE ---\n\n';
        }
      } else {
        // Commande spécifique (ex: 01_write)
        final actionFolder = 'assets/system_prompts/$actionPrefix/';
        final manifestPath = '${actionFolder}manifest.txt';

        // 1. Lire le manifest pour charger les globaux demandés
        if (allSystemPrompts.contains(manifestPath)) {
          final manifestText = await rootBundle.loadString(manifestPath);
          final lines = manifestText.split('\n');
          for (String line in lines) {
            line = line.trim();
            if (line.isEmpty || line.startsWith('#')) continue;
            
            // Résolution basique du chemin relatif vers les fichiers globaux
            if (line.startsWith('../')) {
              final globalFilename = line.substring(3);
              final globalPath = 'assets/system_prompts/$globalFilename';
              if (allSystemPrompts.contains(globalPath)) {
                final content = await rootBundle.loadString(globalPath);
                finalPrompt += '--- DEBUT FICHIER CONTEXTE : $globalFilename ---\n$content\n--- FIN FICHIER CONTEXTE ---\n\n';
              }
            }
          }
        }

        // 2. Charger tous les fichiers .md locaux du dossier d'action
        final localFiles = allSystemPrompts.where((path) => path.startsWith(actionFolder) && path.endsWith('.md')).toList();
        for (final assetPath in localFiles) {
          final filename = assetPath.split('/').last;
          final content = await rootBundle.loadString(assetPath);
          finalPrompt += '--- DEBUT FICHIER CONTEXTE : $actionPrefix/$filename ---\n$content\n--- FIN FICHIER CONTEXTE ---\n\n';
        }
      }
      
      // Injecter les informations sur l'OS pour aider l'IA avec les commandes système
      final osName = Platform.operatingSystem;
      final osVersion = Platform.operatingSystemVersion;
      finalPrompt += '--- INFORMATIONS SYSTEME ---\n';
      finalPrompt += 'Vous êtes exécuté sur une machine locale. Voici les informations du système cible :\n';
      finalPrompt += 'Système d\'exploitation : $osName\n';
      finalPrompt += 'Version : $osVersion\n';
      finalPrompt += 'Adaptez vos commandes système (ex: execute_command) à cet OS (ex: dir vs ls, chemins de fichiers, etc.).\n';
      finalPrompt += '--- FIN INFORMATIONS SYSTEME ---\n\n';

      if (finalPrompt.trim().isEmpty) return null;
      return Content.system(finalPrompt);
    } catch (e) {
      AppLogger.w("Impossible de charger les system prompts: $e");
      return null;
    }
  }

  /// Appelle l'API Gemini pour converser en utilisant l'historique
  Future<ChatResult> chat(String message, List<Content> history, {String? actionPrefix, required String wikiRoot}) async {
    final settings = loadSettings();
    final apiKey = settings.googleApiKey;

    if (apiKey == null || apiKey.isEmpty) {
      throw Exception("Clé d'API manquante. Veuillez la configurer dans la palette de commandes.");
    }

    // 1. Charger les instructions système basiques
    var systemInstruction = await _buildSystemInstruction(actionPrefix);
    
    // 2. Recherche vectorielle (RAG) dans le wiki
    List<String> sources = [];
    try {
      final searchResults = await searchSimilar(wikiRoot: wikiRoot, query: message, limit: BigInt.from(5));
      
      if (searchResults.isNotEmpty) {
        String ragContext = "\n\n--- CONTEXTE WIKI PERTINENT ---\n";
        ragContext += "Voici des extraits du wiki de l'utilisateur qui pourraient t'aider à répondre:\n\n";
        for (var chunk in searchResults) {
          ragContext += "Fichier: ${chunk.filePath}\nExtrait:\n${chunk.chunkText}\n\n";
          
          final fileName = chunk.filePath.split(RegExp(r'[/\\]')).last;
          if (!sources.contains(fileName)) {
            sources.add(fileName);
          }
        }
        ragContext += "--- FIN CONTEXTE WIKI ---\n";
        ragContext += "Note: Utilise ce contexte pour répondre à la question si c'est pertinent. Tu n'as accès qu'aux informations de ce wiki.\n";
        
        // On injecte le RAG directement dans le message de l'utilisateur 
        // pour s'assurer que le modèle le lit, même si systemInstruction est ignoré.
        message = "$ragContext\n\nQuestion ou instruction : $message";
        
        AppLogger.d("RAG: Injecté ${searchResults.length} extraits dans le message utilisateur.");
      }
    } catch (e) {
      AppLogger.w("Erreur lors de la recherche RAG: $e");
    }

    // 3.5 Initialiser et ajouter les outils MCP
    await McpService.instance.initialize(wikiRoot);
    List<FunctionDeclaration> functionDeclarations = [];
    final mcpTools = await McpService.instance.getAndRegisterTools();
    
    String finalSystemInstruction = "";
    if (systemInstruction != null && systemInstruction.parts.isNotEmpty) {
      final part = systemInstruction.parts.first;
      if (part is TextPart) {
        finalSystemInstruction = part.text;
      }
    }

    if (mcpTools.isNotEmpty) {
      finalSystemInstruction += "\n\nTu as accès aux outils externes (fonctions) suivants que tu peux appeler automatiquement si besoin :\n";
    }

    for (var mcpTool in mcpTools) {
      functionDeclarations.add(FunctionDeclaration(
        mcpTool.name,
        mcpTool.description,
        _convertJsonSchema(mcpTool.inputSchema),
      ));
      finalSystemInstruction += "- ${mcpTool.name}: ${mcpTool.description}\n";
    }

    if (actionPrefix == '06_create-mcp') {
      functionDeclarations.add(FunctionDeclaration(
        'create_mcp',
        'Crée un serveur MCP en Python',
        Schema.object(properties: {
          'name': Schema.string(description: 'Nom du serveur (minuscule sans espace)'),
          'server_content': Schema.string(description: 'Code Python complet du serveur (FastMCP)'),
          'requirements_content': Schema.string(description: 'Contenu du fichier requirements.txt'),
          'isGlobal': Schema.boolean(description: 'True si disponible globalement, false sinon'),
        }, requiredProperties: ['name', 'server_content', 'requirements_content']),
      ));
    } else if (actionPrefix == '05_create-commandes') {
      functionDeclarations.add(FunctionDeclaration(
        'create_command',
        'Crée une commande personnalisée',
        Schema.object(properties: {
          'name': Schema.string(description: 'Nom de la commande'),
          'content': Schema.string(description: 'Contenu du prompt'),
          'isGlobal': Schema.boolean(description: 'True si disponible globalement, false sinon'),
        }, requiredProperties: ['name', 'content']),
      ));
    } else if (actionPrefix == '04_create-rules') {
      functionDeclarations.add(FunctionDeclaration(
        'create_rule',
        'Crée une règle de contexte global',
        Schema.object(properties: {
          'name': Schema.string(description: 'Nom de la règle'),
          'content': Schema.string(description: 'Contenu de la règle'),
          'isGlobal': Schema.boolean(description: 'True si disponible globalement, false sinon'),
        }, requiredProperties: ['name', 'content']),
      ));
    }
    
    functionDeclarations.addAll(_getAdvancedTools());

    final tool = Tool(functionDeclarations: functionDeclarations);

    // On crée une instance locale du modèle avec les tools
    final chatModel = GenerativeModel(
      model: AIService.selectedModelNotifier.value,
      apiKey: apiKey,
      systemInstruction: finalSystemInstruction.isNotEmpty ? Content.system(finalSystemInstruction) : null,
      tools: functionDeclarations.isNotEmpty ? [tool] : null,
    );

    try {
      var currentSession = chatModel.startChat(history: history);
      var response = await currentSession.sendMessage(Content.text(message));
      
      // Gérer les appels d'outils
      int iterations = 0;
      const int maxIterations = 5;
      String finalReplyText = "";
      List<String> executedTools = [];

      while (response.functionCalls.isNotEmpty && iterations < maxIterations) {
        iterations++;
        List<FunctionResponse> functionResponses = [];

        for (var functionCall in response.functionCalls) {
          final cmdId = functionCall.name;
          final args = functionCall.args;
          
          AppLogger.i("L'IA demande l'exécution de l'outil MCP : $cmdId avec args : $args");
          
          try {
            if (cmdId == 'wiki_open_file') {
              final absolutePath = p.join(wikiRoot, args['filePath'] as String);
              EditorManager.instance.openFile(absolutePath);
              executedTools.add("Ouvrir ${args['filePath']}");
            } 
            else if (cmdId == 'wiki_write_file') {
              final absolutePath = p.join(args['isGlobal'] == true ? (await getApplicationSupportDirectory()).path : wikiRoot, args['filePath'] as String);
              final file = File(absolutePath);
              if (!file.parent.existsSync()) file.parent.createSync(recursive: true);
              
              final isOpened = EditorManager.instance.openedFiles.any((f) => f.path == absolutePath);
              if (isOpened) {
                EditorManager.instance.updateFileContent(absolutePath, args['content'] as String);
                if (args['isGlobal'] != true) EditorManager.instance.openFile(absolutePath);
              } else {
                file.writeAsStringSync(args['content'] as String);
                if (args['isGlobal'] != true) EditorManager.instance.openFile(absolutePath);
              }
              executedTools.add("Modifier ${args['filePath']}");
            }
            else if (cmdId == 'wiki_read_file') {
              final String filePath = args['filePath'] as String;
              final absolutePath = p.join(wikiRoot, filePath);
              final file = File(absolutePath);
              if (file.existsSync()) {
                final content = file.readAsStringSync();
                functionResponses.add(FunctionResponse(cmdId, {'content': content}));
              } else {
                functionResponses.add(FunctionResponse(cmdId, {'error': 'Fichier introuvable'}));
              }
            }
            else if (cmdId == 'wiki_append_to_file') {
              final String filePath = args['filePath'] as String;
              final String content = args['content'] as String;
              final absolutePath = p.join(wikiRoot, filePath);
              final file = File(absolutePath);
              if (file.existsSync()) {
                final opened = EditorManager.instance.openedFiles.where((f) => f.path == absolutePath).firstOrNull;
                if (opened != null) {
                  EditorManager.instance.updateFileContent(absolutePath, opened.content + "\n" + content);
                } else {
                  file.writeAsStringSync("\n" + content, mode: FileMode.append);
                }
                EditorManager.instance.openFile(absolutePath);
                executedTools.add("Ajouter à $filePath");
              } else {
                functionResponses.add(FunctionResponse(cmdId, {'error': 'Fichier introuvable'}));
              }
            }
            else if (cmdId == 'wiki_insert_in_file') {
              final String filePath = args['filePath'] as String;
              final String contentToInsert = args['content'] as String;
              final String position = args['position'] as String;
              final num? lineNumberRaw = args['lineNumber'] as num?;
              final int? lineNumber = lineNumberRaw?.toInt();
              
              final absolutePath = p.join(wikiRoot, filePath);
              final file = File(absolutePath);
              
              if (!file.existsSync()) {
                functionResponses.add(FunctionResponse(cmdId, {'error': 'Fichier introuvable'}));
              } else {
                final opened = EditorManager.instance.openedFiles.where((f) => f.path == absolutePath).firstOrNull;
                String currentContent = opened != null ? opened.content : file.readAsStringSync();
                
                String newContent;
                if (position == 'start') {
                  newContent = contentToInsert + "\n\n" + currentContent;
                } else if (position == 'end') {
                  newContent = currentContent + "\n\n" + contentToInsert;
                } else if (position == 'line' && lineNumber != null) {
                  final lines = currentContent.split('\n');
                  if (lineNumber <= 1) {
                    newContent = contentToInsert + "\n" + currentContent;
                  } else if (lineNumber > lines.length) {
                    newContent = currentContent + "\n" + contentToInsert;
                  } else {
                    lines.insert(lineNumber - 1, contentToInsert);
                    newContent = lines.join('\n');
                  }
                } else {
                  newContent = currentContent + "\n" + contentToInsert;
                }
                
                if (opened != null) {
                  EditorManager.instance.updateFileContent(absolutePath, newContent);
                } else {
                  file.writeAsStringSync(newContent);
                }
                EditorManager.instance.openFile(absolutePath);
                executedTools.add("Insérer dans $filePath");
              }
            }
            else if (cmdId == 'wiki_list_directory') {
              final String dirPath = args['dirPath'] as String;
              final absolutePath = dirPath.isEmpty ? wikiRoot : p.join(wikiRoot, dirPath);
              final dir = Directory(absolutePath);
              if (dir.existsSync()) {
                final list = dir.listSync();
                final names = list.map((e) => p.basename(e.path)).toList();
                functionResponses.add(FunctionResponse(cmdId, {'files': names}));
              } else {
                functionResponses.add(FunctionResponse(cmdId, {'error': 'Dossier introuvable'}));
              }
            }
            else if (cmdId == 'wiki_create_directory') {
              final String dirPath = args['dirPath'] as String;
              final absolutePath = p.join(wikiRoot, dirPath);
              Directory(absolutePath).createSync(recursive: true);
              executedTools.add("Créer dossier $dirPath");
            }
            else if (cmdId == 'wiki_delete_file') {
              final String path = args['path'] as String;
              final absolutePath = p.join(wikiRoot, path);
              if (FileSystemEntity.isDirectorySync(absolutePath)) {
                Directory(absolutePath).deleteSync(recursive: true);
              } else if (File(absolutePath).existsSync()) {
                File(absolutePath).deleteSync();
              }
              executedTools.add("Supprimer $path");
            }
            else if (cmdId == 'wiki_rename_file') {
              final String oldPath = args['oldPath'] as String;
              final String newPath = args['newPath'] as String;
              final absoluteOld = p.join(wikiRoot, oldPath);
              final absoluteNew = p.join(wikiRoot, newPath);
              if (FileSystemEntity.isDirectorySync(absoluteOld)) {
                Directory(absoluteOld).renameSync(absoluteNew);
              } else if (File(absoluteOld).existsSync()) {
                File(absoluteOld).renameSync(absoluteNew);
              }
              executedTools.add("Renommer $oldPath");
            }
            else if (cmdId == 'create_rule') {
              final absolutePath = p.join(args['isGlobal'] == true ? getGlobalMuninnDir() : wikiRoot, '.muninn', 'rules', '${args['name']}.md');
              final file = File(absolutePath);
              if (!file.parent.existsSync()) file.parent.createSync(recursive: true);
              file.writeAsStringSync(args['content'] as String);
              executedTools.add("Créer Règle ${args['name']}");
            }
            else if (cmdId == 'create_command') {
              final absolutePath = p.join(args['isGlobal'] == true ? getGlobalMuninnDir() : wikiRoot, '.muninn', 'commands', args['name'] as String);
              final dir = Directory(absolutePath);
              if (!dir.existsSync()) dir.createSync(recursive: true);
              File(p.join(absolutePath, 'prompt.md')).writeAsStringSync(args['content'] as String);
              File(p.join(absolutePath, 'manifest.txt')).writeAsStringSync('name: ${args['name']}');
              executedTools.add("Créer Commande ${args['name']}");
              functionResponses.add(FunctionResponse(cmdId, {'result': 'Commande créée avec succès.'}));
            }
            else if (cmdId == 'create_mcp') {
              final String name = args['name'] as String;
              final String serverContent = args['server_content'] as String;
              final String requirementsContent = args['requirements_content'] as String;
              final bool isGlobal = args['isGlobal'] == true;
              
              final absolutePath = p.join(isGlobal ? getGlobalMuninnDir() : wikiRoot, '.muninn', 'mcp', name);
              final dir = Directory(absolutePath);
              if (!dir.existsSync()) dir.createSync(recursive: true);
              
              File(p.join(absolutePath, 'server.py')).writeAsStringSync(serverContent);
              File(p.join(absolutePath, 'requirements.txt')).writeAsStringSync(requirementsContent);
              
              AppLogger.i("Création du venv uv pour $name...");
              final venvRes = await Process.run('uv', ['venv'], workingDirectory: absolutePath);
              if (venvRes.exitCode != 0) AppLogger.w("uv venv erreur: ${venvRes.stderr}");
              
              AppLogger.i("Installation des dépendances pour $name...");
              final pipRes = await Process.run('uv', ['pip', 'install', '-r', 'requirements.txt'], workingDirectory: absolutePath);
              if (pipRes.exitCode != 0) AppLogger.w("uv pip install erreur: ${pipRes.stderr}");
              
              AppLogger.i("Redémarrage des serveurs MCP pour détecter le nouveau serveur $name...");
              McpService.instance.stopAll();
              await McpService.instance.initialize(wikiRoot);
              
              executedTools.add("Créer MCP $name");
              functionResponses.add(FunctionResponse(cmdId, {'result': 'Serveur MCP créé et initialisé avec succès ! (uv venv + pip install)'}));
            }
            else {
              // --- OUTILS MCP ---
              final result = await McpService.instance.executeTool(cmdId, args);
              if (result != null) {
                functionResponses.add(FunctionResponse(cmdId, {'result': result}));
                executedTools.add("MCP: $cmdId");
              } else {
                functionResponses.add(FunctionResponse(cmdId, {'error': 'Outil non reconnu'}));
                executedTools.add("Inconnu: $cmdId");
              }
            }
          } catch (e) {
            functionResponses.add(FunctionResponse(cmdId, {'error': e.toString()}));
            executedTools.add("Erreur: $cmdId");
          }
        }
        
        if (functionResponses.isNotEmpty) {
          try {
            response = await currentSession.sendMessage(Content('user', functionResponses));
            finalReplyText = response.text ?? finalReplyText;
          } catch (e) {
            if (e.toString().contains('thought_signature') || e.toString().contains('Function call')) {
              AppLogger.w("Fallback thought_signature déclenché pour contourner le bug du SDK Dart");
              String toolResultsText = "Voici les résultats des outils appelés (utilise-les pour répondre ou pour appeler l'outil suivant si nécessaire) :\n";
              for (var fr in functionResponses) {
                toolResultsText += "Outil ${fr.name} : ${jsonEncode(fr.response)}\n";
              }
              final fallbackModel = GenerativeModel(
                model: AIService.selectedModelNotifier.value,
                apiKey: apiKey,
                systemInstruction: finalSystemInstruction.isNotEmpty ? Content.system(finalSystemInstruction) : null,
                tools: functionDeclarations.isNotEmpty ? [tool] : null,
              );
              final fallbackSession = fallbackModel.startChat(history: history);
              response = await fallbackSession.sendMessage(Content.text("$message\n\n$toolResultsText"));
              finalReplyText = response.text ?? finalReplyText;
              currentSession = fallbackSession;
            } else {
              rethrow;
            }
          }
        } else {
          break;
        }
      }
      
      if (finalReplyText.isEmpty && response.text != null) {
        finalReplyText = response.text!;
      }
      return ChatResult(finalReplyText.isNotEmpty ? finalReplyText : (iterations > 0 ? "Action effectuée." : "Aucune réponse générée."), sources);
    } catch (e) {
      AppLogger.e("Erreur de l'API Gemini (Chat) : $e");
      rethrow;
    }
  }

  Schema _convertJsonSchema(Map<String, dynamic> schema) {
    final typeStr = schema['type'] as String?;
    SchemaType type = SchemaType.string;
    if (typeStr == 'object') type = SchemaType.object;
    else if (typeStr == 'array') type = SchemaType.array;
    else if (typeStr == 'integer') type = SchemaType.integer;
    else if (typeStr == 'number') type = SchemaType.number;
    else if (typeStr == 'boolean') type = SchemaType.boolean;

    Map<String, Schema>? properties;
    if (schema.containsKey('properties')) {
      properties = {};
      final props = schema['properties'] as Map<String, dynamic>;
      props.forEach((key, value) {
        properties![key] = _convertJsonSchema(value as Map<String, dynamic>);
      });
    }

    List<String>? requiredProperties;
    if (schema.containsKey('required')) {
      requiredProperties = (schema['required'] as List<dynamic>).cast<String>();
    }

    Schema? items;
    if (schema.containsKey('items')) {
      items = _convertJsonSchema(schema['items'] as Map<String, dynamic>);
    }

    return Schema(
      type,
      description: schema['description'] as String?,
      properties: properties,
      requiredProperties: requiredProperties,
      items: items,
    );
  }
  List<FunctionDeclaration> _getAdvancedTools() {
    return [
      FunctionDeclaration(
        'wiki_open_file',
        'Ouvrir un fichier du wiki dans l''éditeur.',
        Schema.object(properties: {
          'filePath': Schema.string(description: 'Le chemin relatif du fichier à ouvrir.'),
        }, requiredProperties: ['filePath']),
      ),
      FunctionDeclaration(
        'wiki_write_file',
        'Créer ou écraser un fichier avec du contenu texte.',
        Schema.object(properties: {
          'filePath': Schema.string(description: 'Le chemin relatif du fichier à créer ou modifier.'),
          'content': Schema.string(description: 'Le contenu entier à écrire dans le fichier.'),
          'isGlobal': Schema.boolean(description: 'Optionnel. True pour sauvegarder globalement, sinon false.'),
        }, requiredProperties: ['filePath', 'content']),
      ),
      FunctionDeclaration(
        'wiki_read_file',
        'Lire l''intégralité d''un fichier du wiki.',
        Schema.object(properties: {
          'filePath': Schema.string(description: 'Le chemin relatif du fichier à lire.'),
        }, requiredProperties: ['filePath']),
      ),
      FunctionDeclaration(
        'wiki_append_to_file',
        'Ajouter du texte à la fin d''un fichier.',
        Schema.object(properties: {
          'filePath': Schema.string(description: 'Le chemin relatif du fichier à modifier.'),
          'content': Schema.string(description: 'Le contenu à rajouter.'),
        }, requiredProperties: ['filePath', 'content']),
      ),
      FunctionDeclaration(
        'wiki_insert_in_file',
        'Insérer du texte dans un fichier à un endroit précis (au début, à la fin, ou à une ligne donnée).',
        Schema.object(properties: {
          'filePath': Schema.string(description: 'Le chemin relatif du fichier.'),
          'content': Schema.string(description: 'Le texte à insérer.'),
          'position': Schema.string(description: 'L''endroit où insérer ("start", "end", "line").'),
          'lineNumber': Schema.integer(description: 'Numéro de ligne (1-indexé) si position est "line". Optionnel.'),
        }, requiredProperties: ['filePath', 'content', 'position']),
      ),
      FunctionDeclaration(
        'wiki_list_directory',
        'Lister tous les fichiers et dossiers contenus dans un répertoire.',
        Schema.object(properties: {
          'dirPath': Schema.string(description: 'Le chemin relatif du dossier à lister (laisse vide pour racine).'),
        }, requiredProperties: ['dirPath']),
      ),
      FunctionDeclaration(
        'wiki_create_directory',
        'Créer un nouveau dossier vide.',
        Schema.object(properties: {
          'dirPath': Schema.string(description: 'Le chemin relatif du dossier à créer.'),
        }, requiredProperties: ['dirPath']),
      ),
      FunctionDeclaration(
        'wiki_delete_file',
        'Supprimer un fichier ou un dossier.',
        Schema.object(properties: {
          'path': Schema.string(description: 'Le chemin relatif à supprimer.'),
        }, requiredProperties: ['path']),
      ),
      FunctionDeclaration(
        'wiki_rename_file',
        'Renommer ou déplacer un fichier/dossier.',
        Schema.object(properties: {
          'oldPath': Schema.string(description: 'L''ancien chemin relatif.'),
          'newPath': Schema.string(description: 'Le nouveau chemin relatif.'),
        }, requiredProperties: ['oldPath', 'newPath']),
      ),
    ];
  }
}
