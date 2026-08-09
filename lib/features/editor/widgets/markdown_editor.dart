import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:muninn/features/editor/editor.dart';
import 'package:muninn/features/editor/widgets/icon_picker_widget.dart';
import 'package:muninn/features/editor/widgets/editor_toolbar.dart';
import 'package:muninn/features/settings/settings.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/styles/monokai-sublime.dart';
import 'package:muninn/features/editor/utils/markdown_chunk_analyzer.dart';
import 'package:muninn/features/editor/widgets/hover_chunk_indicator.dart';
import 'package:muninn/features/editor/utils/patched_markdown_syntax.dart';
import 'package:muninn/features/editor/widgets/local_search_widget.dart';
import 'package:muninn/core/commands/commands.dart';

import 'package:muninn/features/editor/widgets/interactive_code_block.dart';
import 'package:muninn/features/editor/widgets/welcome_screen.dart';
import 'package:muninn/features/editor/widgets/metadata_dialog.dart';
import 'package:muninn/features/editor/models/file_metadata.dart';

import 'package:muninn/core/theme/theme_manager.dart';
import 'package:muninn/features/editor/utils/custom_monokai_theme.dart';

class MarkdownEditor extends StatefulWidget {
  const MarkdownEditor({super.key});

  @override
  State<MarkdownEditor> createState() => _MarkdownEditorState();
}

class _MarkdownEditorState extends State<MarkdownEditor> {
  late CodeLineEditingController _textController;
  final CodeScrollController _scrollController = CodeScrollController();
  Timer? _autoSaveTimer;

