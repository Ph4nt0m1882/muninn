import 'package:flutter/material.dart';
import 'package:muninn/features/navigation/navigation.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget child; // La zone centrale (l'éditeur)
  final Widget? rightSidebar; // Optionnel : l'explorateur à droite
  final VoidCallback onThemeToggle;
  final VoidCallback onOpenEditor;

  // Point de rupture pour passer en mode "Téléphone"
  static const double mobileBreakpoint = 600.0;

  const ResponsiveLayout({
    super.key,
    required this.child,
    this.rightSidebar,
    required this.onThemeToggle,
    required this.onOpenEditor,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < mobileBreakpoint;
        final themeData = Theme.of(context);

        if (isMobile) {
          // Layout type Téléphone (Pas de barre à gauche)
          return child;
        } else {
          // Layout type Desktop (Barre à gauche)
          return Row(
            children: [
              LeftSidebar(
                onThemeToggle: onThemeToggle,
                onOpenEditor: onOpenEditor,
              ),
              VerticalDivider(width: 1, color: themeData.dividerColor),
              Expanded(child: child),
              if (rightSidebar != null) ...[
                VerticalDivider(width: 1, color: themeData.dividerColor),
                rightSidebar!,
              ],
            ],
          );
        }
      },
    );
  }
}
