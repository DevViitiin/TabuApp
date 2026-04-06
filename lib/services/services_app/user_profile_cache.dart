// lib/services/services_app/user_profile_cache.dart
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class UserProfileData {
  final String name;
  final String avatar;
  const UserProfileData({required this.name, required this.avatar});
}

class UserProfileCache {
  UserProfileCache._();
  static final instance = UserProfileCache._();

  final Map<String, UserProfileData> _cache = {};
  final Map<String, Future<UserProfileData>> _inflight = {};

  /// Retorna do cache imediato (null na primeira chamada para este uid).
  UserProfileData? getCached(String uid) => _cache[uid];

  /// Busca do banco e cacheia. Chamadas simultâneas para o mesmo uid
  /// reutilizam o mesmo Future (sem dupla leitura no banco).
  Future<UserProfileData> fetch(String uid) {
    if (_cache.containsKey(uid)) return Future.value(_cache[uid]!);
    return _inflight.putIfAbsent(uid, () async {
      try {
        final snap = await FirebaseDatabase.instance.ref('Users/$uid').get();
        final data = snap.value as Map<dynamic, dynamic>? ?? {};
        final profile = UserProfileData(
          name:   ((data['name'] as String?) ?? '').toUpperCase(),
          avatar: (data['avatar'] as String?) ?? '',
        );
        _cache[uid] = profile;
        _inflight.remove(uid);
        return profile;
      } catch (e) {
        debugPrint('[UserProfileCache] fetch error for $uid: $e');
        _inflight.remove(uid);
        return const UserProfileData(name: '', avatar: '');
      }
    });
  }

  /// Chame após editar o perfil para forçar nova busca na próxima exibição.
  void invalidate(String uid) {
    _cache.remove(uid);
    _inflight.remove(uid);
  }
}