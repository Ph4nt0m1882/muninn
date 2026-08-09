import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:muninn/features/editor/services/editor_manager.dart';
import 'package:flutter_highlighter/themes/atom-one-dark.dart';
import 'package:flutter_highlighter/themes/atom-one-light.dart';
import 'package:highlighter/highlighter.dart' show highlight, Node;
import 'package:simple_icons/simple_icons.dart';
import 'package:muninn/core/theme/theme_manager.dart';
import 'package:muninn/features/editor/utils/custom_monokai_theme.dart';
// Contrôleur de texte personnalisé pour la coloration syntaxique en temps réel
class CodeEditingController extends TextEditingController {
  String language;
  final Map<String, TextStyle> theme;

  CodeEditingController({
    required this.language,
    required this.theme,
    super.text,
  });

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (text.isEmpty) return TextSpan(style: style, text: '');

    try {
      var result = highlight.parse(text, language: language);
      return TextSpan(
        style: style,
        children: _convertNodes(result.nodes, theme),
      );
    } catch (e) {
      // Fallback if parsing fails
      return TextSpan(style: style, text: text);
    }
  }

  List<TextSpan> _convertNodes(
    List<Node>? nodes,
    Map<String, TextStyle> theme,
  ) {
    if (nodes == null) return [];
    List<TextSpan> spans = [];
    for (var node in nodes) {
      if (node.value != null) {
        spans.add(
          TextSpan(
            text: node.value,
            style: theme[node.className] ?? const TextStyle(),
          ),
        );
      } else if (node.children != null) {
        spans.add(
          TextSpan(
            style: theme[node.className] ?? const TextStyle(),
            children: _convertNodes(node.children, theme),
          ),
        );
      }
    }
    return spans;
  }
}

class InteractiveCodeBlock extends StatefulWidget {
  final String code;
  final String language;
  final bool isEditable;
  final String? filePath; // Nullable if used in places without file backing

  const InteractiveCodeBlock({
    super.key,
    required this.code,
    required this.language,
    this.isEditable = false,
    this.filePath,
  });

  @override
  State<InteractiveCodeBlock> createState() => _InteractiveCodeBlockState();
}

