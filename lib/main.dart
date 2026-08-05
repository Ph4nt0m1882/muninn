import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:munnin/src/rust/frb_generated.dart';
import 'package:munnin/src/rust/api/settings.dart';
import 'package:munnin/core/theme/theme.dart';
import 'package:munnin/core/theme/watermark_background.dart';
import 'package:munnin/features/navigation/navigation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:munnin/src/rust/api/fs.dart' as rust_fs;
import 'package:munnin/src/rust/api/search.dart' as rust_search;
import 'package:munnin/src/rust/api/rag.dart' as rust_rag;
import 'package:munnin/src/rust/api/chat.dart' as rust_chat;
import 'package:munnin/features/settings/settings.dart';
import 'package:munnin/features/settings/widgets/api_key_dialog.dart';
import 'package:munnin/features/settings/widgets/app_settings_dialog.dart';
import 'package:munnin/features/settings/services/settings_manager.dart';
import 'package:munnin/core/utils/logger.dart';
import 'package:munnin/core/modules/module_registry.dart';
import 'package:munnin/core/modules/module_config_manager.dart';
import 'package:munnin/core/services/ai_service.dart';
import 'package:munnin/features/editor/editor.dart';
import 'package:munnin/features/explorer/explorer.dart';
import 'package:munnin/core/commands/commands.dart';
import 'package:munnin/features/home/widgets/spotlight_search.dart'
    as import_spotlight;
import 'package:munnin/features/navigation/widgets/top_bar_search.dart'
    as import_top_bar;
import 'package:window_manager/window_manager.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 800),
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden, // Cacher la barre native
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const MunninApp());
}

class MunninApp extends StatefulWidget {
  const MunninApp({super.key});

  @override
  State<MunninApp> createState() => _MunninAppState();
}

class _MunninAppState extends State<MunninApp> {
  int _themeIndex = 0; // 0 = Light, 1 = Dark, etc.
  bool _isSettingsOpen = false;
  String? _currentWikiPath; // Stocke le chemin du wiki ouvert
  List<String> _recentWikis = [];
  final GlobalKey<FileExplorerState> _fileExplorerKey =
      GlobalKey<FileExplorerState>();

