import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  Stream<User?> get user => _auth.authStateChanges();
  Stream<User?> getcurrentUser() => _auth.userChanges();
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleException(e);
    }
  }

  //Busca os dados do usuario no Realtime Database usando o UID
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    final snapshot = await _database.ref('Users/$uid').get();
    if (snapshot.exists) {
      return Map<String, dynamic>.from(snapshot.value as Map);
    }
    return null;
  }
  // ─── Registro + criação do nó no Realtime Database ───────────────
  Future<UserCredential?> registerWithEmail({
  required String email,
  required String password,
  String? displayName,
}) async {
  try {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    if (displayName != null) {
      await credential.user?.updateDisplayName(displayName);
    }

    final uid = credential.user?.uid;
    print('✅ Usuário criado — UID: $uid');

    if (uid != null) {
      try {
        await _database.ref('Users/$uid').set({
          'uid': uid,
          'nome': displayName ?? '',
          'email': email.trim(),
          'criadoEm': DateTime.now().toIso8601String(),
          'ativo': true,
        });
        print('✅ Dados salvos no Realtime Database');
      } catch (dbError) {
        print('❌ Erro ao salvar no Database: $dbError');
        rethrow;
      }
    }

    return credential;
  } on FirebaseAuthException catch (e) {
    print('❌ FirebaseAuthException: ${e.code} — ${e.message}');
    throw _handleException(e);
  } catch (e) {
    print('❌ Erro inesperado: $e');
    rethrow;
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
    await _auth.signOut();
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
