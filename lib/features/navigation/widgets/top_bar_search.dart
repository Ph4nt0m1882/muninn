import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:muninn/core/commands/commands.dart';

final FocusNode globalSearchFocusNode = FocusNode();

class TopBarSearch extends StatefulWidget {
  const TopBarSearch({super.key});

  @override
  State<TopBarSearch> createState() => _TopBarSearchState();
}

class _TopBarSearchState extends State<TopBarSearch> {
  final TextEditingController _controller = TextEditingController();
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  List<AppCommand> _filteredCommands = [];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    globalSearchFocusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    globalSearchFocusNode.removeListener(_onFocusChange);
    _controller.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onFocusChange() {
    if (globalSearchFocusNode.hasFocus) {
      _filterCommands('');
      _showOverlay();
    } else {
      _removeOverlay();
      _controller.clear();
    }
  }

  void _filterCommands(String query) {
    final all = CommandManager.instance.allCommands;
    if (query.isEmpty) {
      _filteredCommands = all;
    } else {
      final lowerQuery = query.toLowerCase();
      _filteredCommands = all.where((cmd) {
        return cmd.title.toLowerCase().contains(lowerQuery) ||
            (cmd.description?.toLowerCase().contains(lowerQuery) ?? false);
      }).toList();
    }
    _selectedIndex = 0;

    // Si l'overlay est déjà affiché, on demande à le redessiner
    _overlayEntry?.markNeedsBuild();
  }

  void _executeCommand(AppCommand command) {
    globalSearchFocusNode.unfocus();
    command.execute();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (_filteredCommands.isEmpty) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _selectedIndex = (_selectedIndex + 1) % _filteredCommands.length;
      _overlayEntry?.markNeedsBuild();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _selectedIndex =
          (_selectedIndex - 1 + _filteredCommands.length) %
          _filteredCommands.length;
      _overlayEntry?.markNeedsBuild();
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      _executeCommand(_filteredCommands[_selectedIndex]);
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      globalSearchFocusNode.unfocus();
    }
  }

  void _showOverlay() {
    _removeOverlay();
    final theme = Theme.of(context);

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // Catcher global pour fermer quand on clique à côté
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => globalSearchFocusNode.unfocus(),
                child: Container(color: Colors.transparent),
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 36), // Hauteur du textfield (28) + marge
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 450,
                  constraints: const BoxConstraints(maxHeight: 300),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: theme.dividerColor.withValues(alpha: 0.5),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: _filteredCommands.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Aucune commande trouvée',
                            style: theme.textTheme.bodyMedium,
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: _filteredCommands.length,
                          itemBuilder: (context, index) {
                            final cmd = _filteredCommands[index];
                            final isSelected = index == _selectedIndex;

                            return Listener(
                              onPointerDown: (_) => _executeCommand(cmd),
                              child: Container(
                                color: isSelected
                                    ? theme.colorScheme.primary.withValues(
                                        alpha: 0.1,
                                      )
                                    : Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      cmd.icon ?? Icons.terminal,
                                      size: 16,
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : theme.iconTheme.color,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            cmd.title,
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  fontWeight: isSelected
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                ),
                                          ),
                                          if (cmd.description != null)
                                            Text(
                                              cmd.description!,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    fontSize: 11,
                                                    color: theme
                                                        .textTheme
                                                        .bodySmall
                                                        ?.color
                                                        ?.withValues(
                                                          alpha: 0.7,
                                                        ),
                                                  ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (cmd.shortcutLabel != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme.dividerColor.withValues(
                                            alpha: 0.5,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          cmd.shortcutLabel!,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                fontSize: 10,
                                                fontFamily: 'monospace',
                                              ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        width: 450,
        height: 28,
        decoration: BoxDecoration(
          color: globalSearchFocusNode.hasFocus
              ? theme.colorScheme.surface
              : theme.colorScheme.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: globalSearchFocusNode.hasFocus
                ? theme.colorScheme.primary
                : theme.dividerColor.withValues(alpha: 0.2),
          ),
        ),
        child: KeyboardListener(
          focusNode: FocusNode(),
          onKeyEvent: _handleKeyEvent,
          child: TextField(
            controller: _controller,
            focusNode: globalSearchFocusNode,
            onChanged: _filterCommands,
            textAlignVertical:
                TextAlignVertical.center, // Centrage vertical natif
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Rechercher une commande...',
              hintStyle: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.6,
                ),
                fontSize: 13,
                height: 1.0, // Évite les débordements de hauteur
              ),
              prefixIcon: Icon(
                Icons.search,
                size: 16,
                color: theme.iconTheme.color?.withValues(alpha: 0.6),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 36,
                minHeight: 28,
              ), // Empêche l'icône de grossir la boîte
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero, // On enlève le padding forcé
              isDense: true,
            ),
          ),
        ),
      ),
    );
  }
}
