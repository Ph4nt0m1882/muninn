import 'package:flutter/material.dart';
import 'package:muninn/core/commands/commands.dart';

class LeftSidebar extends StatelessWidget {
  final VoidCallback onThemeToggle;
  final VoidCallback onOpenEditor;

  const LeftSidebar({
    super.key,
    required this.onThemeToggle,
    required this.onOpenEditor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 64, // Largeur fixe pour une sidebar d'icônes
      color: theme
          .colorScheme
          .surface, // Couleur de fond distincte de la zone centrale
      child: Column(
        children: [
          // Espace en haut
          const SizedBox(height: 16),

          // Bouton Accueil ou Fichiers
          IconButton(
            icon: const Icon(Icons.folder_open),
            color: theme.colorScheme.onSurface,
            tooltip: 'Ouvrir un Wiki',
            onPressed: () {
              CommandManager.instance.execute('wiki.open');
            },
          ),

          const SizedBox(height: 16),

          IconButton(
            icon: const Icon(Icons.search),
            color: theme.colorScheme.onSurface,
            tooltip: 'Recherche',
            onPressed: () {
              CommandManager.instance.execute('app.command_palette');
            },
          ),

          // Pousse les éléments suivants vers le bas
          const Spacer(),

          // Bouton pour basculer les thèmes (temporaire pour test)
          IconButton(
            icon: const Icon(Icons.color_lens_outlined),
            color: theme.colorScheme.primary,
            tooltip: 'Thème',
            onPressed: onThemeToggle,
          ),

          const SizedBox(height: 16),

          // Bouton Paramètres
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            color: theme.colorScheme.onSurface,
            tooltip: 'Paramètres',
            onPressed: () {
              CommandManager.instance.execute('app.settings');
            },
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
