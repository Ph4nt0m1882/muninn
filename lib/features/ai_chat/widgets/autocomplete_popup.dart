import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:file_picker/file_picker.dart';

enum AutocompleteMode { none, commands, context }

class AutocompletePopup extends StatefulWidget {
  final AutocompleteMode mode;
  final List<String> commands;
  final List<String> images;
  final List<String> pages;
  final String currentWord;
  final void Function(String result, {required bool isExternal, required bool isCommand}) onSelected;
  final VoidCallback onCancel;

  const AutocompletePopup({
    super.key,
    required this.mode,
    required this.commands,
    required this.images,
    required this.pages,
    required this.currentWord,
    required this.onSelected,
    required this.onCancel,
  });

  @override
  State<AutocompletePopup> createState() => _AutocompletePopupState();
}

class _AutocompletePopupState extends State<AutocompletePopup> {
  bool _showExternalDropZone = false;
  bool _isDragging = false;

  @override
  void didUpdateWidget(AutocompletePopup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mode != oldWidget.mode) {
      _showExternalDropZone = false;
    }
  }

  void _pickExternalFile() async {
    final result = await FilePicker.pickFiles();
    if (result != null && result.files.single.path != null) {
      widget.onSelected(result.files.single.path!, isExternal: true, isCommand: false);
    } else {
      widget.onCancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mode == AutocompleteMode.none) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isCommand = widget.mode == AutocompleteMode.commands;

    final query = widget.currentWord.length > 1 ? widget.currentWord.substring(1).toLowerCase() : '';
    
    final filteredCommands = widget.commands.where((c) => c.toLowerCase().contains(query)).toList();
    final filteredPages = widget.pages.where((p) => p.toLowerCase().contains(query)).toList();
    final filteredImages = widget.images.where((i) => i.toLowerCase().contains(query)).toList();

    return Material(
      elevation: 16,
      borderRadius: BorderRadius.circular(12),
      color: theme.colorScheme.surfaceContainer,
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 300, minWidth: 250, maxWidth: 350),
        child: _showExternalDropZone ? _buildExternalDropZone(theme) : _buildLists(
          theme: theme,
          isCommand: isCommand,
          filteredCommands: filteredCommands,
          filteredPages: filteredPages,
          filteredImages: filteredImages,
        ),
      ),
    );
  }

  Widget _buildLists({
    required ThemeData theme,
    required bool isCommand,
    required List<String> filteredCommands,
    required List<String> filteredPages,
    required List<String> filteredImages,
  }) {
    if (isCommand) {
      if (filteredCommands.isEmpty) {
        return _buildEmptyState("Aucune commande trouvée", theme);
      }
      return ListView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        itemCount: filteredCommands.length,
        itemBuilder: (context, index) {
          final cmd = filteredCommands[index];
          return ListTile(
            leading: const Icon(LucideIcons.terminal),
            title: Text('/$cmd'),
            onTap: () => widget.onSelected(cmd, isExternal: false, isCommand: true),
          );
        },
      );
    } else {
      // Context Mode
      return CustomScrollView(
        shrinkWrap: true,
        slivers: [
          SliverToBoxAdapter(
            child: ListTile(
              leading: Icon(LucideIcons.folder_up, color: theme.colorScheme.primary),
              title: Text('Media Externe...', style: TextStyle(color: theme.colorScheme.primary)),
              onTap: () {
                setState(() {
                  _showExternalDropZone = true;
                });
              },
            ),
          ),
          if (filteredPages.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('PAGES', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final page = filteredPages[index];
                  return ListTile(
                    leading: const Icon(LucideIcons.file_text, size: 18),
                    title: Text(page, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => widget.onSelected(page, isExternal: false, isCommand: false),
                  );
                },
                childCount: filteredPages.length,
              ),
            ),
          ],
          if (filteredImages.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('IMAGES', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final img = filteredImages[index];
                  return ListTile(
                    leading: const Icon(LucideIcons.image, size: 18),
                    title: Text(img, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => widget.onSelected(img, isExternal: false, isCommand: false),
                  );
                },
                childCount: filteredImages.length,
              ),
            ),
          ],
        ],
      );
    }
  }

  Widget _buildEmptyState(String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(text, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
    );
  }

  Widget _buildExternalDropZone(ThemeData theme) {
    return DropTarget(
      onDragEntered: (details) {
        setState(() => _isDragging = true);
      },
      onDragExited: (details) {
        setState(() => _isDragging = false);
      },
      onDragDone: (details) {
        if (details.files.isNotEmpty) {
          widget.onSelected(details.files.first.path, isExternal: true, isCommand: false);
        }
      },
      child: GestureDetector(
        onTap: _pickExternalFile,
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: _isDragging ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5) : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isDragging ? theme.colorScheme.primary : theme.dividerColor,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.upload,
                size: 48,
                color: _isDragging ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                "Glissez un fichier ici\nou cliquez pour parcourir",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _isDragging ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
