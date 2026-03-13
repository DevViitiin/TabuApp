import 'package:flutter/material.dart';

/// TABU LOUNGE — Tema escuro com rosa vibrante
/// • Fundo quase preto        → #100208
/// • Rosa principal           → #E85D8A
/// • Rosa claro / pale        → #F5A0C0 / #FCE4ED
/// • Texto branco             → #FFFFFF
/// • Bordas e glow em rosa translúcido
class TabuColors {
  TabuColors._();

  // Fundos
  static const Color bg         = Color(0xFF100208); // --c-bg
  static const Color bgAlt      = Color(0xFF1E0813); // --c-bg-alt
  static const Color bgCard     = Color(0x08FFFFFF); // --c-bg-card  (rgba 3%)
  static const Color nav        = Color(0xF5100208); // --c-nav (96% opaque)

  // Rosa
  static const Color rosaDeep   = Color(0xFF6B1040); // --c-rose-deep
  static const Color rosaPrincipal= Color(0xFFE85D8A);// --c-rose
  static const Color rosaClaro  = Color(0xFFF5A0C0); // --c-rose-light
  static const Color rosaPale   = Color(0xFFFCE4ED); // --c-rose-pale

  // Branco / texto
  static const Color branco     = Color(0xFFFFFFFF); // --c-white
  static const Color dim        = Color(0x94FFFFFF); // --c-dim   (rgba 58%)
  static const Color subtle     = Color(0x52FFFFFF); // --c-subtle (rgba 32%)

  // Bordas & Glow
  static const Color border     = Color(0x2EE85D8A); // --c-border   (18%)
  static const Color borderMid  = Color(0x61E85D8A); // --c-border-mid (38%)
  static const Color glow       = Color(0x73E85D8A); // --c-glow      (45%)

  // Aliases semânticos
  static const Color primary    = rosaPrincipal;
  static const Color accent     = rosaClaro;
  static const Color background = bg;
  static const Color surface    = bgCard;

  // Texto
  static const Color textoPrincipal   = branco;
  static const Color textoSecundario  = dim;
  static const Color textoMuted       = subtle;
  static const Color textoSobreRosa   = Color(0xFF100208); // texto escuro sobre botão rosa

  // Gradientes
  static const LinearGradient fundoApp = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bg, bgAlt],
  );

  static const LinearGradient rosaGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [rosaDeep, rosaPrincipal],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x00100208), Color(0xCC100208), bg],
    stops: [0.0, 0.6, 1.0],
  );

  static const RadialGradient rosaGlow = RadialGradient(
    colors: [Color(0x73E85D8A), Color(0x00000000)],
    radius: 0.8,
  );

  // Paleta completa para referência
  static const List<MapEntry<String, Color>> palette = [
    MapEntry('#100208', bg),
    MapEntry('#1E0813', bgAlt),
    MapEntry('#6B1040', rosaDeep),
    MapEntry('#E85D8A', rosaPrincipal),
    MapEntry('#F5A0C0', rosaClaro),
    MapEntry('#FCE4ED', rosaPale),
    MapEntry('#FFFFFF', branco),
  ];
}

class TabuTypography {
  TabuTypography._();

  static const String displayFont = 'Anton';           // --f-display (Impact fallback)
  static const String bodyFont    = 'Barlow Condensed'; // --f-body

  static TextTheme get textTheme => const TextTheme(
    displayLarge:   TextStyle(fontFamily: displayFont,  fontSize: 80,  fontWeight: FontWeight.w400, letterSpacing: 4,   color: TabuColors.textoPrincipal, height: 1.0),
    displayMedium:  TextStyle(fontFamily: displayFont,  fontSize: 56,  fontWeight: FontWeight.w400, letterSpacing: 3,   color: TabuColors.textoPrincipal),
    displaySmall:   TextStyle(fontFamily: displayFont,  fontSize: 40,  fontWeight: FontWeight.w400, letterSpacing: 2,   color: TabuColors.textoPrincipal),
    headlineLarge:  TextStyle(fontFamily: displayFont,  fontSize: 32,  fontWeight: FontWeight.w400, letterSpacing: 1.5, color: TabuColors.textoPrincipal),
    headlineMedium: TextStyle(fontFamily: bodyFont,     fontSize: 24,  fontWeight: FontWeight.w600, letterSpacing: 1.2, color: TabuColors.textoPrincipal),
    headlineSmall:  TextStyle(fontFamily: bodyFont,     fontSize: 18,  fontWeight: FontWeight.w600, letterSpacing: 1.0, color: TabuColors.textoPrincipal),
    titleLarge:     TextStyle(fontFamily: bodyFont,     fontSize: 16,  fontWeight: FontWeight.w600, letterSpacing: 1.5, color: TabuColors.textoPrincipal),
    titleMedium:    TextStyle(fontFamily: bodyFont,     fontSize: 14,  fontWeight: FontWeight.w500, letterSpacing: 1.2, color: TabuColors.textoPrincipal),
    titleSmall:     TextStyle(fontFamily: bodyFont,     fontSize: 12,  fontWeight: FontWeight.w500, letterSpacing: 1.2, color: TabuColors.textoSecundario),
    bodyLarge:      TextStyle(fontFamily: bodyFont,     fontSize: 16,  fontWeight: FontWeight.w400, letterSpacing: 0.3, color: TabuColors.textoPrincipal,  height: 1.6),
    bodyMedium:     TextStyle(fontFamily: bodyFont,     fontSize: 14,  fontWeight: FontWeight.w400, letterSpacing: 0.2, color: TabuColors.textoSecundario, height: 1.5),
    bodySmall:      TextStyle(fontFamily: bodyFont,     fontSize: 12,  fontWeight: FontWeight.w400, letterSpacing: 0.4, color: TabuColors.textoMuted,      height: 1.4),
    labelLarge:     TextStyle(fontFamily: bodyFont,     fontSize: 13,  fontWeight: FontWeight.w700, letterSpacing: 2.5, color: TabuColors.textoPrincipal),
    labelMedium:    TextStyle(fontFamily: bodyFont,     fontSize: 11,  fontWeight: FontWeight.w600, letterSpacing: 2.0, color: TabuColors.textoSecundario),
    labelSmall:     TextStyle(fontFamily: bodyFont,     fontSize: 9,   fontWeight: FontWeight.w600, letterSpacing: 1.5, color: TabuColors.textoMuted),
  );
}

