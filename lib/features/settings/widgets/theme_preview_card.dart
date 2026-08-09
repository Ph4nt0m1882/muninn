import 'package:flutter/material.dart';
import 'package:muninn/core/theme/theme.dart';

class ThemePreviewCard extends StatefulWidget {
  final CrowStyle style;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  const ThemePreviewCard({
    super.key,
    required this.style,
    required this.isSelected,
    required this.onTap,
    this.onEdit,
  });

  @override
  State<ThemePreviewCard> createState() => _ThemePreviewCardState();
}

class _ThemePreviewCardState extends State<ThemePreviewCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // On génère le ThemeData spécifique à cette carte
    final previewTheme = ThemeManager.buildThemeData(widget.style);
    
    // Logique de la bordure
    final borderColor = widget.isSelected || _isHovered 
        ? previewTheme.colorScheme.primary 
        : Colors.transparent;
    
    double borderWidth = 0;
    if (widget.isSelected && _isHovered) {
      borderWidth = 5.0; // Épaissi au survol du thème sélectionné
    } else if (widget.isSelected) {
      borderWidth = 3.0; // Thème sélectionné (comme actuellement)
    } else if (_isHovered) {
      borderWidth = 2.0; // Légèrement plus fin au survol
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: borderWidth > 0 ? borderWidth : 2.0, // Toujours 2.0 en transparent pour éviter le layout jump
            ),
            boxShadow: [
              if (widget.isSelected)
                BoxShadow(
                  color: previewTheme.colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
            ],
          ),
          // L'astuce magique : On force tout ce sous-arbre à utiliser "previewTheme" !
          child: Theme(
            data: previewTheme,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: previewTheme.scaffoldBackgroundColor,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Fausse TopBar
                        Container(
                          height: 32,
                          color: previewTheme.colorScheme.surface,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            widget.style.name,
                            style: previewTheme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        // Faux Contenu
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 100,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: previewTheme.textTheme.bodyLarge?.color,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: 140,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: previewTheme.textTheme.bodyMedium?.color
                                        ?.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const Spacer(),
                                // Faux bouton
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: previewTheme.colorScheme.primary,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      'Actif',
                                      style: TextStyle(
                                        color: previewTheme.colorScheme.onPrimary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Triangle d'édition pour les thèmes personnalisés
                  if (widget.onEdit != null && _isHovered)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: widget.onEdit,
                        child: CustomPaint(
                          painter: _TrianglePainter(color: previewTheme.colorScheme.primary),
                          size: const Size(40, 40),
                          child: const SizedBox(
                            width: 40,
                            height: 40,
                            child: Align(
                              alignment: Alignment(0.5, -0.5),
                              child: Icon(
                                Icons.edit,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;

  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
