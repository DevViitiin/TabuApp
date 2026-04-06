import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:tabuapp/services/services_app/presence_service.dart';

class AuthService {
  final FirebaseAuth     _auth     = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  Stream<User?> get user             => _auth.authStateChanges();
  Stream<User?> getcurrentUser()     => _auth.userChanges();
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user?.uid;
      if (uid != null) await _salvarTokenFCM(uid);

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleException(e);
    }
  }

  /// Busca os dados do usuário no Realtime Database usando o UID.
  /// Sempre inclui o campo 'uid' no map retornado.
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    final snapshot = await _database.ref('Users/$uid').get();
    if (snapshot.exists && snapshot.value != null) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      data['uid'] = uid; // garante que uid está sempre presente
      return data;
    }
    return null;
  }

  // ─── Registro + criação do nó no Realtime Database ───────────────────────
  Future<UserCredential?> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email:    email.trim(),
        password: password,
      );

      if (displayName != null) {
        await credential.user?.updateDisplayName(displayName);
      }

      final uid = credential.user?.uid;

      if (uid != null) {
        // Campos compatíveis com o que o app lê: name, email, avatar, etc.
        await _database.ref('Users/$uid').set({
          'uid':   uid,
          'name':  displayName ?? '',    // lido como userData['name']
          'email': email.trim(),
          'avatar': '',                  // vazio — usuário pode adicionar depois
          'bio':   '',
          'city':  '',
          'state': '',
          'partys':       0,
          'reservations': 0,
          'vip_lists':    0,
        });

        await _salvarTokenFCM(uid);
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleException(e);
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleException(e);
    }
  }

  Future<void> signOut() async {
    await PresenceService.instance.setOffline(); // ← marca offline primeiro
    await FirebaseAuth.instance.signOut();
  }

  // ─── Salva o token FCM no banco para receber notificações push ────────────
  Future<void> _salvarTokenFCM(String uid) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      await _database.ref('Users/$uid/fcmToken').set(token);

      // Atualiza automaticamente se o token for renovado pelo Firebase
      FirebaseMessaging.instance.onTokenRefresh.listen((novoToken) {
        _database.ref('Users/$uid/fcmToken').set(novoToken);
      });
    } catch (_) {}
  }

  String _handleException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Nenhum usuário encontrado com este e-mail.';
      case 'wrong-password':
        return 'Senha incorreta.';
      case 'email-already-in-use':
        return 'Este e-mail já está em uso.';
      case 'invalid-email':
        return 'E-mail inválido.';
      case 'weak-password':
        return 'A senha deve ter pelo menos 6 caracteres.';
      case 'user-disabled':
        return 'Esta conta foi desativada.';
      case 'too-many-requests':
        return 'Muitas tentativas. Tente novamente mais tarde.';
      default:
        return 'Erro: ${e.message}';
    }
  }
}