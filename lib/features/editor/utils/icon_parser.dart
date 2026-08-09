import 'package:flutter/material.dart';
import 'package:muninn/features/editor/utils/icon_list.dart';

/// Parse une chaîne d'icône (ex: 'play', 'gitea', 'info') en IconData
IconData parseIcon(String iconStr, {IconData fallback = Icons.info}) {
  final str = iconStr.trim().toLowerCase();

  // 1. Cherche dans Lucide (format 'lucide-xxx' ou juste 'xxx')
  if (str.startsWith('lucide-')) {
    if (lucideIconsMap.containsKey(str)) return lucideIconsMap[str]!;
  } else if (lucideIconsMap.containsKey('lucide-$str')) {
    return lucideIconsMap['lucide-$str']!;
  } else if (lucideIconsMap.containsKey(str)) {
    return lucideIconsMap[str]!;
  }

  // 2. Cherche dans Simple Icons (format 'simple-xxx')
  if (str.startsWith('simple-')) {
    if (simpleIconsMap.containsKey(str)) return simpleIconsMap[str]!;
  } else if (simpleIconsMap.containsKey('simple-$str')) {
    return simpleIconsMap['simple-$str']!;
  }

  // 3. Cherche dans Material Icons (format 'material-xxx')
  if (str.startsWith('material-')) {
    if (materialIconsMap.containsKey(str)) return materialIconsMap[str]!;
  } else if (materialIconsMap.containsKey('material-$str')) {
    return materialIconsMap['material-$str']!;
  }

  // Fallback for some common names if they differ
  final commonIcons = {
    'note': lucideIconsMap['lucide-info'] ?? Icons.info,
    'tip': lucideIconsMap['lucide-lightbulb'] ?? Icons.lightbulb,
    'important': lucideIconsMap['lucide-circle_alert'] ?? Icons.error,
    'warning': lucideIconsMap['lucide-triangle_alert'] ?? Icons.warning,
    'caution': lucideIconsMap['lucide-octagon'] ?? Icons.dangerous,
    'danger': lucideIconsMap['lucide-flame'] ?? Icons.whatshot,
    'success': lucideIconsMap['lucide-circle_check'] ?? Icons.check_circle,
    'error': lucideIconsMap['lucide-circle_x'] ?? Icons.error,
  };

  if (commonIcons.containsKey(str)) {
    return commonIcons[str]!;
  }

  return fallback;
}
