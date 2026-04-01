// lib/services/services_app/follow_service.dart
//
// Gerencia o sistema de seguir/deixar de seguir entre usuários.
//
// Estrutura no RTDB:
//   Users/{meuUid}/following/{userId}: true   → quem eu sigo
//   Users/{userId}/followers/{meuUid}: true    → quem me segue
//
// Uso:
//   final fs = FollowService.instance;
//   bool jaSigo = await fs.isSeguindo(myUid, userId);
//   await fs.seguir(myUid, userId);
//   await fs.deixarDeSeguir(myUid, userId);
//   int count  = await fs.getFollowersCount(userId);
//   int count  = await fs.getFollowingCount(userId);
//   Stream<bool> s = fs.streamIsSeguindo(myUid, userId);

import 'package:firebase_database/firebase_database.dart';

class FollowService {
  FollowService._();
  static final FollowService instance = FollowService._();

  final _db = FirebaseDatabase.instance;

  // ── Referências ──────────────────────────────────────────────────────────

  /// Nó que marca que [myUid] segue [targetUid]
  DatabaseReference _followingRef(String myUid, String targetUid) =>
      _db.ref('Users/$myUid/following/$targetUid');

  /// Nó que marca que [myUid] é seguidor de [targetUid]
  DatabaseReference _followerRef(String targetUid, String myUid) =>
      _db.ref('Users/$targetUid/followers/$myUid');

  /// Todos os seguidores de um usuário
  DatabaseReference _followersRef(String userId) =>
      _db.ref('Users/$userId/followers');

  /// Todos os usuários que [userId] segue
  DatabaseReference _followingAllRef(String userId) =>
      _db.ref('Users/$userId/following');

  // ── Consultas ────────────────────────────────────────────────────────────

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

  /// Stream em tempo real: true se [myUid] segue [targetUid].
  Stream<bool> streamIsSeguindo(String myUid, String targetUid) {
    if (myUid.isEmpty || targetUid.isEmpty || myUid == targetUid) {
      return Stream.value(false);
    }
    return _followerRef(targetUid, myUid).onValue.map(
        (e) => e.snapshot.exists && e.snapshot.value == true);
  }

  /// Número de seguidores de [userId].
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

  /// Número de pessoas que [userId] segue.
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

  // ── Mutações ─────────────────────────────────────────────────────────────

  /// [myUid] passa a seguir [targetUid].
  /// Escreve nos dois nós em paralelo (atomicidade eventual).
  Future<void> seguir(String myUid, String targetUid) async {
    if (myUid.isEmpty || targetUid.isEmpty || myUid == targetUid) return;
    await Future.wait([
      _followingRef(myUid, targetUid).set(true),
      _followerRef(targetUid, myUid).set(true),
    ]);
  }

  /// [myUid] deixa de seguir [targetUid].
  /// Remove automaticamente o VIP se existia.
  Future<void> deixarDeSeguir(String myUid, String targetUid) async {
    if (myUid.isEmpty || targetUid.isEmpty) return;
    await Future.wait([
      _followingRef(myUid, targetUid).remove(),
      _followerRef(targetUid, myUid).remove(),
      _db.ref('Users/$myUid/vip_friends/$targetUid').remove(), // auto-remove VIP
    ]);
  }

  /// Toggle: segue se não seguia, deixa de seguir se seguia.
  /// Retorna o novo estado (true = seguindo).
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

  /// Lista de UIDs que [userId] segue.
  Future<List<String>> getFollowing(String userId) async {
    try {
      final snap = await _followingAllRef(userId).get();
      if (!snap.exists || snap.value is! Map) return [];
      return (snap.value as Map).keys.map((k) => k.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  /// Lista de UIDs que seguem [userId].
  Future<List<String>> getFollowers(String userId) async {
    try {
      final snap = await _followersRef(userId).get();
      if (!snap.exists || snap.value is! Map) return [];
      return (snap.value as Map).keys.map((k) => k.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  AMIGOS VIP
  //
  //  Users/{myUid}/vip_friends/{targetUid}: true
  //
  //  Regras:
  //  - Só pode adicionar como VIP se já está seguindo
  //  - Ao deixar de seguir, o VIP é removido automaticamente
  // ══════════════════════════════════════════════════════════════════════════

  DatabaseReference _vipRef(String myUid, String targetUid) =>
      _db.ref('Users/$myUid/vip_friends/$targetUid');

  DatabaseReference _vipAllRef(String myUid) =>
      _db.ref('Users/$myUid/vip_friends');

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

  /// Stream em tempo real: true se [targetUid] é VIP de [myUid].
  Stream<bool> streamIsVip(String myUid, String targetUid) {
    if (myUid.isEmpty || targetUid.isEmpty) return Stream.value(false);
    return _vipRef(myUid, targetUid).onValue.map(
        (e) => e.snapshot.exists && e.snapshot.value == true);
  }

  /// Adiciona [targetUid] como amigo VIP de [myUid].
  /// Só funciona se [myUid] já segue [targetUid].
  Future<bool> adicionarVip(String myUid, String targetUid) async {
    if (myUid.isEmpty || targetUid.isEmpty || myUid == targetUid) return false;
    final seguindo = await isSeguindo(myUid, targetUid);
    if (!seguindo) return false; // precisa seguir primeiro
    await _vipRef(myUid, targetUid).set(true);
    return true;
  }

  /// Remove [targetUid] dos amigos VIP de [myUid].
  Future<void> removerVip(String myUid, String targetUid) async {
    if (myUid.isEmpty || targetUid.isEmpty) return;
    await _vipRef(myUid, targetUid).remove();
  }

  /// Toggle VIP. Retorna o novo estado (true = é VIP agora).
  /// Se não estiver seguindo, retorna false sem fazer nada.
  Future<bool> toggleVip(String myUid, String targetUid) async {
    final jaVip = await isVip(myUid, targetUid);
    if (jaVip) {
      await removerVip(myUid, targetUid);
      return false;
    } else {
      return await adicionarVip(myUid, targetUid);
    }
  }

  /// Lista de UIDs que [myUid] tem como amigos VIP.
  Future<List<String>> getVipFriends(String myUid) async {
    try {
      final snap = await _vipAllRef(myUid).get();
      if (!snap.exists || snap.value is! Map) return [];
      return (snap.value as Map).keys.map((k) => k.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  /// Ao deixar de seguir, remove automaticamente o VIP se existir.
  /// Já chamado internamente por [deixarDeSeguir].
  Future<void> _limparVipSeNecessario(String myUid, String targetUid) async {
    try {
      await _vipRef(myUid, targetUid).remove();
    } catch (_) {}
  }
}