// lib/core/utils/immersive_mode_helper.dart
import 'package:flutter/services.dart';

class ImmersiveModeHelper {
  /// Ativa modo imersivo completo (esconde navigation bar e status bar)
  static void enableFullImmersive() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
  }

  /// Ativa modo edge-to-edge (esconde apenas navigation bar, mantém status bar)
  static void enableEdgeToEdge() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top],
    );
  }

  /// Esconde apenas a navigation bar (botões do Android)
  static void hideNavigationBar() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top], // Mantém apenas a status bar
    );
  }

  /// Restaura barras padrão do sistema
  static void showSystemUI() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values, // Mostra tudo
    );
  }

  /// Configura cores das barras do sistema (para modo edge-to-edge)
  static void setSystemUIColors({
    required Color statusBarColor,
    required Color navigationBarColor,
    Brightness statusBarIconBrightness = Brightness.light,
    Brightness navigationBarIconBrightness = Brightness.light,
  }) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: statusBarColor,
        statusBarIconBrightness: statusBarIconBrightness,
        systemNavigationBarColor: navigationBarColor,
        systemNavigationBarIconBrightness: navigationBarIconBrightness,
      ),
    );
  }
}