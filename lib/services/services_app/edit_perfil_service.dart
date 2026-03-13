// lib/services/services_app/edit_perfil_service.dart
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Tudo vive em Users/{uid}  (U maiúsculo).
/// Este serviço lê e escreve apenas nesse nó.
class EditPerfilService {
  final _db      = FirebaseDatabase.instance.ref().child('Users');
  final _storage = FirebaseStorage.instance;
  final _auth    = FirebaseAuth.instance;

  String get _uid => _auth.currentUser?.uid ?? '';

  // ── Upload avatar → Firebase Storage → avatars/{uid}.jpg ───────────────────
  Future<String> uploadAvatar(
    File file, {
    void Function(double progress)? onProgress,
  }) async {
    if (_uid.isEmpty) throw Exception('Usuário não autenticado');

    final ref = _storage.ref().child('avatars').child('$_uid.jpg');

    final task = ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    if (onProgress != null) {
      task.snapshotEvents.listen((snap) {
        final total = snap.totalBytes == 0 ? 1 : snap.totalBytes;
        onProgress(snap.bytesTransferred / total);
      });
    }

    await task;
    return await ref.getDownloadURL();
  }

  // ── Salva campos editáveis em Users/{uid} ───────────────────────────────────
  Future<void> _save({
    required String name,
    required String bio,
    required String avatarUrl,
  }) async {
    if (_uid.isEmpty) throw Exception('Usuário não autenticado');

    await _db.child(_uid).update({
      'name':   name.trim(),
      'bio':    bio.trim(),
      'avatar': avatarUrl,
    });
  }

  // ── Operação completa ───────────────────────────────────────────────────────
  /// Faz upload se houver nova foto, salva no banco e devolve
  /// apenas os campos alterados para o caller fazer merge.
  Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String bio,
    required String currentAvatarUrl,
    File? newImageFile,
    void Function(double progress)? onUploadProgress,
  }) async {
    if (_uid.isEmpty) throw Exception('Usuário não autenticado');

    String avatarUrl = currentAvatarUrl;

    if (newImageFile != null) {
      avatarUrl = await uploadAvatar(
        newImageFile,
        onProgress: onUploadProgress,
      );
    }

    await _save(name: name, bio: bio, avatarUrl: avatarUrl);

    return {
      'name':   name.trim(),
      'bio':    bio.trim(),
      'avatar': avatarUrl,
    };
  }
}