// lib/services/services_app/follow_service.dart
//
// Gerencia o sistema de seguir/deixar de seguir entre usuários.
//
// Estrutura no RTDB:
//   Users/{meuUid}/following/{userId}: true   → quem eu sigo
//   Users/{userId}/followers/{meuUid}: true    → quem me segue
//   Users/{meuUid}/vip_friends/{userId}: true  → amigos VIP
//
// Paginação:
//   Todas as listas de UIDs suportam cursor via [startAfterKey].
//   Tamanho padrão de página: [pageSize] = 10.

import 'package:firebase_database/firebase_database.dart';

class FollowService {
  FollowService._();
  static final FollowService instance = FollowService._();

  final _db = FirebaseDatabase.instance;

  static const int pageSize = 10;

  // ── Referências ──────────────────────────────────────────────────────────

  DatabaseReference _followingRef(String myUid, String targetUid) =>
      _db.ref('Users/$myUid/following/$targetUid');

  DatabaseReference _followerRef(String targetUid, String myUid) =>
      _db.ref('Users/$targetUid/followers/$myUid');

  DatabaseReference _followersRef(String userId) =>
      _db.ref('Users/$userId/followers');

  DatabaseReference _followingAllRef(String userId) =>
      _db.ref('Users/$userId/following');

  DatabaseReference _vipRef(String myUid, String targetUid) =>
      _db.ref('Users/$myUid/vip_friends/$targetUid');

  DatabaseReference _vipAllRef(String myUid) =>
      _db.ref('Users/$myUid/vip_friends');

  // ── Consultas simples ────────────────────────────────────────────────────

  /// Verifica se [myUid] já segue [targetUid].
  Future<bool> isSeguindo(String myUid, String targetUid) async {
    if (myUid.isEmpty || targetUid.isEmpty || myUid == targetUid) return false;
    try {
      final snap = await _followerRef(targetUid, myUid).get();
      return snap.exists && snap.value == true;
    } catch (_) {
      return false;
    }
  }

  /// Alias em inglês para compatibilidade com as telas.
  Future<bool> isFollowing(String myUid, String targetUid) =>
      isSeguindo(myUid, targetUid);

  /// Stream em tempo real: true se [myUid] segue [targetUid].
  Stream<bool> streamIsSeguindo(String myUid, String targetUid) {
    if (myUid.isEmpty || targetUid.isEmpty || myUid == targetUid) {
      return Stream.value(false);
    }
    return _followerRef(targetUid, myUid)
        .onValue
        .map((e) => e.snapshot.exists && e.snapshot.value == true);
  }

  /// Número total de seguidores de [userId].
  Future<int> getFollowersCount(String userId) async {
    try {
      final snap = await _followersRef(userId).get();
      if (!snap.exists || snap.value == null) return 0;
      if (snap.value is Map) return (snap.value as Map).length;
      return 0;
    } catch (_) {
      return 0;
    }
  }

  /// Número total de pessoas que [userId] segue.
  Future<int> getFollowingCount(String userId) async {
    try {
      final snap = await _followingAllRef(userId).get();
      if (!snap.exists || snap.value == null) return 0;
      if (snap.value is Map) return (snap.value as Map).length;
      return 0;
    } catch (_) {
      return 0;
    }
  }

  /// Número total de amigos VIP de [myUid].
  Future<int> getVipFriendsCount(String myUid) async {
    try {
      final snap = await _vipAllRef(myUid).get();
      if (!snap.exists || snap.value == null) return 0;
      if (snap.value is Map) return (snap.value as Map).length;
      return 0;
    } catch (_) {
      return 0;
    }
  }

  /// Stream do contador de seguidores em tempo real.
  Stream<int> streamFollowersCount(String userId) {
    return _followersRef(userId).onValue.map((e) {
      if (!e.snapshot.exists || e.snapshot.value == null) return 0;
      if (e.snapshot.value is Map) return (e.snapshot.value as Map).length;
      return 0;
    });
  }

  /// Stream do contador de seguindo em tempo real.
  Stream<int> streamFollowingCount(String userId) {
    return _followingAllRef(userId).onValue.map((e) {
      if (!e.snapshot.exists || e.snapshot.value == null) return 0;
      if (e.snapshot.value is Map) return (e.snapshot.value as Map).length;
      return 0;
    });
  }

  // ── Mutações de seguir ───────────────────────────────────────────────────

  /// [myUid] passa a seguir [targetUid].
  Future<void> seguir(String myUid, String targetUid) async {
    if (myUid.isEmpty || targetUid.isEmpty || myUid == targetUid) return;
    await Future.wait([
      _followingRef(myUid, targetUid).set(true),
      _followerRef(targetUid, myUid).set(true),
    ]);
  }

  /// Alias em inglês.
  Future<void> followUser(String myUid, String targetUid) =>
      seguir(myUid, targetUid);

  /// [myUid] deixa de seguir [targetUid].
  Future<void> deixarDeSeguir(String myUid, String targetUid) async {
    if (myUid.isEmpty || targetUid.isEmpty) return;
    await Future.wait([
      _followingRef(myUid, targetUid).remove(),
      _followerRef(targetUid, myUid).remove(),
      _db.ref('Users/$myUid/vip_friends/$targetUid').remove(),
    ]);
  }

  /// Alias em inglês.
  Future<void> unfollowUser(String myUid, String targetUid) =>
      deixarDeSeguir(myUid, targetUid);

  /// Toggle: segue se não seguia, deixa de seguir se seguia.
  Future<bool> toggle(String myUid, String targetUid) async {
    final jaSeguindo = await isSeguindo(myUid, targetUid);
    if (jaSeguindo) {
      await deixarDeSeguir(myUid, targetUid);
      return false;
    } else {
      await seguir(myUid, targetUid);
      return true;
    }
  }

