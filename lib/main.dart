import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:tabuapp/controllers/controllers_authentication/auth_controller.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/firebase_options.dart';
import 'package:tabuapp/services/services_app/presence_service.dart';
import 'routes/auth_guard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ══════════════════════════════════════════════════════════════════════════
  // MODO IMERSIVO TOTAL - SEM NAVIGATION BAR NUNCA
  // ══════════════════════════════════════════════════════════════════════════
  
  // Remove TODOS os overlays (status bar + navigation bar)
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky, // Modo imersivo com gestos nativos
  );

  // Configura estilo das barras (quando aparecerem por swipe)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // INICIALIZAÇÃO DO FIREBASE
  // ══════════════════════════════════════════════════════════════════════════

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Listener de presença
  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user != null) {
      PresenceService.instance.init();
    } else {
      PresenceService.instance.setOffline();
    }
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
      ],
      child: const MyApp(),
    ),
  );
}

// Widget para manter o modo imersivo em TODAS as telas
class ImmersiveScaffold extends StatelessWidget {
  final Widget child;
  
  const ImmersiveScaffold({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: child,
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: TabuTheme.main,
      builder: (context, child) {
        // Garante imersão em TODAS as rotas
        return ImmersiveScaffold(child: child!);
      },
      home: const AuthGuard(),
    );
  }
}