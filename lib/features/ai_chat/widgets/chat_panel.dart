import 'package:flutter/material.dart';
import 'package:munnin/src/rust/api/chat.dart' as rust_chat;
import 'package:munnin/core/services/ai_service.dart';
import 'package:munnin/features/editor/widgets/markdown_renderer.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:munnin/features/ai_chat/utils/chat_text_controller.dart';
import 'package:munnin/features/ai_chat/widgets/autocomplete_popup.dart';

class ChatPanel extends StatefulWidget {
  final String wikiRoot;
  
  const ChatPanel({super.key, required this.wikiRoot});

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final TextEditingController _textController = ChatTextController();
  final ScrollController _scrollController = ScrollController();
  
  List<rust_chat.ChatMessage> _messages = [];
  rust_chat.ChatSession? _currentSession;
  bool _isLoading = false;

  AutocompleteMode _autocompleteMode = AutocompleteMode.none;
  String _currentAutocompleteWord = '';
  List<String> _availableCommands = [];
  List<String> _availablePages = [];
  List<String> _availableImages = [];

  @override
  void initState() {
    super.initState();
    _loadRecentSession();
    _textController.addListener(_onTextChanged);
    _loadAutocompleteData();
  }

  Future<void> _loadAutocompleteData() async {
    try {
      final Set<String> commands = {};
      try {
        final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
        final assets = manifest.listAssets();
        for (String key in assets) {
          if (key.startsWith('assets/system_prompts/')) {
            final parts = key.split('/');
            if (parts.length > 3) {
              final folder = parts[2];
              if (RegExp(r'^\d+_').hasMatch(folder)) {
                commands.add(folder.replaceFirst(RegExp(r'^\d+_'), ''));
              }
            }
          }
        }
      } catch (e) {
        debugPrint("Erreur chargement manifest: $e");
      }
      _availableCommands = commands.toList()..sort();

      final dir = Directory(widget.wikiRoot);
      if (await dir.exists()) {
        final files = await dir.list(recursive: true).toList();
        _availablePages = [];
        _availableImages = [];
        for (var file in files) {
          if (file is File) {
            final ext = p.extension(file.path).toLowerCase();
            final relative = p.relative(file.path, from: widget.wikiRoot);
            if (relative.startsWith('.') && !relative.startsWith('.assets')) continue;

            if (ext == '.md') {
              _availablePages.add(relative);
            } else if (['.png', '.jpg', '.jpeg', '.gif', '.webp'].contains(ext)) {
              _availableImages.add(relative);
            }
          }
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Erreur _loadAutocompleteData: $e");
    }
  }

  void _onTextChanged() {
    final text = _textController.text;
    final selection = _textController.selection;
    if (selection.baseOffset == -1) return;

    final cursorPosition = selection.baseOffset;
    final textBeforeCursor = text.substring(0, cursorPosition);
    final words = textBeforeCursor.split(RegExp(r'\s+'));
    final lastWord = words.isNotEmpty ? words.last : '';

    if (lastWord.startsWith('/')) {
      setState(() {
        _autocompleteMode = AutocompleteMode.commands;
        _currentAutocompleteWord = lastWord;
      });
    } else if (lastWord.startsWith('@')) {
      setState(() {
        _autocompleteMode = AutocompleteMode.context;
        _currentAutocompleteWord = lastWord;
      });
    } else {
      if (_autocompleteMode != AutocompleteMode.none) {
        setState(() => _autocompleteMode = AutocompleteMode.none);
      }
    }
  }

  void _insertAutocomplete(String result, {required bool isExternal, required bool isCommand}) {
    final text = _textController.text;
    final selection = _textController.selection;
    final cursorPosition = selection.baseOffset;
    
    final textBeforeCursor = text.substring(0, cursorPosition);
    final words = textBeforeCursor.split(RegExp(r'\s+'));
    final lastWord = words.isNotEmpty ? words.last : '';
    
    final textAfterCursor = text.substring(cursorPosition);
    
    String replacement = '';
    if (isCommand) {
      replacement = '/$result ';
    } else {
      String name = p.basename(result);
      replacement = '@[$name]($result) ';
    }

    final newTextBeforeCursor = textBeforeCursor.substring(0, textBeforeCursor.length - lastWord.length) + replacement;
    
    _textController.value = TextEditingValue(
      text: newTextBeforeCursor + textAfterCursor,
      selection: TextSelection.collapsed(offset: newTextBeforeCursor.length),
    );
    
    setState(() {
      _autocompleteMode = AutocompleteMode.none;
    });
  }

  Future<void> _loadRecentSession() async {
    try {
      final sessions = rust_chat.getChatSessions(wikiRoot: widget.wikiRoot);
      if (sessions.isNotEmpty) {
        _currentSession = sessions.first;
        _messages = rust_chat.getChatMessages(wikiRoot: widget.wikiRoot, sessionId: _currentSession!.id);
        setState(() {});
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint("Erreur chargement session de chat: $e");
    }
  }

  void _showHistoryDialog() {
    final theme = Theme.of(context);
    List<rust_chat.ChatSession> sessions = [];
    try {
      sessions = rust_chat.getChatSessions(wikiRoot: widget.wikiRoot);
    } catch (e) {
      debugPrint("Erreur chargement historique: $e");
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Historique des conversations'),
              content: SizedBox(
                width: 450,
                height: 500,
                child: sessions.isEmpty
                    ? const Center(child: Text("Aucune conversation passée."))
                    : ListView.builder(
                        itemCount: sessions.length,
                        itemBuilder: (context, index) {
                          final session = sessions[index];
                          final date = DateTime.fromMillisecondsSinceEpoch(session.updatedAt);
                          final formattedDate = "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
                          
                          return ListTile(
                            title: Text(session.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(formattedDate),
                            leading: const Icon(Icons.chat_bubble_outline),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'rename') {
                                  final controller = TextEditingController(text: session.title);
                                  final newName = await showDialog<String>(
                                    context: ctx,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Renommer la conversation'),
                                      content: TextField(
                                        controller: controller,
                                        autofocus: true,
                                        decoration: const InputDecoration(hintText: 'Nouveau nom'),
                                      ),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
                                        TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Enregistrer')),
                                      ],
                                    ),
                                  );
                                  
                                  if (newName != null && newName.trim().isNotEmpty) {
                                    try {
                                      rust_chat.renameChatSession(wikiRoot: widget.wikiRoot, sessionId: session.id, newTitle: newName.trim());
                                      setDialogState(() {
                                        sessions = rust_chat.getChatSessions(wikiRoot: widget.wikiRoot);
                                      });
                                    } catch (e) {
                                      debugPrint("Erreur renommage: $e");
                                    }
                                  }
                                } else if (value == 'delete') {
                                  try {
                                    rust_chat.deleteChatSession(wikiRoot: widget.wikiRoot, sessionId: session.id);
                                    setDialogState(() {
                                      sessions.removeWhere((s) => s.id == session.id);
                                    });
                                    if (_currentSession?.id == session.id) {
                                      setState(() {
                                        _currentSession = null;
                                        _messages = [];
                                      });
                                    }
                                  } catch (e) {
                                    debugPrint("Erreur suppression: $e");
                                  }
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'rename',
                                  child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Renommer')]),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Supprimer', style: TextStyle(color: Colors.red))]),
                                ),
                              ],
                            ),
                            onTap: () {
                              setState(() {
                                _currentSession = session;
                                try {
                                  _messages = rust_chat.getChatMessages(wikiRoot: widget.wikiRoot, sessionId: session.id);
                                } catch (e) {
                                  _messages = [];
                                  debugPrint("Erreur chargement messages: $e");
                                }
                              });
                              Navigator.of(ctx).pop();
                              _scrollToBottom();
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Fermer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    
    final content = text.trim();
    _textController.clear();
    
    // Create new session if none exists
    if (_currentSession == null) {
      final session = rust_chat.ChatSession(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: content.length > 30 ? '${content.substring(0, 30)}...' : content,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      rust_chat.saveChatSession(wikiRoot: widget.wikiRoot, session: session);
      _currentSession = session;
    }

    final userMessage = rust_chat.ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      sessionId: _currentSession!.id,
      role: 'user',
      content: content,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });
    
    _scrollToBottom();
    
    // Sauvegarde en DB
    rust_chat.saveChatMessage(wikiRoot: widget.wikiRoot, message: userMessage);

    try {
      // Préparer l'historique pour Gemini
      final history = _messages.map((m) {
        return m.role == 'user' ? Content.text(m.content) : Content.model([TextPart(m.content)]);
      }).toList();
      
      // On retire le dernier message car on va l'envoyer comme nouveau message dans la méthode chat()
      history.removeLast();

      final result = await AIService.instance.chat(content, history, wikiRoot: widget.wikiRoot);
      
      final aiMessage = rust_chat.ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        sessionId: _currentSession!.id,
        role: 'model',
        content: result.text,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        sources: result.sources.isEmpty ? null : result.sources,
      );

      rust_chat.saveChatMessage(wikiRoot: widget.wikiRoot, message: aiMessage);

      setState(() {
        _messages.add(aiMessage);
        _isLoading = false;
      });
      _scrollToBottom();

    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur IA: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: const TextScaler.linear(0.80), // Échelle spécifique plus petite pour le chat
      ),
      child: Stack(
        children: [
          Column(
            children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.purple[300]),
                const SizedBox(width: 8),
                Text(
                  'Assistant IA',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.history),
                  tooltip: 'Historique des conversations',
                  onPressed: _showHistoryDialog,
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Nouvelle conversation',
                  onPressed: () {
                    setState(() {
                      _currentSession = null;
                      _messages = [];
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
                child: _messages.isEmpty
                    ? Center(
                        child: Text(
                          "Posez une question ou tapez / pour voir les commandes",
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length + (_isLoading ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _messages.length) {
                            return _buildLoadingBubble(theme);
                          }
                          final message = _messages[index];
                          return _buildMessageBubble(message, theme);
                        },
                      ),
              ),
              _buildInputArea(theme),
            ],
          ),
          if (_autocompleteMode != AutocompleteMode.none)
            Positioned(
              left: 16,
              bottom: 80,
              child: AutocompletePopup(
                mode: _autocompleteMode,
                commands: _availableCommands,
                images: _availableImages,
                pages: _availablePages,
                currentWord: _currentAutocompleteWord,
                onSelected: _insertAutocomplete,
                onCancel: () => setState(() => _autocompleteMode = AutocompleteMode.none),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingBubble(ThemeData theme) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(rust_chat.ChatMessage message, ThemeData theme) {
    final isUser = message.role == 'user';
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUser ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 0),
            bottomRight: Radius.circular(isUser ? 0 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            isUser 
                ? Text(message.content, style: TextStyle(color: theme.colorScheme.onPrimaryContainer))
                : MarkdownRenderer(content: message.content),
            if (!isUser && message.sources != null && message.sources!.where((s) => !s.startsWith('[Système]')).isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  Text("Sources :", style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ...message.sources!.where((s) => !s.startsWith('[Système]')).map((s) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Text(s, style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)),
                  )),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: 'Posez une question...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              minLines: 1,
              maxLines: 4,
              onSubmitted: _sendMessage,
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: theme.colorScheme.primary,
            child: IconButton(
              icon: Icon(Icons.send, color: theme.colorScheme.onPrimary, size: 20),
              onPressed: () => _sendMessage(_textController.text),
            ),
          ),
        ],
      ),
    );
  }
}
