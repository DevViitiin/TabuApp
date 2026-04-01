// lib/services/chat_request_service.dart
//
// ESTRATÉGIA DE PATH:
//   Chave da solicitação = uid menor + "_" + uid maior (mesma lógica do chatId)
//   Isso permite leitura direta sem queries que exigem .indexOn no Firebase.
//
// Firebase:
//   ChatRequests/
//     {uidA_uidB}/
//       from_uid, to_uid, from_name, from_avatar
//       status: "pending" | "accepted" | "declined"
//       created_at, seen
//
//   UserChatRequests/
//     {myUid}/
//       {uidA_uidB}: "pending" | "accepted" | "declined"
//
//   Chats/ e ChatMessages/ são criados AQUI ao aceitar (não no ChatRoomScreen)

import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:tabuapp/models/chat_request_model.dart';


class ChatRequestService {
  static final ChatRequestService _i = ChatRequestService._();
  factory ChatRequestService() => _i;
  ChatRequestService._();

  final _db = FirebaseDatabase.instance;

  // ─── Chave determinística (igual ao chatId) ───────────────────────────────
  static String buildKey(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  static String _requestKey(String uid1, String uid2) => buildKey(uid1, uid2);

  // ══════════════════════════════════════════════════════════════════════════
  // ENVIAR SOLICITAÇÃO
  // ══════════════════════════════════════════════════════════════════════════

  Future<String> sendRequest({
    required String fromUid,
    required String toUid,
    required String fromName,
    required String fromAvatar,
  }) async {
    final key = _requestKey(fromUid, toUid);

    final snap = await _db.ref('ChatRequests/$key').get();

    if (snap.exists && snap.value is Map) {
      final existing = ChatRequest.fromMap(key, snap.value as Map<dynamic, dynamic>);
      if (existing.isAccepted) return 'accepted';
      if (existing.isPending)  return 'exists';
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final request = ChatRequest(
      id:          key,
      fromUid:     fromUid,
      toUid:       toUid,
      fromName:    fromName,
      fromAvatar:  fromAvatar,
      status:      'pending',
      createdAt:   now,
      seen:        false,
    );

    await _db.ref().update({
      'ChatRequests/$key':               request.toMap(),
      'UserChatRequests/$toUid/$key':    'pending',
      'UserChatRequests/$fromUid/$key':  'pending',
    });

    return 'sent';
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ACEITAR — cria o chat no mesmo batch write
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> acceptRequest(String requestKey, String myUid) async {
    // Busca os dados completos da solicitação
    final reqSnap = await _db.ref('ChatRequests/$requestKey').get();
    if (!reqSnap.exists || reqSnap.value is! Map) return;

    final reqData = reqSnap.value as Map<dynamic, dynamic>;
    final fromUid = reqData['from_uid'] as String? ?? '';
    if (fromUid.isEmpty) return;

    // chatId = mesmo algoritmo do TabuChat.buildChatId
    final sorted = ([myUid, fromUid]..sort());
    final chatId = '${sorted[0]}_${sorted[1]}';
    final now    = DateTime.now().millisecondsSinceEpoch;

    // Verifica se o chat já existe (não sobrescreve mensagens existentes)
    final chatSnap = await _db.ref('Chats/$chatId').get();

    // Monta o batch — atualiza solicitação + cria chat (se necessário)
    final updates = <String, dynamic>{
      // Solicitação
      'ChatRequests/$requestKey/status':         'accepted',
      'ChatRequests/$requestKey/seen':           true,
      'UserChatRequests/$myUid/$requestKey':     'accepted',
      'UserChatRequests/$fromUid/$requestKey':   'accepted',
    };

    if (!chatSnap.exists) {
      // Estrutura inicial do chat — idêntica ao TabuChat.createInitialStructure
      updates['Chats/$chatId/user1']                              = sorted[0];
      updates['Chats/$chatId/user2']                              = sorted[1];
      updates['Chats/$chatId/metadata/last_message']              = '';
      updates['Chats/$chatId/metadata/last_sender']               = '';
      updates['Chats/$chatId/metadata/last_timestamp']            = 0;
      updates['Chats/$chatId/metadata/created_at']                = now;
      updates['Chats/$chatId/unreadCount/${sorted[0]}']           = 0;
      updates['Chats/$chatId/unreadCount/${sorted[1]}']           = 0;
      updates['Chats/$chatId/participants/${sorted[0]}/status']    = 'offline';
      updates['Chats/$chatId/participants/${sorted[0]}/last_seen'] = now;
      updates['Chats/$chatId/participants/${sorted[1]}/status']    = 'offline';
      updates['Chats/$chatId/participants/${sorted[1]}/last_seen'] = now;
      // Placeholder para o nó de mensagens (Firebase não aceita path vazio)
      updates['ChatMessages/$chatId/_placeholder/_init']           = true;
    }

    await _db.ref().update(updates);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // RECUSAR
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> declineRequest(String requestKey, String myUid) async {
    final snap    = await _db.ref('ChatRequests/$requestKey/from_uid').get();
    final fromUid = snap.value as String? ?? '';

    await _db.ref().update({
      'ChatRequests/$requestKey/status':         'declined',
      'ChatRequests/$requestKey/seen':           true,
      'UserChatRequests/$myUid/$requestKey':     'declined',
      if (fromUid.isNotEmpty)
        'UserChatRequests/$fromUid/$requestKey': 'declined',
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CONSULTA PONTUAL
  // ══════════════════════════════════════════════════════════════════════════

  Future<ChatRequest?> getRequestBetween(String uid1, String uid2) async {
    try {
      final key  = _requestKey(uid1, uid2);
      final snap = await _db
          .ref('ChatRequests/$key')
          .get()
          .timeout(const Duration(seconds: 8));

      if (!snap.exists || snap.value is! Map) return null;
      final req = ChatRequest.fromMap(key, snap.value as Map<dynamic, dynamic>);
      return req.isDeclined ? null : req;
    } catch (_) {
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STREAMS
  // ══════════════════════════════════════════════════════════════════════════

  Stream<List<ChatRequest>> pendingRequestsStream(String myUid) {
    return _db
        .ref('UserChatRequests/$myUid')
        .onValue
        .asyncMap((event) async {
      if (!event.snapshot.exists || event.snapshot.value is! Map) {
        return <ChatRequest>[];
      }

      final keys = <String>[];
      (event.snapshot.value as Map<dynamic, dynamic>).forEach((key, status) {
        if (status == 'pending') keys.add(key.toString());
      });

      if (keys.isEmpty) return <ChatRequest>[];

      final futures = keys.map((key) => _db.ref('ChatRequests/$key').get());
      final snaps   = await Future.wait(futures);

      final list = <ChatRequest>[];
      for (final s in snaps) {
        if (s.exists && s.value is Map) {
          try {
            final req = ChatRequest.fromMap(
                s.key!, s.value as Map<dynamic, dynamic>);
            // Só recebidas (não enviadas)
            if (req.toUid == myUid && req.isPending) {
              list.add(req);
            }
          } catch (_) {}
        }
      }

      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Stream<int> unseenCountStream(String myUid) {
    return pendingRequestsStream(myUid)
        .map((list) => list.where((r) => !r.seen).length);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MARK AS SEEN
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> markAllAsSeen(String myUid) async {
    try {
      final snap = await _db.ref('UserChatRequests/$myUid').get();
      if (!snap.exists || snap.value is! Map) return;

      final updates = <String, dynamic>{};
      (snap.value as Map<dynamic, dynamic>).forEach((key, status) {
        if (status == 'pending') {
          updates['ChatRequests/$key/seen'] = true;
        }
      });

      if (updates.isNotEmpty) await _db.ref().update(updates);
    } catch (_) {}
  }
}