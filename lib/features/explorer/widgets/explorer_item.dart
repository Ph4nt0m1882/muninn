import 'package:flutter/material.dart';
import 'package:muninn/features/explorer/models/explorer_node.dart';
import 'package:muninn/core/constants/app_sizes.dart';

/// Composant visuel représentant une seule ligne dans l'explorateur (fichier ou dossier).
class ExplorerItem extends StatelessWidget {
  /// Le nœud représenté.
  final ExplorerNode node;

  /// Indique si l'élément est actuellement sélectionné.
  final bool isSelected;

  /// Action au clic simple.
  final VoidCallback onTap;

  /// Action au clic droit (position fournie).
  final void Function(Offset position) onSecondaryTap;

  /// Action déclenchée lorsqu'un autre élément est relâché sur celui-ci (Drag & Drop).
  final void Function(String droppedPath) onDroppedOn;

  const ExplorerItem({
    super.key,
    required this.node,
    this.isSelected = false,
    required this.onTap,
    required this.onSecondaryTap,
    required this.onDroppedOn,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String name = node.entity.path.split(RegExp(r'[/\\]')).last;

    // Masquer l'extension .md pour l'affichage
    if (!node.isDirectory && name.toLowerCase().endsWith('.md')) {
      name = name.substring(0, name.length - 3);
    }

    // Décalage pour simuler l'arbre
    final indent = AppSizes.spacingM + (node.depth * AppSizes.spacingL);

    // L'élément visuel de base
    Widget content = Container(
      height: AppSizes.itemHeightCompact,
      padding: EdgeInsets.only(left: indent, right: AppSizes.spacingS),
      color: isSelected
          ? theme.colorScheme.primary.withValues(alpha: 0.15)
          : Colors.transparent,
      child: Row(
        children: [
          if (node.isDirectory)
            Icon(
              node.isExpanded
                  ? Icons.keyboard_arrow_down
                  : Icons.keyboard_arrow_right,
              size: AppSizes.iconSmall,
              color: theme.iconTheme.color?.withValues(alpha: 0.7),
            )
          else
            const SizedBox(width: AppSizes.iconSmall),

          const SizedBox(width: AppSizes.spacingXs),

          Icon(
            node.isDirectory ? Icons.folder : Icons.insert_drive_file,
            size: AppSizes.iconSmall,
            color: node.isDirectory
                ? theme.colorScheme.primary.withValues(alpha: 0.8)
                : theme.iconTheme.color?.withValues(alpha: 0.5),
          ),

          const SizedBox(width: AppSizes.spacingS),

          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: AppSizes.fontS,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? theme.colorScheme.primary
                    : (node.isDirectory
                          ? theme.textTheme.bodyLarge?.color
                          : theme.textTheme.bodyMedium?.color),
              ),
            ),
          ),
        ],
      ),
    );

    // Draggable pour pouvoir le déplacer
    Widget draggableWidget = Draggable<String>(
      data: node.entity.path,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.7,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.spacingS,
              vertical: AppSizes.spacingXs,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppSizes.radiusS),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: AppSizes.radiusS,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
            child: Text(name, style: theme.textTheme.bodyMedium),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: content),
      child: content,
    );

    Widget finalContent = draggableWidget;

    // Si c'est un dossier, on peut déposer dessus
    if (node.isDirectory) {
      finalContent = DragTarget<String>(
        onWillAcceptWithDetails: (details) {
          return details.data != node.entity.path;
        },
        onAcceptWithDetails: (details) {
          onDroppedOn(details.data);
        },
        builder: (context, candidateData, rejectedData) {
          final isHovered = candidateData.isNotEmpty;
          return Container(
            color: isHovered
                ? theme.colorScheme.primary.withValues(alpha: 0.2)
                : Colors.transparent,
            child: draggableWidget,
          );
        },
      );
    }

    return GestureDetector(
      onSecondaryTapDown: (details) {
        onSecondaryTap(details.globalPosition);
      },
      child: InkWell(onTap: onTap, child: finalContent),
    );
  }
}
