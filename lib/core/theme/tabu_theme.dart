import 'package:flutter/material.dart';

/// TABU LOUNGE — Theme 100% fiel à foto
/// • Parede rosa salmão uniforme  →  #E8767A  (fundo do app)
/// • Logo / nuvens brancos        →  #FFFFFF  (texto, elementos)
/// • LED neon ciano nas nuvens    →  #5DDFFF  (acento)
/// Sem preto. Rosa é o fundo, branco é o primeiro plano.
class TabuColors {
  TabuColors._();

  // Rosa
  static const Color rosaPrincipal   = Color(0xFFE8767A); // parede do bar
  static const Color rosaClaro       = Color(0xFFF0A0A4); // tint
  static const Color rosaPastel      = Color(0xFFF9E0E1); // superfície card
  static const Color rosaEscuro      = Color(0xFFC95A60); // sombra/pressed
  static const Color rosaVivo        = Color(0xFFEA5D65); // badge/alerta

  // Branco
  static const Color branco          = Color(0xFFFFFFFF); // logo, texto, nuvens
  static const Color brancoRosado    = Color(0xFFFFF4F4); // input fill
  static const Color brancoQuente    = Color(0xFFFFF9F9); // modal background

  // Neon ciano (LED das nuvens)
  static const Color neonCyan        = Color(0xFF5DDFFF);
  static const Color neonBright      = Color(0xFF3BC8F5);
  static const Color neonDeep        = Color(0xFF1AA8D8); // links / CTAs sec.
  static const Color neonGlow        = Color(0xFFB8F0FF); // halo difuso

  // Texto
  static const Color textoPrincipal  = branco;
  static const Color textoSecundario = Color(0xCCFFFFFF); // branco 80%
  static const Color textoMuted      = Color(0x88FFFFFF); // branco 53%
  static const Color textoSobreWhite = Color(0xFF9A4048); // sobre superfície branca

  // Borders
  static const Color border          = Color(0x44FFFFFF); // branco 27% sobre rosa
  static const Color borderSobreWhite= Color(0x55E8767A); // rosa 33% sobre branco
  static const Color borderNeon      = Color(0x665DDFFF); // neon 40%

  // Aliases
  static const Color primary   = rosaPrincipal;
  static const Color accent    = neonCyan;
  static const Color highlight = rosaClaro;
  static const Color background= rosaPrincipal;
  static const Color surface   = brancoRosado;

  // Gradientes
  static const LinearGradient fundoApp = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFEC8286), Color(0xFFE8767A), Color(0xFFE47076)],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient ctaGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [rosaPrincipal, neonCyan],
  );

  static const LinearGradient tetoGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x885DDFFF), Color(0x22E8767A), Colors.transparent],
    stops: [0.0, 0.4, 1.0],
  );

  static const RadialGradient rosaGlow = RadialGradient(
    colors: [Color(0x66E8767A), Color(0x00000000)], radius: 0.8,
  );
  static const RadialGradient neonGlowRadial = RadialGradient(
    colors: [Color(0x885DDFFF), Color(0x00000000)], radius: 0.8,
  );

  static const List<MapEntry<String, Color>> palette = [
    MapEntry('#E8767A', rosaPrincipal),
    MapEntry('#F0A0A4', rosaClaro),
    MapEntry('#F9E0E1', rosaPastel),
    MapEntry('#C95A60', rosaEscuro),
    MapEntry('#EA5D65', rosaVivo),
    MapEntry('#FFFFFF', branco),
    MapEntry('#FFF4F4', brancoRosado),
    MapEntry('#FFF9F9', brancoQuente),
    MapEntry('#5DDFFF', neonCyan),
    MapEntry('#3BC8F5', neonBright),
    MapEntry('#1AA8D8', neonDeep),
    MapEntry('#B8F0FF', neonGlow),
  ];
}

class TabuTypography {
  TabuTypography._();
  static const String displayFont = 'Bebas Neue';
  static const String bodyFont    = 'Outfit';

