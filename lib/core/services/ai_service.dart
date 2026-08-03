import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:munnin/src/rust/api/settings.dart';
import 'package:munnin/src/rust/api/rag.dart';
import 'package:munnin/core/utils/logger.dart';

class AIService {
  static final AIService instance = AIService._internal();
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

      if (finalPrompt.trim().isEmpty) return null;
      return Content.system(finalPrompt);
    } catch (e) {
      AppLogger.w("Impossible de charger les system prompts: $e");
      return null;
    }
  }

  /// Appelle l'API Gemini pour converser en utilisant l'historique
  Future<String> chat(String message, List<Content> history, {String? actionPrefix, required String wikiRoot}) async {
    final settings = loadSettings();
    final apiKey = settings.googleApiKey;

    if (apiKey == null || apiKey.isEmpty) {
      throw Exception("Clé d'API manquante. Veuillez la configurer dans la palette de commandes.");
    }

    // 1. Charger les instructions système basiques
    var systemInstruction = await _buildSystemInstruction(actionPrefix);
    
    // 2. Recherche vectorielle (RAG) dans le wiki
    try {
      final searchResults = await searchSimilar(wikiRoot: wikiRoot, query: message, limit: BigInt.from(5));
      
      if (searchResults.isNotEmpty) {
        String ragContext = "\n\n--- CONTEXTE WIKI PERTINENT ---\n";
        ragContext += "Voici des extraits du wiki de l'utilisateur qui pourraient t'aider à répondre:\n\n";
        for (var chunk in searchResults) {
          ragContext += "Fichier: ${chunk.filePath}\nExtrait:\n${chunk.chunkText}\n\n";
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

    // On crée une instance locale du modèle pour lui passer la bonne systemInstruction (dépendante de l'action)
    final chatModel = GenerativeModel(
      model: 'gemini-3.5-flash-lite',
      apiKey: apiKey,
      systemInstruction: systemInstruction,
    );

    try {
      final chatSession = chatModel.startChat(history: history);
      final response = await chatSession.sendMessage(Content.text(message));
      return response.text ?? "Aucune réponse générée.";
    } catch (e) {
      AppLogger.e("Erreur de l'API Gemini (Chat) : $e");
      rethrow;
    }
  }
}
