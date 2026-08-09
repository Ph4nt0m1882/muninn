import 'package:flutter/material.dart';
import 'package:muninn/core/commands/commands.dart';

class AppSettingsDialog extends StatelessWidget {
  const AppSettingsDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const AppSettingsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.settings),
          SizedBox(width: 8),
          Text('Paramètres de l\'Application'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.palette, color: theme.colorScheme.primary),
              title: const Text('Apparence & Thèmes'),
              subtitle: const Text('Personnaliser les couleurs et polices'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                CommandManager.instance.execute('app.theme_settings');
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.smart_toy, color: theme.colorScheme.secondary),
              title: const Text('Intelligence Artificielle'),
              subtitle: const Text('Configurer Gemini, Ollama ou autres modèles'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                CommandManager.instance.execute('app.ai_settings');
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.language, color: theme.colorScheme.tertiary),
              title: const Text('Langue'),
              subtitle: const Text('Français (Par défaut)'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Le changement de langue sera bientôt disponible.')),
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
    );
  }
}