class _InteractiveCodeBlockState extends State<InteractiveCodeBlock>
    with SingleTickerProviderStateMixin {
  late CodeEditingController _controller;
  late String _currentLanguage;
  late String _originalCode;
  late String _originalLanguage;

  final FocusNode _focusNode = FocusNode();
  late AnimationController _animationController;
  bool _isFocused = false;
  bool _isCopied = false;
  bool _isModified = false;

  final List<String> _commonLanguages = [
    'python',
    'dart',
    'javascript',
    'html',
    'css',
    'json',
    'bash',
    'sql',
    'cpp',
    'rust',
    'markdown',
  ];

  @override
  void initState() {
    super.initState();
    _currentLanguage = widget.language.isEmpty ? 'plaintext' : widget.language;
    _originalLanguage = _currentLanguage;
    _originalCode = widget.code;

    // Fallback theme empty map initially, will be updated in build
    _controller = CodeEditingController(
      language: _currentLanguage,
      theme: {},
      text: widget.code,
    );
    _controller.addListener(_checkModifications);

    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
        if (_isFocused) {
          _animationController.repeat();
        } else {
          _animationController.stop();
        }
      });
    });

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void didUpdateWidget(covariant InteractiveCodeBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the external code changed and we are not focused, update it.
    if (oldWidget.code != widget.code && !_isFocused && !_isModified) {
      _originalCode = widget.code;
      _controller.text = widget.code;
    }
  }

  void _checkModifications() {
    final modified =
        _controller.text != _originalCode ||
        _currentLanguage != _originalLanguage;
    if (_isModified != modified) {
      setState(() {
        _isModified = modified;
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_checkModifications);
    _controller.dispose();
    _focusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _saveModifications() {
    if (widget.filePath == null) return;

    final newCode = _controller.text;

    EditorManager.instance.replaceCodeBlock(
      widget.filePath!,
      _originalCode,
      newCode,
      _originalLanguage,
      _currentLanguage,
    );

    setState(() {
      _originalCode = newCode;
      _originalLanguage = _currentLanguage;
      _isModified = false;
    });

    EditorManager.instance.saveActiveFile();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bloc de code sauvegardé !'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  IconData _getLanguageIcon(String lang) {
    switch (lang.toLowerCase()) {
      case 'python':
        return SimpleIcons.python;
      case 'javascript':
      case 'js':
        return SimpleIcons.javascript;
      case 'typescript':
      case 'ts':
        return SimpleIcons.typescript;
      case 'dart':
        return SimpleIcons.dart;
      case 'html':
        return SimpleIcons.html5;
      case 'css':
        return SimpleIcons.css;
      case 'json':
        return SimpleIcons.json;
      case 'bash':
      case 'sh':
        return SimpleIcons.gnubash;
      case 'sql':
        return SimpleIcons.postgresql;
      case 'cpp':
      case 'c++':
        return SimpleIcons.cplusplus;
      case 'c':
        return SimpleIcons.c;
      case 'csharp':
      case 'c#':
        return Icons.code;
      case 'rust':
        return SimpleIcons.rust;
      case 'java':
        return SimpleIcons.openjdk;
      case 'go':
        return SimpleIcons.go;
      case 'ruby':
        return SimpleIcons.ruby;
      case 'php':
        return SimpleIcons.php;
      case 'swift':
        return SimpleIcons.swift;
      case 'kotlin':
        return SimpleIcons.kotlin;
      case 'markdown':
        return SimpleIcons.markdown;
      default:
        return Icons.code;
    }
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                _getLanguageIcon(_currentLanguage),
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              if (widget.isEditable)
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _commonLanguages.contains(_currentLanguage)
                        ? _currentLanguage
                        : 'plaintext',
                    isDense: true,
                    icon: const Icon(Icons.arrow_drop_down, size: 16),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                    items:
                        [
                          ..._commonLanguages,
                          if (!_commonLanguages.contains(_currentLanguage))
                            'plaintext',
                        ].map((lang) {
                          return DropdownMenuItem(
                            value: lang,
                            child: Text(lang.toUpperCase()),
                          );
                        }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _currentLanguage = val;
                          _controller.language = val;
                        });
                        _checkModifications();
                      }
                    },
                  ),
                )
              else
                Text(
                  _currentLanguage.toUpperCase(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              if (_isModified)
                Padding(
                  padding: const EdgeInsets.only(left: 4.0),
                  child: Text(
                    '*',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),

          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: _isCopied
                  ? const Icon(
                      Icons.check,
                      key: ValueKey('check'),
                      color: Colors.green,
                      size: 16,
                    )
                  : const Icon(Icons.copy, key: ValueKey('copy'), size: 16),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Copier le code',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _controller.text));
              setState(() {
                _isCopied = true;
              });
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  setState(() {
                    _isCopied = false;
                  });
                }
              });
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentStyle = theme.extension<CrowStyleExtension>()!.style;
    final baseTheme = getSyntaxTheme(currentStyle.ui.codeTheme);
    final syntaxTheme = Map<String, TextStyle>.from(baseTheme);

    if (syntaxTheme.containsKey('root')) {
      syntaxTheme['root'] = syntaxTheme['root']!.copyWith(
        backgroundColor: Colors.transparent,
      );
    } else {
      syntaxTheme['root'] = const TextStyle(
        backgroundColor: Colors.transparent,
      );
    }

    _controller.theme.clear();
    _controller.theme.addAll(syntaxTheme);

    final codeTextStyle = TextStyle(
      fontFamily: 'Consolas',
      fontSize: 14.0,
      height: currentStyle.ui.lineHeight,
      color: syntaxTheme['root']?.color ?? theme.textTheme.bodyMedium?.color,
    );

    Widget editorContent;
    if (widget.isEditable) {
      editorContent = Focus(
        onKeyEvent: (node, event) {
          if (HardwareKeyboard.instance.isControlPressed &&
              event.logicalKey == LogicalKeyboardKey.keyS) {
            if (event is KeyDownEvent) {
              _saveModifications();
            }
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.tab) {
            if (event is KeyDownEvent) {
              final text = _controller.text;
              final selection = _controller.selection;
              if (selection.isValid) {
                final newText = text.replaceRange(
                  selection.start,
                  selection.end,
                  '    ',
                );
                _controller.value = TextEditingValue(
                  text: newText,
                  selection: TextSelection.collapsed(
                    offset: selection.start + 4,
                  ),
                );
              }
            }
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: () {
            if (!_focusNode.hasFocus) {
              FocusScope.of(context).requestFocus(_focusNode);
            }
          },
          behavior: HitTestBehavior.translucent,
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            style: codeTextStyle,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(12),
              isDense: true,
            ),
            cursorColor: theme.colorScheme.primary,
          ),
        ),
      );
    } else {
      editorContent = Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        child: SelectableText.rich(
          _controller.buildTextSpan(
            context: context,
            withComposing: false,
            style: codeTextStyle,
          ),
        ),
      );
    }

    final innerContainer = Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [_buildHeader(theme), editorContent],
      ),
    );

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final isFocusedAndEditable = widget.isEditable && _isFocused;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: isFocusedAndEditable
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: SweepGradient(
                    center: FractionalOffset.center,
                    transform: GradientRotation(
                      _animationController.value * 2 * math.pi,
                    ),
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                      theme.colorScheme.primary,
                    ],
                  ),
                )
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.isEditable
                        ? theme.colorScheme.primary.withValues(alpha: 0.3)
                        : theme.dividerColor,
                    width: 1.5,
                  ),
                ),
          padding: isFocusedAndEditable
              ? const EdgeInsets.all(2.0)
              : EdgeInsets.zero,
          child: child,
        );
      },
      child: innerContainer,
    );
  }
}