  @override
  void initState() {
    super.initState();
    _textController = CodeLineEditingController.fromText('');
    // Listen for code changes internally
    _textController.addListener(_onCodeChanged);

    EditorManager.instance.addListener(_onEditorStateChanged);
    SettingsManager.instance.addListener(_onSettingsChanged);
    _syncController();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    SettingsManager.instance.removeListener(_onSettingsChanged);
    _autoSaveTimer?.cancel();
    EditorManager.instance.removeListener(_onEditorStateChanged);
    _textController.removeListener(_onCodeChanged);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onEditorStateChanged() {
    _syncController();
    if (mounted) setState(() {});
  }

  void _onCodeChanged() {
    final activePath = EditorManager.instance.activeFilePath;
    if (activePath != null) {
      if (_textController.text != EditorManager.instance.activeFile?.content) {
        EditorManager.instance.updateFileContent(
          activePath,
          _textController.text,
        );

        // Auto-save logic
        final isAutoSaveEnabled = SettingsManager.instance.getValue(
          'editor.autoSave',
          true,
        );
        if (isAutoSaveEnabled) {
          _autoSaveTimer?.cancel();
          _autoSaveTimer = Timer(const Duration(seconds: 2), () {
            EditorManager.instance.saveActiveFile();
          });
        }
      }
    }
  }

  CodeLineSelection _getSelectionFromOffsets(int start, int end) {
    final lines = _textController.codeLines;
    int currentOffset = 0;

    int baseIndex = 0;
    int baseOffset = 0;
    int extentIndex = 0;
    int extentOffset = 0;

    for (int i = 0; i < lines.length; i++) {
      final lineLength = lines[i].text.length + 1; // +1 pour le \n

      if (start >= currentOffset && start < currentOffset + lineLength) {
        baseIndex = i;
        baseOffset = start - currentOffset;
      }

      if (end >= currentOffset && end <= currentOffset + lineLength) {
        extentIndex = i;
        extentOffset = end - currentOffset;
        if (extentOffset == lineLength) {
          extentOffset = lines[i].text.length;
        }
      }
      currentOffset += lineLength;
    }

    return CodeLineSelection(
      baseIndex: baseIndex,
      baseOffset: baseOffset,
      extentIndex: extentIndex,
      extentOffset: extentOffset,
    );
  }

  void _syncController() {
    final activeFile = EditorManager.instance.activeFile;
    if (activeFile != null) {
      if (_textController.text != activeFile.content) {
        _textController.text = activeFile.content;
      }

      if (activeFile.teleportTarget != null) {
        final target = activeFile.teleportTarget!;
        activeFile.teleportTarget = null; // On consomme la cible

        // On attend la prochaine frame pour que le layout soit fait
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _textController.selection = _getSelectionFromOffsets(
              target.startOffset,
              target.endOffset,
            );
          }
        });
      }
    } else {
      _textController.text = '';
    }
  }

  void _insertText(String textToInsert) {
    final selection = _textController.value.selection;
    if (selection.baseIndex >= 0 && selection.extentIndex >= 0) {
      final lines = _textController.codeLines;

      int absoluteBase = 0;
      for (int i = 0; i < selection.baseIndex; i++) {
        absoluteBase += lines[i].text.length + 1;
      }
      absoluteBase += selection.baseOffset;

      int absoluteExtent = 0;
      for (int i = 0; i < selection.extentIndex; i++) {
        absoluteExtent += lines[i].text.length + 1;
      }
      absoluteExtent += selection.extentOffset;

      final start = absoluteBase < absoluteExtent
          ? absoluteBase
          : absoluteExtent;
      final end = absoluteBase > absoluteExtent ? absoluteBase : absoluteExtent;

      final currentText = _textController.text;
      if (start >= 0 && end <= currentText.length) {
        final newText = currentText.replaceRange(start, end, textToInsert);
        _textController.text = newText;
      }
    } else {
      final newText = _textController.text + textToInsert;
      _textController.text = newText;
    }
  }

  void _openIconPicker() {
    IconPickerWidget.show(context, (iconName, library) {
      final currentPosition = _textController.selection.baseOffset;

      final content = (library == 'symbol' || library == 'emoji')
          ? iconName
          : ':$library-$iconName:';

      if (currentPosition >= 0) {
        _insertText(content);
      }
    });
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (event.logicalKey == LogicalKeyboardKey.tab) {
        _insertText('  ');
        return KeyEventResult.handled;
      }
      
      // Ctrl+Y pour Redo
      if (event.logicalKey == LogicalKeyboardKey.keyY && HardwareKeyboard.instance.isControlPressed) {
        _textController.redo();
        return KeyEventResult.handled;
      }
      
      // Wrapping characters around selection
      if (event.character != null) {
        final char = event.character!;
        final wrapChars = {'*': '*', '_': '_', '"': '"', '\'': '\'', '(': ')', '[': ']', '{': '}', r'$': r'$'};
        
        if (wrapChars.containsKey(char)) {
          final selection = _textController.selection;
          
          if (selection.baseIndex >= 0 && selection.extentIndex >= 0) {
            final isCollapsed = selection.baseIndex == selection.extentIndex && selection.baseOffset == selection.extentOffset;
            
            // Si la sélection est vide, on fait de l'auto-close (sauf pour l'apostrophe)
            if (isCollapsed) {
              if (char != '\'') {
                final closingChar = wrapChars[char]!;
                _insertText('$char$closingChar');
                
                // On recule le curseur d'un caractère pour le placer au milieu
                Future.microtask(() {
                  _textController.selection = selection.copyWith(
                    baseOffset: selection.baseOffset + 1,
                    extentOffset: selection.extentOffset + 1,
                  );
                });
                return KeyEventResult.handled;
              }
            } 
            // Si on a une vraie sélection, on enveloppe
            else {
              final lines = _textController.codeLines;
              int absoluteBase = 0;
              for (int i = 0; i < selection.baseIndex; i++) {
                absoluteBase += lines[i].text.length + 1;
              }
              absoluteBase += selection.baseOffset;
              
              int absoluteExtent = 0;
              for (int i = 0; i < selection.extentIndex; i++) {
                absoluteExtent += lines[i].text.length + 1;
              }
              absoluteExtent += selection.extentOffset;
              
              final start = absoluteBase < absoluteExtent ? absoluteBase : absoluteExtent;
              final end = absoluteBase > absoluteExtent ? absoluteBase : absoluteExtent;
              
              final currentText = _textController.text;
              if (start >= 0 && end <= currentText.length) {
                final selectedText = currentText.substring(start, end);
                final newText = currentText.replaceRange(start, end, '$char$selectedText${wrapChars[char]}');
                _textController.text = newText;
                
                bool baseIsStart = selection.baseIndex < selection.extentIndex || 
                                  (selection.baseIndex == selection.extentIndex && selection.baseOffset <= selection.extentOffset);
                
                int newBaseOffset = selection.baseOffset;
                int newExtentOffset = selection.extentOffset;

                if (selection.baseIndex == selection.extentIndex) {
                   newBaseOffset++;
                   newExtentOffset++;
                } else {
                   if (baseIsStart) {
                      newBaseOffset++;
                   } else {
                      newExtentOffset++;
                   }
                }
                
                Future.microtask(() {
                  _textController.selection = selection.copyWith(
                     baseOffset: newBaseOffset,
                     extentOffset: newExtentOffset,
                  );
                });
                return KeyEventResult.handled;
              }
            }
          }
        }
      }
    }
    return KeyEventResult.ignored;
  }

  Future<void> _handleImageImport(String src, String alt) async {
    final activePath = EditorManager.instance.activeFilePath;
    if (activePath == null) return;

    try {
      final fileDir = Directory(p.dirname(activePath));
      final assetsDir = Directory(p.join(fileDir.path, '.assets'));
      if (!await assetsDir.exists()) {
        await assetsDir.create(recursive: true);
      }

      final uri = Uri.tryParse(src);
      if (uri == null) return;

      String fileName = p.basename(uri.path);
      if (fileName.isEmpty || !fileName.contains('.')) {
        fileName = 'image_${DateTime.now().millisecondsSinceEpoch}.png';
      }

      final destinationPath = p.join(assetsDir.path, fileName);
      final destFile = File(destinationPath);

      if (src.startsWith('http')) {
        final client = HttpClient();
        final request = await client.getUrl(uri);
        final response = await request.close();
        if (response.statusCode == 200) {
          await response.pipe(destFile.openWrite());
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Échec du téléchargement: ${response.statusCode}")),
            );
          }
          return;
        }
      } else {
        // Chemin local
        final localFile = File(src);
        if (await localFile.exists()) {
          await localFile.copy(destinationPath);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Le fichier local n'existe pas.")),
          );
          return;
        }
      }

      final memoryContent = EditorManager.instance.activeFile?.content ?? '';
      
      // Attention aux caractères d'échappement dans oldTagText
      final oldTagText = '!![$alt]($src)';
      final newSrc = '.assets/$fileName';
      final newTagText = '!![$alt]($newSrc)'; // On garde !! selon la demande de l'utilisateur
      
      if (memoryContent.contains(oldTagText)) {
        final newMemoryContent = memoryContent.replaceAll(oldTagText, newTagText);
        EditorManager.instance.updateFileContent(activePath, newMemoryContent);
        
        final file = File(activePath);
        await file.writeAsString(newMemoryContent);
        EditorManager.instance.markAsClean(activePath);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image importée avec succès !')),
          );
        }
      }
    } catch (e) {
      debugPrint("Erreur lors de l'import de l'image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur d'import : $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final manager = EditorManager.instance;
    final currentStyle = theme.extension<CrowStyleExtension>()!.style;
    final openedFiles = manager.openedFiles;

    if (openedFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit_document, size: 64, color: theme.dividerColor),
            const SizedBox(height: 16),
            Text(
              'Aucun fichier ouvert',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Global Editor Toolbar (always visible above tabs)
        EditorToolbar(onIconPickerPressed: _openIconPicker),

        // Tabs
        Container(
          height: 40,
          color: theme.colorScheme.surface,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: openedFiles.length,
            itemBuilder: (context, index) {
              final file = openedFiles[index];
              final isActive = file.path == manager.activeFilePath;

              return _EditorTab(
                file: file,
                isActive: isActive,
                onTap: () => manager.openFile(file.path),
                onClose: () => manager.closeFile(file.path),
              );
            },
          ),
        ),

        // Editor Area
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: manager.activeFile?.mode == EditorMode.settings
                  ? const WikiSettingsScreen()
                  : manager.activeFile?.mode == EditorMode.render
                  ? CallbackShortcuts(
                      bindings: {
                        const SingleActivator(
                          LogicalKeyboardKey.keyF,
                          control: true,
                        ): () {
                          CommandManager.instance.execute(
                            'app.command_palette',
                          );
                        },
                      },
                      child: Focus(
                        autofocus: true,
                        child: MarkdownRenderer(
                          content: manager.activeFile?.content ?? '',
                          filePath: manager.activeFilePath,
                          onCheckboxToggled: (id, newState) async {
                            final activePath = manager.activeFilePath;
                            if (activePath == null) return;
                            final memoryContent =
                                manager.activeFile?.content ?? '';

                            // On masque les blocs de code pour ne pas fausser l'index des ID
                            final maskedContent = memoryContent.replaceAllMapped(
                              RegExp(r'```.*?```', multiLine: true, dotAll: true),
                              (m) => ' ' * m.group(0)!.length,
                            );

                            final regExp = RegExp(
                              r'^(\s*-\s+)\[([ xXvV\*])\]',
                              multiLine: true,
                            );
                            final matches = regExp
                                .allMatches(maskedContent)
                                .toList();
                            if (id >= 0 && id < matches.length) {
                              final memMatch = matches[id];
                              final prefix = memMatch.group(1)!;

                              // Calcul de la ligne exacte
                              int lineStart = memoryContent.lastIndexOf(
                                '\n',
                                memMatch.start,
                              );
                              lineStart = lineStart == -1 ? 0 : lineStart + 1;
                              int lineEnd = memoryContent.indexOf(
                                '\n',
                                memMatch.end,
                              );
                              if (lineEnd == -1) lineEnd = memoryContent.length;
                              final originalLine = memoryContent.substring(
                                lineStart,
                                lineEnd,
                              );

                              int lineNumber = '\n'
                                  .allMatches(
                                    memoryContent.substring(0, memMatch.start),
                                  )
                                  .length;

                              final wasDirty =
                                  manager.activeFile?.isDirty ?? false;

                              // Remplacement en mémoire
                              final newMemoryContent = memoryContent
                                  .replaceRange(
                                    memMatch.start,
                                    memMatch.end,
                                    '$prefix[$newState]',
                                  );
                              EditorManager.instance.updateFileContent(
                                activePath,
                                newMemoryContent,
                              );

                              // Tentative de sauvegarde silencieuse sur le disque
                              try {
                                final file = File(activePath);
                                if (await file.exists()) {
                                  if (!wasDirty) {
                                    // Le fichier n'avait aucune autre modification. On sauvegarde tout et on efface l'astérisque.
                                    await file.writeAsString(newMemoryContent);
                                    EditorManager.instance.markAsClean(
                                      activePath,
                                    );
                                  } else {
                                    // Le fichier a d'autres modifications en cours. Sauvegarde partielle de la ligne uniquement.
                                    final diskContent = await file
                                        .readAsString();
                                    List<String> diskLines = diskContent.split(
                                      '\n',
                                    );

                                    if (lineNumber < diskLines.length) {
                                      String cleanDiskLine =
                                          diskLines[lineNumber].replaceAll(
                                            '\r',
                                            '',
                                          );
                                      String cleanOriginalLine = originalLine
                                          .replaceAll('\r', '');

                                      // Si la ligne correspond exactement, on remplace sur le disque
                                      if (cleanDiskLine == cleanOriginalLine) {
                                        bool hasCr = diskLines[lineNumber]
                                            .endsWith('\r');
                                        String newLine = cleanOriginalLine
                                            .replaceFirst(
                                              RegExp(r'\[([ xXvV\*])\]'),
                                              '[$newState]',
                                            );
                                        if (hasCr) newLine += '\r';

                                        diskLines[lineNumber] = newLine;
                                        await file.writeAsString(
                                          diskLines.join('\n'),
                                        );
                                      }
                                    }
                                  }
                                }
                              } catch (e) {
                                  debugPrint(
                                    "Erreur de sauvegarde silencieuse: $e",
                                  );
                                }
                              }
                            },
                            onImageImportRequested: (src, alt) => _handleImageImport(src, alt),
                          ),
                        ),
                      )
                  : CallbackShortcuts(
                      bindings: {
                        const SingleActivator(
                          LogicalKeyboardKey.keyI,
                          control: true,
                          shift: true,
                        ): _openIconPicker,
                      },
                      child: Focus(
                        autofocus: true,
                        onKeyEvent: _onKeyEvent,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: CodeEditor(
                                autocompleteSymbols: false,
                                controller: _textController,
                                scrollController: _scrollController,
                                style: CodeEditorStyle(
                                  fontFamily: 'Consolas',
                                  fontSize: 14,
                                  fontHeight: currentStyle.ui.lineHeight,
                                  codeTheme: CodeHighlightTheme(
                                    languages: {
                                      'markdown': CodeHighlightThemeMode(
                                        mode: getPatchedMarkdownSyntax(),
                                      ),
                                    },
                                    theme: getCustomMarkdownTheme(currentStyle.ui.markdownTheme),
                                  ),
                                ),
                                wordWrap: true,
                                indicatorBuilder:
                                    (
                                      context,
                                      editingController,
                                      chunkController,
                                      notifier,
                                    ) {
                                      return Row(
                                        children: [
                                          DefaultCodeLineNumber(
                                            controller: editingController,
                                            notifier: notifier,
                                          ),
                                          HoverCodeChunkIndicator(
                                            controller: chunkController,
                                            notifier: notifier,
                                          ),
                                        ],
                                      );
                                    },
                                chunkAnalyzer: const MarkdownChunkAnalyzer(),
                                scrollbarBuilder: (context, child, details) =>
                                    child,
                                findBuilder: (context, controller, readOnly) =>
                                    LocalSearchWidget(
                                      controller: controller,
                                      readOnly: readOnly,
                                    ),
                              ),
                            ),
                            _CustomScrollbar(
                              textController: _textController,
                              mainScrollController: _scrollController,
                              showMinimapText: SettingsManager.instance
                                  .getValue('editor.minimap.enabled', false),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EditorTab extends StatefulWidget {
  final OpenedFile file;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _EditorTab({
    required this.file,
    required this.isActive,
    required this.onTap,
    required this.onClose,
  });

  @override
  State<_EditorTab> createState() => _EditorTabState();
}

class _EditorTabState extends State<_EditorTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideSizeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    if (widget.file.openAnimation != TabOpenAnimation.none) {
      if (widget.file.openAnimation == TabOpenAnimation.normal) {
        _slideSizeAnimation = CurvedAnimation(
          parent: _controller,
          curve: Curves.easeOutCubic,
        );
        _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
        );
      } else if (widget.file.openAnimation == TabOpenAnimation.raven) {
        _slideSizeAnimation = const AlwaysStoppedAnimation(1.0);
        _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
          CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
        );
      }
      _controller.forward().then((_) {
        if (mounted) {
          widget.file.openAnimation = TabOpenAnimation.none;
        }
      });
    } else {
      _slideSizeAnimation = const AlwaysStoppedAnimation(1.0);
      _scaleAnimation = const AlwaysStoppedAnimation(1.0);
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final theme = Theme.of(context);
        final bgColor = widget.isActive
            ? theme.scaffoldBackgroundColor
            : theme.colorScheme.surface;
        final textColor = widget.isActive
            ? theme.textTheme.bodyLarge?.color
            : theme.textTheme.bodySmall?.color;

        final isNormalAnim =
            widget.file.openAnimation == TabOpenAnimation.normal &&
            _controller.isAnimating;
        final isRavenAnim =
            widget.file.openAnimation == TabOpenAnimation.raven &&
            _controller.isAnimating;

        Color? currentBgColor = bgColor;
        if (isNormalAnim) {
          final darkColor = theme.brightness == Brightness.dark
              ? Colors.black
              : Colors.grey.shade300;
          currentBgColor = Color.lerp(darkColor, bgColor, _controller.value);
        }

        Widget tabContent = Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: currentBgColor,
            border: Border(
              right: BorderSide(color: theme.dividerColor, width: 1),
              top: BorderSide(
                color: widget.isActive
                    ? theme.colorScheme.primary
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icône de mode
              if (widget.file.mode == EditorMode.settings)
                Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: Icon(
                    Icons.settings,
                    size: 14,
                    color: textColor?.withValues(alpha: 0.8),
                  ),
                )
              else
                InkWell(
                  onTap: () {
                    final newMode = widget.file.mode == EditorMode.markdown
                        ? EditorMode.render
                        : EditorMode.markdown;
                    EditorManager.instance.setFileMode(
                      widget.file.path,
                      newMode,
                    );
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: Icon(
                      widget.file.mode == EditorMode.render
                          ? Icons.preview
                          : Icons.code,
                      size: 14,
                      color: textColor?.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              // Nom du fichier avec gestion des métadonnées
              InkWell(
                onTap: widget.file.path.toLowerCase().endsWith('.md') && widget.file.metadata?.status != NoteStatus.system
                    ? () {
                        showDialog(
                          context: context,
                          builder: (context) => MetadataDialog(file: widget.file),
                        );
                      }
                    : null,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                  child: Text(
                    widget.file.name + (widget.file.isDirty ? ' *' : ''),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: textColor,
                      fontWeight: widget.isActive
                          ? FontWeight.w600
                          : FontWeight.normal,
                      fontStyle: widget.file.isDirty
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Bouton fermer
              InkWell(
                onTap: widget.onClose,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: textColor?.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        );

        if (isNormalAnim) {
          tabContent = ClipRect(
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: _slideSizeAnimation.value,
              child: FractionalTranslation(
                translation: Offset(_slideSizeAnimation.value - 1.0, 0),
                child: tabContent,
              ),
            ),
          );
        } else if (isRavenAnim) {
          tabContent = Stack(
            alignment: Alignment.center,
            children: [
              ScaleTransition(scale: _scaleAnimation, child: tabContent),
              if (_controller.value < 0.8)
                Positioned.fill(
                  child: ClipRect(
                    child: Transform.scale(
                      scale: _controller.value * 3.0,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(
                            alpha: 0.4 * (1.0 - (_controller.value / 0.8)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        }

        return InkWell(onTap: widget.onTap, child: tabContent);
      },
    );
  }
}

class _CustomScrollbar extends StatefulWidget {
  final CodeLineEditingController textController;
  final CodeScrollController mainScrollController;
  final bool showMinimapText;

  const _CustomScrollbar({
    required this.textController,
    required this.mainScrollController,
    this.showMinimapText = true,
  });

  @override
  State<_CustomScrollbar> createState() => _CustomScrollbarState();
}

class _CustomScrollbarState extends State<_CustomScrollbar> {
  final CodeScrollController _minimapScrollController = CodeScrollController();
  double _sliderTop = 0;
  double _sliderHeight = 0;
  bool _isDragging = false;

  static const double _scaleRatio = 14.0 / 3.5; // 4.0

  @override
  void initState() {
    super.initState();
    widget.mainScrollController.verticalScroller.addListener(_syncFromMain);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncFromMain());
  }

  @override
  void dispose() {
    widget.mainScrollController.verticalScroller.removeListener(_syncFromMain);
    _minimapScrollController.dispose();
    super.dispose();
  }

  void _syncFromMain() {
    if (!widget.mainScrollController.verticalScroller.hasClients) return;

    final mainPos = widget.mainScrollController.verticalScroller.position;
    final mainOffset = mainPos.pixels;
    final mainViewport = mainPos.viewportDimension;

    final newSliderHeight = mainViewport / _scaleRatio;

    final sliderMaxTop = mainViewport - newSliderHeight;
    final percent = mainPos.maxScrollExtent > 0
        ? (mainOffset / mainPos.maxScrollExtent).clamp(0.0, 1.0)
        : 0.0;
    final newSliderTop = percent * sliderMaxTop;

    if (widget.showMinimapText) {
      double miniOffset = (mainOffset / _scaleRatio) - newSliderTop;
      if (_minimapScrollController.verticalScroller.hasClients) {
        final miniPos = _minimapScrollController.verticalScroller.position;
        miniOffset = miniOffset.clamp(0.0, miniPos.maxScrollExtent);
        if ((miniPos.pixels - miniOffset).abs() > 0.5) {
          _minimapScrollController.verticalScroller.jumpTo(miniOffset);
        }
      }
    }

    if (_sliderTop != newSliderTop || _sliderHeight != newSliderHeight) {
      setState(() {
        _sliderTop = newSliderTop;
        _sliderHeight = newSliderHeight;
      });
    }
  }

  void _onGesture(double localY) {
    if (!widget.mainScrollController.verticalScroller.hasClients) return;

    double miniOffset = 0;
    if (widget.showMinimapText &&
        _minimapScrollController.verticalScroller.hasClients) {
      miniOffset = _minimapScrollController.verticalScroller.position.pixels;
    } else {
      // Si la minimap text n'est pas affichée, la position locale de la souris correspond
      // directement à un pourcentage de l'écran, ce qui nous permet de trouver le point central
      // Wait, if no minimap text, we can just map the localY to the sliderTop directly.
      // Or we can use the same logic if we pretend miniOffset is 0.
      // But actually, it's easier to map localY directly to the document percent.
    }

    final mainPos = widget.mainScrollController.verticalScroller.position;
    final mainViewport = mainPos.viewportDimension;

    if (!widget.showMinimapText) {
      // Simple scrollbar calculation
      final sliderMaxTop = mainViewport - _sliderHeight;
      if (sliderMaxTop <= 0) return;
      final percent = (localY - (_sliderHeight / 2)) / sliderMaxTop;
      final targetMainOffset =
          percent.clamp(0.0, 1.0) * mainPos.maxScrollExtent;
      widget.mainScrollController.verticalScroller.jumpTo(targetMainOffset);
      return;
    }

    final contentY = localY + miniOffset;
    final mainTargetCenter = contentY * _scaleRatio;

    double targetMainOffset = mainTargetCenter - (mainViewport / 2);
    targetMainOffset = targetMainOffset.clamp(0.0, mainPos.maxScrollExtent);

    widget.mainScrollController.verticalScroller.jumpTo(targetMainOffset);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentStyle = theme.extension<CrowStyleExtension>()!.style;
    final width = widget.showMinimapText ? 120.0 : 16.0;

    return Container(
      width: width,
      decoration: BoxDecoration(color: theme.scaffoldBackgroundColor),
      child: Stack(
        children: [
          // Minimap Editor Text
          if (widget.showMinimapText)
            Opacity(
              opacity: 0.8,
              child: IgnorePointer(
                child: CodeEditor(
                  autocompleteSymbols: false,
                  controller: widget.textController,
                  scrollController: _minimapScrollController,
                  scrollbarBuilder: (context, child, details) => child,
                  readOnly: true,
                  style: CodeEditorStyle(
                    fontFamily: 'Consolas',
                    fontSize: 3.5,
                    fontHeight: currentStyle.ui.lineHeight,
                    codeTheme: CodeHighlightTheme(
                      languages: {
                        'markdown': CodeHighlightThemeMode(
                          mode: getPatchedMarkdownSyntax(),
                        ),
                      },
                      theme: getCustomMarkdownTheme(currentStyle.ui.markdownTheme),
                    ),
                  ),
                  wordWrap: true,
                ),
              ),
            ),

          // Background Slider (only for minimap)
          if (widget.showMinimapText && _sliderHeight > 0)
            Positioned(
              top: _sliderTop,
              left: 0,
              right: 0,
              height: _sliderHeight,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                    border: Border.all(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),

          // Real Thumb (The solid bar on the right)
          if (_sliderHeight > 0)
            Positioned(
              top: _sliderTop,
              right: 2, // 2px margin from right edge
              width: widget.showMinimapText
                  ? 8.0
                  : 12.0, // Thicker if no minimap text
              height: _sliderHeight,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(
                      alpha: _isDragging ? 0.4 : 0.2,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),

          // Gesture overlay
          Positioned.fill(
            child: Listener(
              onPointerSignal: (pointerSignal) {
                if (pointerSignal is PointerScrollEvent) {
                  if (widget.mainScrollController.verticalScroller.hasClients) {
                    final pos =
                        widget.mainScrollController.verticalScroller.position;
                    final targetOffset =
                        pos.pixels + pointerSignal.scrollDelta.dy;
                    widget.mainScrollController.verticalScroller.jumpTo(
                      targetOffset.clamp(0.0, pos.maxScrollExtent),
                    );
                  }
                }
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragDown: (details) {
                    setState(() => _isDragging = true);
                    _onGesture(details.localPosition.dy);
                  },
                  onVerticalDragUpdate: (details) {
                    _onGesture(details.localPosition.dy);
                  },
                  onVerticalDragEnd: (_) => setState(() => _isDragging = false),
                  onVerticalDragCancel: () =>
                      setState(() => _isDragging = false),
                  onTapDown: (details) {
                    _onGesture(details.localPosition.dy);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
