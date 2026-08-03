import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:munnin/core/commands/commands.dart';

class WelcomeScreen extends StatefulWidget {
  final ValueChanged<String> onWikiOpened;
  final List<String> recentWikis;

  const WelcomeScreen({
    super.key,
    required this.onWikiOpened,
    this.recentWikis = const [],
  });

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final bool _isLoading = false;
  bool _showAllWikis = false;

  void _createNewWiki() {
    CommandManager.instance.execute('wiki.create');
  }

  void _openExistingWiki() {
    CommandManager.instance.execute('wiki.open');
  }

  void _openSettings() {
    CommandManager.instance.execute('app.theme_settings');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconPath = isDark
        ? 'assets/images/icones/munnin(dark).svg'
        : 'assets/images/icones/munnin(light).svg';

    final displayedWikis = _showAllWikis
        ? widget.recentWikis
        : widget.recentWikis.take(5).toList();

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 900),
        padding: const EdgeInsets.all(48.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // LOGO EN HAUT
            Align(
              alignment: Alignment.topCenter,
              child: Column(
                children: [
                  SvgPicture.asset(iconPath, width: 80, height: 80),
                  const SizedBox(height: 24),
                  Text(
                    'Munnin',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Votre base de connaissances personnelle.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 64),

            // DEUX COLONNES
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // COLONNE GAUCHE : ACTIONS
                  Expanded(
                    flex: 4,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        Text(
                          'Démarrer',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_isLoading)
                          const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          )
                        else ...[
                          _buildActionButton(
                            icon: Icons.create_new_folder,
                            label: 'Nouveau Wiki...',
                            onTap: _createNewWiki,
                            theme: theme,
                          ),
                          _buildActionButton(
                            icon: Icons.folder_open,
                            label: 'Ouvrir un Wiki...',
                            onTap: _openExistingWiki,
                            theme: theme,
                          ),
                          const SizedBox(height: 16),
                          _buildActionButton(
                            icon: Icons.settings,
                            label: 'Paramètres...',
                            onTap: _openSettings,
                            theme: theme,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                  // SÉPARATEUR
                  Container(
                    width: 1,
                    color: theme.dividerColor.withValues(alpha: 0.5),
                    margin: const EdgeInsets.symmetric(horizontal: 48),
                  ),

                  // COLONNE DROITE : RÉCENTS
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Récents',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (widget.recentWikis.isEmpty)
                          Text(
                            'Aucun wiki ouvert récemment.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: theme.textTheme.bodySmall?.color,
                            ),
                          )
                        else ...[
                          Expanded(
                            child: ListView.builder(
                              itemCount: displayedWikis.length,
                              itemBuilder: (context, index) {
                                final path = displayedWikis[index];
                                final name = path.split(RegExp(r'[/\\]')).last;
                                return InkWell(
                                  onTap: () => widget.onWikiOpened(path),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8.0,
                                      horizontal: 8.0,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.auto_stories,
                                          size: 20,
                                          color: theme.colorScheme.primary
                                              .withValues(alpha: 0.8),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              Text(
                                                path,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style:
                                                    theme.textTheme.bodySmall,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          if (widget.recentWikis.length > 5 && !_showAllWikis)
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _showAllWikis = true;
                                });
                              },
                              child: const Text('Voir tous les wikis...'),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        child: Row(
          children: [
            Icon(icon, size: 22, color: theme.colorScheme.primary),
            const SizedBox(width: 16),
            Text(
              label,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
