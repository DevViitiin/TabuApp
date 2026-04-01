import 'package:flutter/material.dart';
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

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Inicializa presença sempre que o estado de auth mudar
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: TabuTheme.main,
      home: const AuthGuard(),
    );
  }
}