class TabuTheme {
  TabuTheme._();

  static ThemeData get main => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: TabuColors.bg,
    colorScheme: const ColorScheme.dark(
      primary:     TabuColors.rosaPrincipal,
      onPrimary:   TabuColors.branco,
      secondary:   TabuColors.rosaClaro,
      onSecondary: TabuColors.bg,
      tertiary:    TabuColors.rosaDeep,
      onTertiary:  TabuColors.branco,
      surface:     TabuColors.bgCard,
      onSurface:   TabuColors.textoPrincipal,
      outline:     TabuColors.border,
    ),
    textTheme: TabuTypography.textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: TabuColors.nav,
      foregroundColor: TabuColors.branco,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: TabuTypography.displayFont,
        fontSize: 24,
        fontWeight: FontWeight.w400,
        letterSpacing: 6,
        color: TabuColors.branco,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor:      TabuColors.nav,
      selectedItemColor:    TabuColors.rosaPrincipal,
      unselectedItemColor:  TabuColors.subtle,
      selectedLabelStyle:   TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w700),
      unselectedLabelStyle: TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 10, letterSpacing: 2),
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: TabuColors.rosaPrincipal,
        foregroundColor: TabuColors.branco,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
        textStyle: const TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 3),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: TabuColors.rosaPrincipal,
        side: const BorderSide(color: TabuColors.rosaPrincipal, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
        textStyle: const TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 3),
      ),
    ),
    cardTheme: CardThemeData(
      color: TabuColors.bgCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(0),
        side: const BorderSide(color: TabuColors.border, width: 0.8),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: TabuColors.bgCard,
      border:        OutlineInputBorder(borderRadius: BorderRadius.circular(0), borderSide: const BorderSide(color: TabuColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(0), borderSide: const BorderSide(color: TabuColors.border, width: 0.8)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(0), borderSide: const BorderSide(color: TabuColors.rosaPrincipal, width: 1.5)),
      labelStyle: const TextStyle(fontFamily: TabuTypography.bodyFont, color: TabuColors.textoSecundario, letterSpacing: 1.5, fontSize: 12),
      hintStyle:  const TextStyle(fontFamily: TabuTypography.bodyFont, color: TabuColors.textoMuted,      letterSpacing: 1.5, fontSize: 12),
    ),
    dividerTheme: const DividerThemeData(color: TabuColors.border, thickness: 0.5),
    chipTheme: ChipThemeData(
      backgroundColor: TabuColors.bgCard,
      selectedColor:   TabuColors.rosaPrincipal,
      labelStyle: const TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 11, letterSpacing: 2, color: TabuColors.textoPrincipal),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(0),
        side: const BorderSide(color: TabuColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
    iconTheme: const IconThemeData(color: TabuColors.textoSecundario, size: 20),
  );
}

class TabuGlow {
  TabuGlow._();

  static List<BoxShadow> rosaPrincipal({double blur = 20, double spread = 4}) => [
    BoxShadow(color: TabuColors.glow,            blurRadius: blur,      spreadRadius: spread),
    BoxShadow(color: TabuColors.rosaPrincipal.withOpacity(0.2), blurRadius: blur * 2),
  ];

  static List<BoxShadow> rosaSubtle({double blur = 12}) => [
    BoxShadow(color: TabuColors.border, blurRadius: blur, offset: const Offset(0, 4)),
  ];

  static List<BoxShadow> branco({double blur = 16}) => [
    BoxShadow(color: Colors.white.withOpacity(0.12), blurRadius: blur, offset: const Offset(0, 4)),
  ];
}