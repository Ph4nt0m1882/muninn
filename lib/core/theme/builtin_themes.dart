import 'package:flutter/material.dart';
import 'crow_style.dart';

class BuiltinThemes {
  static const CrowStyle light = CrowStyle(
    id: 'builtin_light',
    name: 'Light',
    ui: CrowStyleUI(
      brightness: Brightness.light,
      background: Color(0xFFF8FAFC),
      surface: Color(0xFFFFFFFF),
      surfaceHighlight: Color(0xFFE2E8F0),
      textPrimary: Color(0xFF0F172A),
      textSecondary: Color(0xFF64748B),
      accent: Color(0xFF0284C7),
    ),
  );

  static const CrowStyle dark = CrowStyle(
    id: 'builtin_dark',
    name: 'Dark',
    ui: CrowStyleUI(
      brightness: Brightness.dark,
      background: Color(0xFF0F172A),
      surface: Color(0xFF1E293B),
      surfaceHighlight: Color(0xFF334155),
      textPrimary: Color(0xFFF8FAFC),
      textSecondary: Color(0xFF94A3B8),
      accent: Color(0xFF38BDF8),
    ),
  );

  static const CrowStyle lightHC = CrowStyle(
    id: 'builtin_light_hc',
    name: 'Light High Contrast',
    ui: CrowStyleUI(
      brightness: Brightness.light,
      background: Color(0xFFFFFFFF),
      surface: Color(0xFFFFFFFF),
      surfaceHighlight: Color(0xFF000000), // Bordures très contrastées
      textPrimary: Color(0xFF000000),
      textSecondary: Color(0xFF000000),
      accent: Color(0xFF0000EE), // Bleu pur web
    ),
  );

  static const CrowStyle darkHC = CrowStyle(
    id: 'builtin_dark_hc',
    name: 'Dark High Contrast',
    ui: CrowStyleUI(
      brightness: Brightness.dark,
      background: Color(0xFF000000),
      surface: Color(0xFF000000),
      surfaceHighlight: Color(0xFFFFFFFF), // Bordures très contrastées
      textPrimary: Color(0xFFFFFFFF),
      textSecondary: Color(0xFFFFFFFF),
      accent: Color(0xFF00FF00), // Vert fluo
    ),
  );

  static const CrowStyle odin = CrowStyle(
    id: 'builtin_odin',
    name: 'Odin',
    ui: CrowStyleUI(
      brightness: Brightness.light,
      background: Color(0xFFFBF8F1),
      surface: Color(0xFFFFFFFF),
      surfaceHighlight: Color(0xFFF0E6D2),
      textPrimary: Color(0xFF2C241B),
      textSecondary: Color(0xFF7A6B53),
      accent: Color(0xFFD4AF37),
      backgroundImage: 'assets/images/bg/odin.svg',
    ),
  );

  static const CrowStyle huginn = CrowStyle(
    id: 'builtin_huginn',
    name: 'Huginn',
    ui: CrowStyleUI(
      brightness: Brightness.dark,
      background: Color(0xFF13111C),
      surface: Color(0xFF1E1A29),
      surfaceHighlight: Color(0xFF2A2438),
      textPrimary: Color(0xFFE2E0E5),
      textSecondary: Color(0xFF9A94A8),
      accent: Color(0xFF8B5CF6),
      backgroundImage: 'assets/images/bg/huginn.svg',
    ),
  );

  static const List<CrowStyle> all = [
    light,
    lightHC,
    odin,
    dark,
    darkHC,
    huginn,
  ];
}
