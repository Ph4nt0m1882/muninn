import 'package:flutter/material.dart';
import 'package:munnin/features/explorer/explorer.dart';
import 'package:munnin/features/ai_chat/widgets/chat_panel.dart';
import 'package:munnin/features/editor/editor.dart';

class RightSidebar extends StatefulWidget {
  final String wikiRoot;
  final GlobalKey<FileExplorerState>? explorerKey;

  const RightSidebar({super.key, required this.wikiRoot, this.explorerKey});

  @override
  State<RightSidebar> createState() => _RightSidebarState();
}

class _RightSidebarState extends State<RightSidebar> {
  int _selectedIndex = 0; // 0 for File Explorer, 1 for AI Chat
  double _currentWidth = 320.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Row(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragUpdate: (details) {
            setState(() {
              _currentWidth -= details.delta.dx;
              if (_currentWidth < 200) _currentWidth = 200;
              if (_currentWidth > 600) _currentWidth = 600;
            });
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeLeftRight,
            child: Container(
              width: 5,
              color: Colors.transparent, // Zone de préhension invisible
            ),
          ),
        ),
        SizedBox(
          width: _currentWidth,
          child: Column(
            children: [
              // En-tête avec les onglets
              Container(
                color: theme.colorScheme.surfaceContainer,
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTab(
                        icon: Icons.folder,
                        label: 'Fichiers',
                        index: 0,
                        theme: theme,
                      ),
                    ),
                    Expanded(
                      child: _buildTab(
                        icon: Icons.auto_awesome,
                        label: 'Assistant',
                        index: 1,
                        theme: theme,
                      ),
                    ),
                  ],
                ),
              ),
              // Contenu
              Expanded(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: [
                    FileExplorer(
                      key: widget.explorerKey,
                      rootPath: widget.wikiRoot,
                      onFileSelected: (path) {
                        EditorManager.instance.openFile(path);
                      },
                    ),
                    ChatPanel(
                      wikiRoot: widget.wikiRoot,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTab({
    required IconData icon,
    required String label,
    required int index,
    required ThemeData theme,
  }) {
    final isSelected = _selectedIndex == index;
    final color = isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? theme.colorScheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
