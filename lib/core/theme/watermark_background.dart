import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class WatermarkBackground extends StatelessWidget {
  final String imagePath;
  final Color inkColor;
  final double opacity;

  const WatermarkBackground({
    super.key,
    required this.imagePath,
    required this.inkColor,
    this.opacity = 0.05,
  });

  @override
  Widget build(BuildContext context) {
    final r = inkColor.red.toDouble();
    final g = inkColor.green.toDouble();
    final b = inkColor.blue.toDouble();

    // Matrice magique qui transforme n'importe quelle image (bicolore/niveaux de gris) :
    // - Les pixels blancs deviennent transparents (Alpha = 0)
    // - Les pixels noirs deviennent opaques (Alpha = 255) et prennent la couleur inkColor (r, g, b)
    // - Les pixels gris deviennent semi-transparents
    // - Respecte l'Alpha original (une image détourée reste détourée)
    final matrix = <double>[
      0, 0, 0, 0, r,
      0, 0, 0, 0, g,
      0, 0, 0, 0, b,
      -0.2126, -0.7152, -0.0722, 1, 0,
    ];

    final isAsset = imagePath.startsWith('assets/');
    final isSvg = imagePath.toLowerCase().endsWith('.svg');

    Widget imageWidget;
    if (isAsset) {
      if (isSvg) {
        imageWidget = SvgPicture.asset(imagePath, fit: BoxFit.cover);
      } else {
        imageWidget = Image.asset(imagePath, fit: BoxFit.cover);
      }
    } else {
      final file = File(imagePath);
      if (isSvg) {
        imageWidget = SvgPicture.file(file, fit: BoxFit.cover);
      } else {
        imageWidget = Image.file(file, fit: BoxFit.cover);
      }
    }

    return Opacity(
      opacity: opacity,
      child: ColorFiltered(
        colorFilter: ColorFilter.matrix(matrix),
        child: imageWidget,
      ),
    );
  }
}