  // ── Listas completas (sem paginação – uso interno / contagem) ────────────

  Future<List<String>> getFollowers(String userId) async {
    try {
      final snap = await _followersRef(userId).get();
      if (!snap.exists || snap.value is! Map) return [];
      return (snap.value as Map).keys.map((k) => k.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  /// Alias para compatibilidade com as telas.
  Future<List<String>?> getUserFollowers(String userId) =>
      getFollowers(userId);

  Future<List<String>> getFollowing(String userId) async {
    try {
      final snap = await _followingAllRef(userId).get();
      if (!snap.exists || snap.value is! Map) return [];
      return (snap.value as Map).keys.map((k) => k.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Listas PAGINADAS ─────────────────────────────────────────────────────

  /// Retorna até [pageSize] UIDs de seguidores de [userId].
  ///
  /// [startAfterKey]: chave (UID) da última entrada da página anterior.
  /// Retorna lista vazia se não há mais resultados.
  Future<List<String>> getFollowersPaginated(
    String userId, {
    String? startAfterKey,
    int limit = pageSize,
  }) async {
    try {
      Query query = _followersRef(userId).orderByKey().limitToFirst(limit);
      if (startAfterKey != null && startAfterKey.isNotEmpty) {
        query = _followersRef(userId)
            .orderByKey()
            .startAfter(startAfterKey)
            .limitToFirst(limit);
      }
      final snap = await query.get();
      if (!snap.exists || snap.value is! Map) return [];
      return (snap.value as Map).keys.map((k) => k.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  /// Retorna até [pageSize] UIDs de quem [userId] segue (paginado).
  Future<List<String>> getFollowingPaginated(
    String userId, {
    String? startAfterKey,
    int limit = pageSize,
  }) async {
    try {
      Query query = _followingAllRef(userId).orderByKey().limitToFirst(limit);
      if (startAfterKey != null && startAfterKey.isNotEmpty) {
        query = _followingAllRef(userId)
            .orderByKey()
            .startAfter(startAfterKey)
            .limitToFirst(limit);
      }
      final snap = await query.get();
      if (!snap.exists || snap.value is! Map) return [];
      return (snap.value as Map).keys.map((k) => k.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  /// Retorna até [pageSize] UIDs de amigos VIP de [myUid] (paginado).
  Future<List<String>> getVipFriendsPaginated(
    String myUid, {
    String? startAfterKey,
    int limit = pageSize,
  }) async {
    try {
      Query query = _vipAllRef(myUid).orderByKey().limitToFirst(limit);
      if (startAfterKey != null && startAfterKey.isNotEmpty) {
        query = _vipAllRef(myUid)
            .orderByKey()
            .startAfter(startAfterKey)
            .limitToFirst(limit);
      }
      final snap = await query.get();
      if (!snap.exists || snap.value is! Map) return [];
      return (snap.value as Map).keys.map((k) => k.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  AMIGOS VIP
  // ══════════════════════════════════════════════════════════════════════════

  /// Verifica se [myUid] tem [targetUid] como amigo VIP.
  Future<bool> isVip(String myUid, String targetUid) async {
    if (myUid.isEmpty || targetUid.isEmpty) return false;
    try {
      final snap = await _vipRef(myUid, targetUid).get();
      return snap.exists && snap.value == true;
    } catch (_) {
      return false;
    }
  }

  /// Alias em inglês.
  Future<bool> isVipFriend(String myUid, String targetUid) =>
      isVip(myUid, targetUid);

  /// Stream em tempo real: true se [targetUid] é VIP de [myUid].
  Stream<bool> streamIsVip(String myUid, String targetUid) {
    if (myUid.isEmpty || targetUid.isEmpty) return Stream.value(false);
    return _vipRef(myUid, targetUid)
        .onValue
        .map((e) => e.snapshot.exists && e.snapshot.value == true);
  }

  /// Adiciona [targetUid] como amigo VIP de [myUid].
  /// Só funciona se [myUid] já segue [targetUid].
  Future<bool> adicionarVip(String myUid, String targetUid) async {
    if (myUid.isEmpty || targetUid.isEmpty || myUid == targetUid) return false;
    final seguindo = await isSeguindo(myUid, targetUid);
    if (!seguindo) return false;
    await _vipRef(myUid, targetUid).set(true);
    return true;
  }

  /// Alias em inglês.
  Future<bool> addVipFriend(String myUid, String targetUid) =>
      adicionarVip(myUid, targetUid);

  /// Remove [targetUid] dos amigos VIP de [myUid].
  Future<void> removerVip(String myUid, String targetUid) async {
    if (myUid.isEmpty || targetUid.isEmpty) return;
    await _vipRef(myUid, targetUid).remove();
  }

  /// Alias em inglês.
  Future<void> removeVipFriend(String myUid, String targetUid) =>
      removerVip(myUid, targetUid);

  /// Toggle VIP. Retorna o novo estado (true = é VIP agora).
  Future<bool> toggleVip(String myUid, String targetUid) async {
    final jaVip = await isVip(myUid, targetUid);
    if (jaVip) {
      await removerVip(myUid, targetUid);
      return false;
    } else {
      return await adicionarVip(myUid, targetUid);
    }
  }

  /// Lista completa de UIDs VIP (sem paginação – uso interno).
  Future<List<String>> getVipFriends(String myUid) async {
    try {
      final snap = await _vipAllRef(myUid).get();
      if (!snap.exists || snap.value is! Map) return [];
      return (snap.value as Map).keys.map((k) => k.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  /// Alias para compatibilidade com as telas.
  Future<List<String>?> getUserVipFriends(String myUid) =>
      getVipFriends(myUid);
}