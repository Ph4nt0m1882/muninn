import 'package:flutter/material.dart';
import 'package:muninn/core/theme/theme.dart';
import 'package:muninn/features/settings/settings.dart';

class ThemeSelectionScreen extends StatefulWidget {
  final int initialIndex;
  final ValueChanged<int> onThemeSelected;

  const ThemeSelectionScreen({
    super.key,
    required this.initialIndex,
    required this.onThemeSelected,
  });

  @override
  State<ThemeSelectionScreen> createState() => _ThemeSelectionScreenState();
}

class _ThemeSelectionScreenState extends State<ThemeSelectionScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Paramètres d\'Apparence',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choisissez le thème de l\'application. Les thèmes "HC" sont à haut contraste.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          Expanded(
            child: CustomScrollView(
              slivers: [
                // Titre Thèmes Système (optionnel, mais bon pour la clarté)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      'Thèmes Systèmes',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                // Grille des thèmes systèmes
                SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.2,
                    crossAxisSpacing: 24,
                    mainAxisSpacing: 24,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final style = BuiltinThemes.all[index];
                      return ThemePreviewCard(
                        style: style,
                        isSelected: _currentIndex == index,
                        onTap: () {
                          setState(() {
                            _currentIndex = index;
                          });
                          widget.onThemeSelected(index);
                        },
                        // onEdit est null car ce sont des thèmes systèmes
                      );
                    },
                    childCount: BuiltinThemes.all.length,
                  ),
                ),

                // Séparateur et Titre Thèmes Personnalisés
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 32.0, bottom: 16.0),
                    child: Text(
                      'Thèmes Personnalisés',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // TODO: SliverGrid pour les thèmes personnalisés (vide pour l'instant)
                // SliverGrid(...)

                // Bouton "Créer un thème" (Taille d'une barre d'espace)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 24.0, bottom: 24.0),
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const ThemeEditorScreen(),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 48, // Faible hauteur (façon barre d'espace)
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(alpha: 0.5),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Créer un thème',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
