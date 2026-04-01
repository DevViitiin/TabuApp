// lib/services/tabu_chat_service.dart

import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../../models/chat_model.dart';

class TabuChatService {
  static final TabuChatService _instance = TabuChatService._internal();
  factory TabuChatService() => _instance;
  TabuChatService._internal();

  final FirebaseDatabase _db = FirebaseDatabase.instance;

  static const int _initialLimit = 20;

  // Cache por chatId
  final Map<String, List<ChatMessage>> _cache = {};
  final Map<String, int> _lastTimestamp = {};
  final Map<String, StreamSubscription> _listeners = {};

  // ══════════════════════════════════════════════════════════════════════════
  // REFS
  // ══════════════════════════════════════════════════════════════════════════

  DatabaseReference _chatRef(String chatId) =>
      _db.ref('Chats/$chatId');

  DatabaseReference _messagesRef(String chatId) =>
      _db.ref('ChatMessages/$chatId');

  DatabaseReference _metadataRef(String chatId) =>
      _db.ref('Chats/$chatId/metadata');

  // ══════════════════════════════════════════════════════════════════════════
  // 1. INICIALIZAÇÃO
  // ══════════════════════════════════════════════════════════════════════════

  Future<TabuChat> initializeChat(String myUid, String otherUid) async {
    final chatId = TabuChat.buildChatId(myUid, otherUid);

    final snap = await _chatRef(chatId).get();

    if (!snap.exists || snap.value == null) {
      final initial = TabuChat.createInitialStructure(myUid, otherUid);
      await _chatRef(chatId).set(initial);
      await _ensureMessagesPlaceholder(chatId);
      return TabuChat.fromMap(chatId, initial);
    }

    await _ensureMessagesPlaceholder(chatId);
    return TabuChat.fromMap(chatId, snap.value as Map<dynamic, dynamic>);
  }