  @override
  void initState() {
    super.initState();
    _loadInitialSettings();
    _registerCommands();
    HardwareKeyboard.instance.addHandler(_handleGlobalKeys);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeys);
    super.dispose();
  }

  bool _handleGlobalKeys(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (HardwareKeyboard.instance.isControlPressed) {
        if (event.logicalKey == LogicalKeyboardKey.keyF &&
            HardwareKeyboard.instance.isShiftPressed) {
          CommandManager.instance.execute('app.command_palette');
          return true;
        } else if (event.logicalKey == LogicalKeyboardKey.keyP &&
            HardwareKeyboard.instance.isShiftPressed) {
          import_top_bar.globalSearchFocusNode.requestFocus();
          return true;
        } else if (event.logicalKey == LogicalKeyboardKey.keyS) {
          if (HardwareKeyboard.instance.isShiftPressed) {
            CommandManager.instance.execute('file.save_all');
          } else {
            CommandManager.instance.execute('file.save');
          }
          return true;
        }
      }
    }
    return false;
  }

  void _registerCommands() {
    final cmdManager = CommandManager.instance;

    cmdManager.register(
      AppCommand(
        id: 'app.theme_settings',
        title: 'Changer le thème',
        description: 'Ouvrir les paramètres d\'apparence',
        icon: Icons.palette,
        execute: _openThemeSettings,
      ),
    );

    cmdManager.register(
      AppCommand(
        id: 'app.settings',
        title: 'Paramètres de l\'application',
        description: 'Ouvrir les paramètres généraux',
        icon: Icons.settings,
        execute: () {
          final context = navigatorKey.currentContext;
          if (context != null) {
            AppSettingsDialog.show(context);
          }
        },
      ),
    );

    cmdManager.register(
      AppCommand(
        id: 'app.ai_settings',
        title: 'Configuration IA (Clé API)',
        description: 'Configurer Gemini et les fonctionnalités intelligentes',
        icon: Icons.smart_toy,
        execute: () {
          final context = navigatorKey.currentContext;
          if (context != null) {
            ApiKeyDialog.show(context);
          }
        },
      ),
    );

    cmdManager.register(
      AppCommand(
        id: 'ai.summarize',
        title: 'AI: Résumer',
        description: 'Générer un résumé du document actuel avec Google AI Studio',
        icon: Icons.auto_awesome,
        execute: () async {
          final path = EditorManager.instance.activeFilePath;
          if (path == null) return;
          
          try {
            final content = await File(path).readAsString();
            
            if (content.trim().isEmpty) {
              if (navigatorKey.currentContext != null) {
                ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
                  const SnackBar(content: Text('Le document est vide.')),
                );
              }
              return;
            }

            if (navigatorKey.currentContext != null) {
              ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
                const SnackBar(content: Text('Génération du résumé en cours...')),
              );
            }

            final summary = await AIService.instance.summarize(content);
            
            if (navigatorKey.currentContext != null) {
              showDialog(
                context: navigatorKey.currentContext!,
                builder: (ctx) => AlertDialog(
                  title: const Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.purple),
                      SizedBox(width: 8),
                      Text('Résumé IA'),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Text(summary),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Fermer'),
                    ),
                  ],
                ),
              );
            }
          } catch (e) {
            if (navigatorKey.currentContext != null) {
              ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
                SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
              );
            }
          }
        },
      ),
    );

    cmdManager.register(
      AppCommand(
        id: 'app.command_palette',
        title: 'Recherche Globale (Spotlight)',
        icon: Icons.search,
        shortcutLabel: 'Ctrl+Shift+F',
        execute: () {
          final context = navigatorKey.currentContext;
          if (context != null) {
            import_spotlight.SpotlightSearchDialog.show(context);
          }
        },
      ),
    );

    cmdManager.register(
      AppCommand(
        id: 'wiki.create',
        title: 'Nouveau Wiki...',
        description: 'Créer un nouveau répertoire de connaissances',
        icon: Icons.create_new_folder,
        execute: _createNewWiki,
      ),
    );

    cmdManager.register(
      AppCommand(
        id: 'wiki.pull_welcome_file',
        title: 'Mettre à jour le tutoriel',
        description: 'Récupérer la dernière version du fichier welcome.md',
        icon: Icons.download,
        execute: _pullWelcomeFile,
      ),
    );

    cmdManager.register(
      AppCommand(
        id: 'wiki.settings',
        title: 'Paramètres du Wiki',
        description: 'Ouvrir les paramètres du wiki actuel',
        icon: Icons.settings_applications,
        execute: () {
          if (_currentWikiPath != null) {
            final crowPath = '$_currentWikiPath${Platform.pathSeparator}.crow';
            EditorManager.instance.openFile(crowPath);
          }
        },
      ),
    );

    cmdManager.register(
      AppCommand(
        id: 'wiki.open',
        title: 'Ouvrir un Wiki...',
        description: 'Ouvrir un répertoire existant',
        icon: Icons.folder_open,
        execute: _openExistingWiki,
      ),
    );

    cmdManager.register(
      AppCommand(
        id: 'file.save',
        title: 'Sauvegarder',
        description: 'Sauvegarde le fichier actif',
        icon: Icons.save,
        shortcutLabel: 'Ctrl+S',
        execute: () {
          EditorManager.instance.saveActiveFile();
        },
      ),
    );

    cmdManager.register(
      AppCommand(
        id: 'file.save_all',
        title: 'Sauvegarder tout',
        description: 'Sauvegarde tous les fichiers modifiés',
        icon: Icons.save_alt,
        shortcutLabel: 'Ctrl+Shift+S',
        execute: () {
          EditorManager.instance.saveAll();
        },
      ),
    );

    cmdManager.register(
      AppCommand(
        id: 'editor.mode.markdown',
        title: 'Mode Markdown',
        description: 'Passer l\'onglet actif en mode édition Markdown',
        icon: Icons.code,
        execute: () {
          final path = EditorManager.instance.activeFilePath;
          if (path != null) {
            EditorManager.instance.setFileMode(path, EditorMode.markdown);
          }
        },
      ),
    );

    cmdManager.register(
      AppCommand(
        id: 'editor.mode.render',
        title: 'Mode Rendu',
        description: 'Passer l\'onglet actif en mode lecture (Rendu)',
        icon: Icons.preview,
        execute: () {
          final path = EditorManager.instance.activeFilePath;
          if (path != null) {
            EditorManager.instance.setFileMode(path, EditorMode.render);
          }
        },
      ),
    );

    cmdManager.register(
      AppCommand(
        id: 'editor.mode.markdown_all',
        title: 'Tout en Markdown',
        description: 'Passer tous les onglets en mode édition',
        icon: Icons.integration_instructions,
        execute: () {
          EditorManager.instance.setAllFilesMode(EditorMode.markdown);
        },
      ),
    );

    cmdManager.register(
      AppCommand(
        id: 'editor.mode.render_all',
        title: 'Tout en Rendu',
        description: 'Passer tous les onglets en mode lecture',
        icon: Icons.chrome_reader_mode,
        execute: () {
          EditorManager.instance.setAllFilesMode(EditorMode.render);
        },
      ),
    );
    cmdManager.register(
      AppCommand(
        id: 'wiki.repair',
        title: 'Diagnostiquer & Réparer le Wiki',
        description: 'Vérifie la base de recherche et la répare si besoin',
        icon: Icons.health_and_safety,
        execute: _repairWiki,
      ),
    );

    cmdManager.register(
      AppCommand(
        id: 'wiki.reindex_force',
        title: 'Forcer la Réindexation',
        description: 'Recrée totalement la base de recherche',
        icon: Icons.sync,
        execute: () {
          if (_currentWikiPath != null) {
            _reindexWiki(_currentWikiPath!);
          }
        },
      ),
    );
  }

  Future<void> _repairWiki() async {
    final context = navigatorKey.currentContext;
    if (context == null || _currentWikiPath == null) return;

    try {
      final health = rust_search.checkDbHealth(wikiRoot: _currentWikiPath!);

      if (health.status == 'healthy') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'La base de données est saine. Aucune réparation requise.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Base ${health.status} (${health.message}). Réparation en cours...',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        await _reindexWiki(_currentWikiPath!);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du diagnostic: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _reindexWiki(String path) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final progressNotifier = ValueNotifier<double>(0.0);
    final statusNotifier = ValueNotifier<String>('Préparation...');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(days: 365), // Reste ouvert pendant le process
        content: ValueListenableBuilder<double>(
          valueListenable: progressNotifier,
          builder: (context, progress, _) {
            return ValueListenableBuilder<String>(
              valueListenable: statusNotifier,
              builder: (context, status, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(status),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: progress),
                  ],
                );
              },
            );
          },
        ),
      ),
    );

    try {
      // 1. Indexation texte (FTS) via Rust (très rapide)
      statusNotifier.value = 'Indexation classique (Recherche)...';
      await rust_search.rebuildIndex(wikiRoot: path);

      // 2. Nettoyage de l'ancienne base vectorielle
      statusNotifier.value = 'Nettoyage de la base vectorielle...';
      await rust_rag.clearIndex(wikiRoot: path);

      // Injection du manuel système ligne par ligne dans le RAG
      statusNotifier.value = 'Injection du manuel système...';
      try {
        final manualContent = await rootBundle.loadString('assets/templates/munnin_manual.txt');
        final lines = manualContent.split('\n');
        for (int i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.isNotEmpty) {
            await rust_rag.indexFile(
              wikiRoot: path,
              filePath: '[Système] Notice Ligne ${i + 1}',
              content: line,
            );
          }
        }
      } catch (e) {
        debugPrint('Erreur lors de l\'injection du manuel: $e');
      }

      // 3. Indexation vectorielle (RAG) fichier par fichier pour le progrès
      final dir = Directory(path);
      if (await dir.exists()) {
        final files = await dir.list(recursive: true).where((f) {
          return f is File && 
                 f.path.endsWith('.md') && 
                 !f.path.contains('.git') && 
                 !f.path.contains('.crow');
        }).toList();

        for (int i = 0; i < files.length; i++) {
          final file = files[i] as File;
          final fileName = file.uri.pathSegments.last;
          statusNotifier.value = 'Vecteurs IA (${i + 1}/${files.length}): $fileName';
          progressNotifier.value = (i + 1) / files.length;
          
          // Laisser le temps à l'UI de se mettre à jour
          await Future.delayed(const Duration(milliseconds: 10));
          
          final content = await file.readAsString();
          await rust_rag.indexFile(wikiRoot: path, filePath: file.path, content: content);
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Réindexation totale terminée avec succès !'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la réindexation: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _createNewWiki() async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nouveau Wiki'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: 'Nom du wiki'),
          autofocus: true,
          onSubmitted: (val) => Navigator.pop(context, val),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, nameController.text),
            child: const Text('Créer'),
          ),
        ],
      ),
    );

    if (name == null || name.trim().isEmpty) return;

    String? parentPath = await FilePicker.getDirectoryPath(
      dialogTitle: 'Sélectionner le dossier parent du Wiki',
    );

    if (parentPath == null) return;

    try {
      final newWikiPath = '$parentPath${Platform.pathSeparator}${name.trim()}';
      await rust_fs.initWiki(rootPath: newWikiPath, title: name.trim());

      // --- Génération de la documentation / tutoriel par défaut ---
      final docFile = File('$newWikiPath${Platform.pathSeparator}welcome.md');
      final templateContent = await rootBundle.loadString(
        'assets/templates/welcome.md',
      );
      await docFile.writeAsString(templateContent);
      // -----------------------------------------------------------

      _openWiki(newWikiPath);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _pullWelcomeFile() async {
    if (_currentWikiPath == null) return;

    final context = navigatorKey.currentContext;
    if (context == null) return;

    final docFile = File(
      '$_currentWikiPath${Platform.pathSeparator}welcome.md',
    );

    if (await docFile.exists()) {
      if (!context.mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Fichier existant'),
          content: const Text(
            'Un fichier welcome.md existe déjà à la racine de ce wiki. Voulez-vous vraiment l\'écraser avec la dernière version du tutoriel ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
              ),
              child: const Text('Écraser'),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    try {
      final templateContent = await rootBundle.loadString(
        'assets/templates/welcome.md',
      );
      await docFile.writeAsString(templateContent);

      // Met à jour la version en mémoire si le fichier est déjà ouvert
      EditorManager.instance.updateFileContent(docFile.path, templateContent);
      EditorManager.instance.markAsClean(docFile.path);

      // Rafraîchit l'explorateur pour qu'il affiche le fichier nouvellement créé
      _fileExplorerKey.currentState?.loadTree();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fichier welcome.md récupéré avec succès !'),
          ),
        );
      }

      EditorManager.instance.openFile(docFile.path);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la récupération: $e')),
        );
      }
    }
  }

  Future<void> _openExistingWiki() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      dialogTitle: 'Sélectionner l\'ancre (.crow) du Wiki',
      type: FileType.custom,
      allowedExtensions: ['crow'],
    );

    if (result != null && result.files.single.path != null) {
      final String crowPath = result.files.single.path!;
      final String wikiPath = File(crowPath).parent.path;
      _openWiki(wikiPath);
    }
  }

  void _loadInitialSettings() {
    final settings = loadSettings();
    setState(() {
      _themeIndex = settings.themeIndex;
      // Ne garde que les dossiers qui existent encore sur le disque
      _recentWikis = settings.recentWikis.where((path) {
        return Directory(path).existsSync();
      }).toList();
    });

    // Note: Pour nettoyer le fichier de config JSON définitivement, il faudra
    // exposer une méthode `remove_recent_wiki` ou `save_settings` côté Rust (RustLib).
  }

  void _setTheme(int index) {
    setState(() {
      _themeIndex = index;
    });
    saveTheme(index: index);
  }

  void _openThemeSettings() {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paramètres d\'Apparence'),
        content: SizedBox(
          width: 800,
          height: 600,
          child: ThemeSelectionScreen(
            initialIndex: _themeIndex,
            onThemeSelected: _setTheme,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _closeThemeSettings() {
    setState(() {
      _isSettingsOpen = false;
    });
  }

  void _openWiki(String path) {
    setState(() {
      _currentWikiPath = path;
    });
    EditorManager.instance.wikiRoot = path;
    addRecentWiki(wikiPath: path);

    // Initialise les paramètres du wiki
    SettingsManager.instance.loadSettings(path);

    // Initialise la base de données de recherche pour ce wiki
    try {
      rust_search.initSearchDb(wikiRoot: path);
      rust_chat.initChatDb(wikiRoot: path);
    } catch (e) {
      debugPrint("Erreur lors de l'initialisation de la base de données: $e");
    }

    ModuleConfigManager.instance.loadConfig(path).then((_) {
      // Informe les modules que le wiki est ouvert
      for (var module in ModuleRegistry.instance.modules) {
        module.onWikiOpened(path).catchError((e) {
          debugPrint("Erreur lors de l'initialisation du module ${module.name}: $e");
        });
      }
    });

    _loadInitialSettings(); // Rafraîchit l'historique
  }

  void _openEditor() {
    // Force la vue éditeur (ferme potentiellement d'autres choses plus tard)
  }

  @override
  Widget build(BuildContext context) {
    final currentCrowStyle = BuiltinThemes.all[_themeIndex];
    final themeData = ThemeManager.buildThemeData(currentCrowStyle);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Munnin Wiki',
      debugShowCheckedModeBanner: false,
      theme: themeData,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(0.95),
          ),
          child: child!,
        );
      },
      home: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile =
              constraints.maxWidth < ResponsiveLayout.mobileBreakpoint;

          return Scaffold(
            backgroundColor: currentCrowStyle.ui.backgroundImage != null
                ? Colors.transparent
                : themeData.scaffoldBackgroundColor,
            appBar: const CustomTopBar(),
            // Si mobile, on affiche la BottomBar, sinon rien (car Desktop utilise la LeftSidebar)
            bottomNavigationBar: isMobile
                ? MobileBottomNavigation(
                    onThemeToggle: _openThemeSettings,
                    onOpenEditor: _openEditor,
                  )
                : null,
            // Le body utilise un Stack pour permettre aux fenêtres de flotter au-dessus de l'éditeur
            body: Stack(
              children: [
                // Couche de Fond (Image Filigrane Bicolore)
                if (currentCrowStyle.ui.backgroundImage != null)
                  Positioned.fill(
                    child: Container(
                      color: themeData.scaffoldBackgroundColor,
                      child: WatermarkBackground(
                        imagePath: currentCrowStyle.ui.backgroundImage!,
                        inkColor: themeData.colorScheme.onSurface,
                        opacity: currentCrowStyle.ui.backgroundImageOpacity,
                      ),
                    ),
                  ),

                // Couche 0 : Le Layout de fond (Editeur ou Accueil)
                ResponsiveLayout(
                  onThemeToggle: _openThemeSettings,
                  onOpenEditor: _openEditor,
                  rightSidebar: _currentWikiPath != null
                      ? RightSidebar(
                          wikiRoot: _currentWikiPath!,
                          explorerKey: _fileExplorerKey,
                        )
                      : null,
                  child: _currentWikiPath == null
                      ? WelcomeScreen(
                          onWikiOpened: _openWiki,
                          recentWikis: _recentWikis,
                        )
                      : const MarkdownEditor(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
