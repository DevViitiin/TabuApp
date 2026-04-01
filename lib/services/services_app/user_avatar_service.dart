// lib/services/services_app/user_avatar_service.dart
//
// Cache de avatares — busca sempre do nó Users/{uid}/avatar no RTDB.
// Evita usar URLs salvas em posts/comentários (podem ter tokens expirados).

import 'package:firebase_database/firebase_database.dart';

class UserAvatarService {
  UserAvatarService._();
  static final UserAvatarService instance = UserAvatarService._();

  // Cache em memória para evitar múltiplas buscas do mesmo uid na sessão
  final Map<String, String> _cache = {};

  /// Retorna a URL do avatar atual do usuário.
  /// Sempre busca do RTDB — nunca confie na URL salva no post/comentário.
  Future<String> getAvatar(String uid) async {
    if (uid.isEmpty) return '';
    if (_cache.containsKey(uid)) return _cache[uid]!;

    try {
      final snap = await FirebaseDatabase.instance
          .ref('Users/$uid/avatar')
          .get();
      final url = (snap.exists && snap.value != null)
          ? (snap.value as String? ?? '')
          : '';
      _cache[uid] = url;
      return url;
    } catch (_) {
      return '';
    }
  }

  /// Invalida o cache de um usuário (chamar após editar perfil).
  void invalidate(String uid) => _cache.remove(uid);

  /// Invalida o cache completo.
  void clear() => _cache.clear();
}