  static TextTheme get textTheme => const TextTheme(
    displayLarge:   TextStyle(fontFamily: displayFont, fontSize: 80, fontWeight: FontWeight.w400, letterSpacing: 12, color: TabuColors.textoPrincipal, height: 1.0),
    displayMedium:  TextStyle(fontFamily: displayFont, fontSize: 56, fontWeight: FontWeight.w400, letterSpacing: 8,  color: TabuColors.textoPrincipal),
    displaySmall:   TextStyle(fontFamily: displayFont, fontSize: 40, fontWeight: FontWeight.w400, letterSpacing: 5,  color: TabuColors.textoPrincipal),
    headlineLarge:  TextStyle(fontFamily: displayFont, fontSize: 32, fontWeight: FontWeight.w400, letterSpacing: 3,  color: TabuColors.textoPrincipal),
    headlineMedium: TextStyle(fontFamily: bodyFont,    fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: 1.5,color: TabuColors.textoPrincipal),
    headlineSmall:  TextStyle(fontFamily: bodyFont,    fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 1.2,color: TabuColors.textoPrincipal),
    titleLarge:     TextStyle(fontFamily: bodyFont,    fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 2,  color: TabuColors.textoPrincipal),
    titleMedium:    TextStyle(fontFamily: bodyFont,    fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 1.5,color: TabuColors.textoPrincipal),
    titleSmall:     TextStyle(fontFamily: bodyFont,    fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 1.5,color: TabuColors.textoSecundario),
    bodyLarge:      TextStyle(fontFamily: bodyFont,    fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.3,color: TabuColors.textoPrincipal,   height: 1.6),
    bodyMedium:     TextStyle(fontFamily: bodyFont,    fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.2,color: TabuColors.textoSecundario,  height: 1.5),
    bodySmall:      TextStyle(fontFamily: bodyFont,    fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.5,color: TabuColors.textoMuted,       height: 1.4),
    labelLarge:     TextStyle(fontFamily: bodyFont,    fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 3,  color: TabuColors.textoPrincipal),
    labelMedium:    TextStyle(fontFamily: bodyFont,    fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 2.5,color: TabuColors.textoSecundario),
    labelSmall:     TextStyle(fontFamily: bodyFont,    fontSize: 9,  fontWeight: FontWeight.w600, letterSpacing: 2,  color: TabuColors.textoMuted),
  );
}

class TabuTheme {
  TabuTheme._();

  static ThemeData get main => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: TabuColors.rosaPrincipal,
    colorScheme: const ColorScheme.light(
      primary:     TabuColors.branco,
      onPrimary:   TabuColors.rosaPrincipal,
      secondary:   TabuColors.neonCyan,
      onSecondary: TabuColors.branco,
      tertiary:    TabuColors.rosaEscuro,
      onTertiary:  TabuColors.branco,
      surface:     TabuColors.brancoRosado,
      onSurface:   TabuColors.textoSobreWhite,
      outline:     TabuColors.border,
    ),
    textTheme: TabuTypography.textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: TabuColors.rosaPrincipal,
      foregroundColor: TabuColors.branco,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(fontFamily: TabuTypography.displayFont, fontSize: 24, fontWeight: FontWeight.w400, letterSpacing: 8, color: TabuColors.branco),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor:     TabuColors.rosaPrincipal,
      selectedItemColor:   TabuColors.branco,
      unselectedItemColor: TabuColors.textoMuted,
      selectedLabelStyle:  TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w700),
      unselectedLabelStyle:TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 10, letterSpacing: 2),
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: TabuColors.branco,
        foregroundColor: TabuColors.rosaPrincipal,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
        textStyle: const TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 3),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: TabuColors.branco,
        side: const BorderSide(color: TabuColors.branco, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
        textStyle: const TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 3),
      ),
    ),
    cardTheme: CardThemeData(
      color: TabuColors.brancoRosado,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(0),
        side: const BorderSide(color: TabuColors.borderSobreWhite, width: 0.5),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0x28FFFFFF),
      border:        OutlineInputBorder(borderRadius: BorderRadius.circular(0), borderSide: const BorderSide(color: TabuColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(0), borderSide: const BorderSide(color: TabuColors.border, width: 0.8)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(0), borderSide: const BorderSide(color: TabuColors.branco, width: 1.5)),
      labelStyle: const TextStyle(fontFamily: TabuTypography.bodyFont, color: TabuColors.textoSecundario, letterSpacing: 1.5, fontSize: 12),
      hintStyle:  const TextStyle(fontFamily: TabuTypography.bodyFont, color: TabuColors.textoMuted,      letterSpacing: 1.5, fontSize: 12),
    ),
    dividerTheme: const DividerThemeData(color: TabuColors.border, thickness: 0.5),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0x28FFFFFF),
      selectedColor:   TabuColors.branco,
      labelStyle: const TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 11, letterSpacing: 2, color: TabuColors.textoPrincipal),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0), side: const BorderSide(color: TabuColors.border)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
    iconTheme: const IconThemeData(color: TabuColors.textoSecundario, size: 20),
  );
}

class TabuGlow {
  TabuGlow._();
  static List<BoxShadow> branco({double blur = 16}) => [
    BoxShadow(color: Colors.white.withOpacity(0.35), blurRadius: blur, offset: const Offset(0, 4)),
  ];
  static List<BoxShadow> neonCyan({double blur = 20, double spread = 4}) => [
    BoxShadow(color: TabuColors.neonCyan.withOpacity(0.65), blurRadius: blur, spreadRadius: spread),
    BoxShadow(color: TabuColors.neonGlow.withOpacity(0.3),  blurRadius: blur * 2),
  ];
  static List<BoxShadow> rosaProfundo({double blur = 12}) => [
    BoxShadow(color: TabuColors.rosaEscuro.withOpacity(0.3), blurRadius: blur, offset: const Offset(0, 4)),
  ];
}