  Future<void> _ensureMessagesPlaceholder(String chatId) async {
    final snap = await _messagesRef(chatId).get();
    if (!snap.exists) {
      await _messagesRef(chatId)
          .child('_placeholder')
          .set({'_init': true});
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 2. PRESENÇA
  // ══════════════════════════════════════════════════════════════════════════

  // ── Presença GLOBAL (visível em qualquer tela, não só no chat) ─────────────
  Future<void> setGlobalOnline(String myUid) async {
    final ref = _db.ref('Users/$myUid/presence');
    await ref.update({
      'online':    true,
      'last_seen': ServerValue.timestamp,
    });
    // Firebase marca offline automaticamente ao desconectar
    ref.onDisconnect().update({
      'online':    false,
      'last_seen': ServerValue.timestamp,
    });
  }

  Future<void> setGlobalOffline(String myUid) async {
    await _db.ref('Users/$myUid/presence').update({
      'online':    false,
      'last_seen': ServerValue.timestamp,
    });
  }

  /// Stream do status online de qualquer usuário (global)
  Stream<bool> userOnlineStream(String uid) {
    return _db
        .ref('Users/$uid/presence/online')
        .onValue
        .map((e) => e.snapshot.value == true);
  }

  /// Último visto de qualquer usuário (global)
  Stream<int> userLastSeenStream(String uid) {
    return _db
        .ref('Users/$uid/presence/last_seen')
        .onValue
        .map((e) => (e.snapshot.value as int?) ?? 0);
  }

  // ── Presença por CHAT (mantido para retrocompatibilidade) ──────────────────
  Future<void> setOnline(String chatId, String myUid) async {
    final ref = _db.ref('Chats/$chatId/participants/$myUid');
    await ref.update({
      'status': 'online',
      'last_seen': ServerValue.timestamp,
    });
    ref.onDisconnect().update({
      'status': 'offline',
      'last_seen': ServerValue.timestamp,
    });
  }

  Future<void> setOffline(String chatId, String myUid) async {
    await _db.ref('Chats/$chatId/participants/$myUid').update({
      'status': 'offline',
      'last_seen': ServerValue.timestamp,
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 3. ENVIO
  // ══════════════════════════════════════════════════════════════════════════

  Future<String> sendMessage({
    required String chatId,
    required String text,
    required String senderId,
    required String recipientId,
  }) async {
    if (text.trim().isEmpty) throw Exception('Mensagem vazia');

    final now = DateTime.now().millisecondsSinceEpoch;
    final msgRef = _messagesRef(chatId).push();
    final msgId = msgRef.key!;

    final msg = ChatMessage(
      id: msgId,
      text: text.trim(),
      senderId: senderId,
      timestamp: now,
      readBy: {senderId: true, recipientId: false},
    );

    await msgRef.set(msg.toMap());

    // Incrementa unread do destinatário
    await _db
        .ref('Chats/$chatId/unreadCount/$recipientId')
        .runTransaction((current) =>
            Transaction.success(((current as int?) ?? 0) + 1));

    // Atualiza metadata
    await _metadataRef(chatId).update({
      'last_message': text.trim(),
      'last_sender': senderId,
      'last_timestamp': now,
    });

    return msgId;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 4. STREAM DE MENSAGENS
  // ══════════════════════════════════════════════════════════════════════════

  Stream<List<ChatMessage>> messagesStream(String chatId) {
    final controller = StreamController<List<ChatMessage>>.broadcast();

    _loadInitial(chatId).then((initial) {
      _cache[chatId] = initial;
      if (initial.isNotEmpty) {
        _lastTimestamp[chatId] = initial.last.timestamp;
      }
      controller.add(List.from(initial));
      _setupListeners(chatId, controller);
    });

    return controller.stream;
  }

  Future<List<ChatMessage>> _loadInitial(String chatId) async {
    try {
      final snap = await _messagesRef(chatId)
          .orderByChild('timestamp')
          .limitToLast(_initialLimit)
          .get();

      if (!snap.exists || snap.value is! Map) return [];

      final msgs = <ChatMessage>[];
      (snap.value as Map<dynamic, dynamic>).forEach((key, val) {
        if (key == '_placeholder') return;
        if (val is Map) {
          try {
            msgs.add(ChatMessage.fromMap(key.toString(), val));
          } catch (_) {}
        }
      });

      msgs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return msgs;
    } catch (_) {
      return [];
    }
  }

  void _setupListeners(
      String chatId, StreamController<List<ChatMessage>> controller) {
    final lastTs = _lastTimestamp[chatId] ?? 0;

    // Novas mensagens
    final addSub = _messagesRef(chatId)
        .orderByChild('timestamp')
        .startAfter(lastTs)
        .onChildAdded
        .listen((event) {
      if (event.snapshot.key == '_placeholder') return;
      final val = event.snapshot.value;
      if (val is! Map) return;
      try {
        final msg = ChatMessage.fromMap(event.snapshot.key!, val);
        final current = _cache[chatId] ?? [];
        if (!current.any((m) => m.id == msg.id)) {
          current.add(msg);
          _cache[chatId] = current;
          _lastTimestamp[chatId] = msg.timestamp;
          controller.add(List.from(current));
        }
      } catch (_) {}
    });

    // Atualizações (leitura)
    final changeSub = _messagesRef(chatId).onChildChanged.listen((event) {
      if (event.snapshot.key == '_placeholder') return;
      final val = event.snapshot.value;
      if (val is! Map) return;
      try {
        final updated = ChatMessage.fromMap(event.snapshot.key!, val);
        final current = _cache[chatId] ?? [];
        final idx = current.indexWhere((m) => m.id == updated.id);
        if (idx != -1) {
          current[idx] = updated;
          _cache[chatId] = current;
          controller.add(List.from(current));
        }
      } catch (_) {}
    });

    _listeners['add_$chatId'] = addSub;
    _listeners['change_$chatId'] = changeSub;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 5. PAGINAÇÃO
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<ChatMessage>> loadOlder(
      String chatId, int oldestTimestamp) async {
    try {
      final snap = await _messagesRef(chatId)
          .orderByChild('timestamp')
          .endBefore(oldestTimestamp)
          .limitToLast(20)
          .get();

      if (!snap.exists || snap.value is! Map) return [];

      final msgs = <ChatMessage>[];
      (snap.value as Map<dynamic, dynamic>).forEach((key, val) {
        if (key == '_placeholder') return;
        if (val is Map) {
          try {
            msgs.add(ChatMessage.fromMap(key.toString(), val));
          } catch (_) {}
        }
      });

      msgs.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      final cached = _cache[chatId] ?? [];
      _cache[chatId] = [...msgs, ...cached];

      return msgs;
    } catch (_) {
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 6. MARK AS READ
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> markAsRead(String chatId, String myUid) async {
    try {
      final snap = await _messagesRef(chatId).get();
      if (!snap.exists || snap.value is! Map) return;

      final now     = DateTime.now().millisecondsSinceEpoch;
      final updates = <String, dynamic>{};

      (snap.value as Map<dynamic, dynamic>).forEach((msgId, val) {
        if (msgId == '_placeholder') return;
        if (val is Map) {
          final readBy = val['read_by'] as Map<dynamic, dynamic>?;
          if (readBy != null && readBy[myUid] == false) {
            updates['ChatMessages/$chatId/$msgId/read_by/$myUid'] = true;
            updates['ChatMessages/$chatId/$msgId/read_at/$myUid'] = now;
          }
        }
      });

      if (updates.isNotEmpty) {
        await _db.ref().update(updates);
      }

      await _db.ref('Chats/$chatId/unreadCount/$myUid').set(0);
    } catch (_) {}
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 7. STREAMS AUXILIARES
  // ══════════════════════════════════════════════════════════════════════════

  Stream<ParticipantStatus> otherStatusStream(
      String chatId, String otherUid) {
    return _db
        .ref('Chats/$chatId/participants/$otherUid')
        .onValue
        .map((event) {
      if (!event.snapshot.exists || event.snapshot.value is! Map) {
        return ParticipantStatus(
            status: 'offline',
            lastSeen: DateTime.now().millisecondsSinceEpoch);
      }
      return ParticipantStatus.fromMap(
          event.snapshot.value as Map<dynamic, dynamic>);
    });
  }

  Stream<int> unreadStream(String chatId, String myUid) {
    return _db
        .ref('Chats/$chatId/unreadCount/$myUid')
        .onValue
        .map((event) => (event.snapshot.value as int?) ?? 0);
  }

  /// Stream em tempo real de cada chat individual
  /// Usado pelo _ChatTile para manter última mensagem e status sempre atualizados
  Stream<TabuChat?> singleChatStream(String chatId) {
    return _db.ref('Chats/$chatId').onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value is! Map) return null;
      try {
        return TabuChat.fromMap(chatId, event.snapshot.value as Map<dynamic, dynamic>);
      } catch (_) {
        return null;
      }
    });
  }

  /// Lista dos chatIds aceitos do usuário (stream leve — só o índice)
  /// O _ChatTile assina singleChatStream individualmente para dados em tempo real
  Stream<List<String>> chatIdsStream(String myUid) {
    return _db
        .ref('UserChatRequests/$myUid')
        .onValue
        .map((event) {
      if (!event.snapshot.exists || event.snapshot.value is! Map) return <String>[];
      final ids = <String>[];
      (event.snapshot.value as Map<dynamic, dynamic>).forEach((key, status) {
        if (status == 'accepted') ids.add(key.toString());
      });
      return ids;
    });
  }

  /// Mantido para compatibilidade — usa snapshot único, não reativo a mensagens
  Stream<List<TabuChat>> chatListStream(String myUid) {
    return _db
        .ref('UserChatRequests/$myUid')
        .onValue
        .asyncMap((event) async {
      if (!event.snapshot.exists || event.snapshot.value is! Map) {
        return <TabuChat>[];
      }

      final chatIds = <String>[];
      (event.snapshot.value as Map<dynamic, dynamic>).forEach((key, status) {
        if (status == 'accepted') chatIds.add(key.toString());
      });

      if (chatIds.isEmpty) return <TabuChat>[];

      final futures = chatIds.map((id) => _db.ref('Chats/$id').get());
      final snaps   = await Future.wait(futures);

      final chats = <TabuChat>[];
      for (final snap in snaps) {
        if (snap.exists && snap.value is Map) {
          try {
            chats.add(
                TabuChat.fromMap(snap.key!, snap.value as Map<dynamic, dynamic>));
          } catch (_) {}
        }
      }

      chats.sort(
          (a, b) => b.metadata.lastTimestamp.compareTo(a.metadata.lastTimestamp));
      return chats;
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 8. CLEANUP
  // ══════════════════════════════════════════════════════════════════════════

  void disposeChat(String chatId) {
    _listeners['add_$chatId']?.cancel();
    _listeners['change_$chatId']?.cancel();
    _listeners.remove('add_$chatId');
    _listeners.remove('change_$chatId');
    _cache.remove(chatId);
    _lastTimestamp.remove(chatId);
  }

  void disposeAll() {
    for (final sub in _listeners.values) {
      sub.cancel();
    }
    _listeners.clear();
    _cache.clear();
    _lastTimestamp.clear();
  }
}