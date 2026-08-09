import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:muninn/features/navigation/navigation.dart';
import 'package:window_manager/window_manager.dart';

class CustomTopBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomTopBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(40.0); // Hauteur de la barre

  @override
  Widget build(BuildContext context) {
    // Si on est sur le Web, on n'affiche pas la TopBar personnalisée
    if (kIsWeb) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Chemin vers l'icône en fonction du thème
    final iconPath = Theme.of(context).brightness == Brightness.dark
        ? 'assets/images/icones/muninn(dark).svg'
        : 'assets/images/icones/muninn(light).svg';

    return Container(
      color: theme.scaffoldBackgroundColor,
      // On utilise LayoutBuilder pour connaître la taille réelle donnée par l'écran
      child: LayoutBuilder(
        builder: (context, constraints) {
          // WindowCaption a besoin d'au moins ~150px pour ses boutons système.
          // Si l'écran est plus petit, on force la largeur à 150px pour éviter que
          // le "Expanded" interne de WindowCaption ne plante ou ne déborde.
          final safeWidth = constraints.maxWidth < 150
              ? 150.0
              : constraints.maxWidth;

          return Stack(
            children: [
              // La barre native avec les boutons de fenêtre
              ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: safeWidth,
                  maxWidth: safeWidth,
                  maxHeight: 40.0,
                  child: WindowCaption(
                    brightness: theme.brightness,
                    backgroundColor: Colors.transparent,
                    title: Row(
                      children: [
                        SvgPicture.asset(iconPath, width: 20, height: 20),
                        const SizedBox(width: 12),
                        Text(
                          "Muninn",
                          style: TextStyle(
                            color: theme.textTheme.bodyLarge?.color,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Le vrai champ de recherche (TopBarSearch) au centre
              if (constraints.maxWidth >
                  600) // Ne l'afficher que s'il y a assez de place
                Align(
                  alignment: Alignment.center,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: const TopBarSearch(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
