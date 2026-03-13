// lib/guards/auth_guard.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:tabuapp/widgets/main_navigation.dart';
import 'package:tabuapp/screens/screens_auth/acess_code_screen/acess_code_screen.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';

class AuthGuard extends StatelessWidget {
  const AuthGuard({super.key});

  Future<Map<String, dynamic>> _loadUserData(String uid) async {
    final snap = await FirebaseDatabase.instance
        .ref()
        .child('Users')
        .child(uid)
        .get();

    if (!snap.exists || snap.value == null) return {};
    return _deepCast(snap.value as Map);
  }

  static Map<String, dynamic> _deepCast(Map raw) {
    return raw.map((k, v) {
      final key = k?.toString() ?? '';
      dynamic value;
      if (v is Map)       value = _deepCast(v);
      else if (v is List) value = _castList(v);
      else                value = v;
      return MapEntry(key, value);
    });
  }

  static List<dynamic> _castList(List list) {
    return list.map((e) {
      if (e is Map)  return _deepCast(e);
      if (e is List) return _castList(e);
      return e;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        if (snapshot.hasData) {
          final uid = snapshot.data!.uid;

          return FutureBuilder<Map<String, dynamic>>(
            future: _loadUserData(uid),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const _LoadingScreen();
              }

              final userData = userSnapshot.data?.isNotEmpty == true
                  ? userSnapshot.data!
                  : {
                      'uid':   uid,
                      'name':  snapshot.data!.displayName ?? '',
                      'email': snapshot.data!.email ?? '',
                    };

              return TabuShell(userData: userData);
            },
          );
        }

        return const AccessCodeScreen();
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TabuColors.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'TABU',
              style: TextStyle(
                fontFamily: TabuTypography.displayFont,
                fontSize: 36,
                letterSpacing: 10,
                color: TabuColors.rosaPrincipal,
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(
                color: TabuColors.rosaPrincipal,
                strokeWidth: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}