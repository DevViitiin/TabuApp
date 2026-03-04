import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tabuapp/services/services_app/auth_service.dart';
import 'package:tabuapp/screens/screens_home/home_screen/home_screen.dart';
import 'package:tabuapp/screens/screens_auth/acess_code_screen/acess_code_screen.dart';

class AuthGuard extends StatelessWidget {
  const AuthGuard({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFE8767A),
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }

        if (snapshot.hasData) {
          // Usuário logado — busca os dados e passa para HomeScreen
          return FutureBuilder<Map<String, dynamic>?>(
            future: AuthService().getUserData(snapshot.data!.uid),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  backgroundColor: Color(0xFFE8767A),
                  body: Center(child: CircularProgressIndicator(color: Colors.white)),
                );
              }
              return HomeScreen(
                userData: userSnapshot.data ?? {
                  'uid': snapshot.data!.uid,
                  'nome': snapshot.data!.displayName ?? '',
                  'email': snapshot.data!.email ?? '',
                  'ativo': true,
                },
              );
            },
          );
        }

        return const AccessCodeScreen();
      },
    );
  }
}