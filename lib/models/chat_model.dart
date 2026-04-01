// lib/models/chat_model.dart

class TabuChat {
  final String chatId;
  final String user1Id;
  final String user2Id;
  final ChatMetadata metadata;
  final Map<String, int> unreadCount;
  final Map<String, ParticipantStatus> participants;

  TabuChat({
    required this.chatId,
    required this.user1Id,
    required this.user2Id,
    required this.metadata,
    required this.unreadCount,
    required this.participants,
  });

  /// chatId é sempre os dois UIDs ordenados: menor_maior
  static String buildChatId(String uidA, String uidB) {
    final sorted = [uidA, uidB]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  factory TabuChat.fromMap(String chatId, Map<dynamic, dynamic> map) {
    final metaMap = map['metadata'] as Map<dynamic, dynamic>?;
    final unreadMap = map['unreadCount'] as Map<dynamic, dynamic>? ?? {};
    final participantsMap = map['participants'] as Map<dynamic, dynamic>? ?? {};

    final participants = <String, ParticipantStatus>{};
    participantsMap.forEach((uid, val) {
      if (val is Map) {
        participants[uid.toString()] = ParticipantStatus.fromMap(val);
      }
    });

    final unread = <String, int>{};
    unreadMap.forEach((uid, val) {
      unread[uid.toString()] = (val as num?)?.toInt() ?? 0;
    });

    return TabuChat(
      chatId: chatId,
      user1Id: map['user1'] as String? ?? '',
      user2Id: map['user2'] as String? ?? '',
      metadata: metaMap != null
          ? ChatMetadata.fromMap(metaMap)
          : ChatMetadata.empty(),
      unreadCount: unread,
      participants: participants,
    );
  }

  Map<String, dynamic> toMap() => {
        'user1': user1Id,
        'user2': user2Id,
        'metadata': metadata.toMap(),
        'unreadCount': unreadCount,
        'participants': participants
            .map((uid, p) => MapEntry(uid, p.toMap())),
      };

  static Map<String, dynamic> createInitialStructure(
      String uid1, String uid2) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final sorted = [uid1, uid2]..sort();
    return {
      'user1': sorted[0],
      'user2': sorted[1],
      'metadata': {
        'last_message': '',
        'last_sender': '',
        'last_timestamp': 0,
        'created_at': now,
      },
      'unreadCount': {uid1: 0, uid2: 0},
      'participants': {
        uid1: {'status': 'offline', 'last_seen': now},
        uid2: {'status': 'offline', 'last_seen': now},
      },
    };
  }

  /// Retorna o UID do outro participante dado o meu UID
  String otherUserId(String myUid) =>
      user1Id == myUid ? user2Id : user1Id;

  int myUnreadCount(String myUid) => unreadCount[myUid] ?? 0;

  TabuChat copyWith({
    ChatMetadata? metadata,
    Map<String, int>? unreadCount,
    Map<String, ParticipantStatus>? participants,
  }) =>
      TabuChat(
        chatId: chatId,
        user1Id: user1Id,
        user2Id: user2Id,
        metadata: metadata ?? this.metadata,
        unreadCount: unreadCount ?? this.unreadCount,
        participants: participants ?? this.participants,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
class ChatMetadata {
  final String lastMessage;
  final String lastSender; // UID de quem enviou
  final int lastTimestamp;
  final int? createdAt;

  ChatMetadata({
    required this.lastMessage,
    required this.lastSender,
    required this.lastTimestamp,
    this.createdAt,
  });

  factory ChatMetadata.fromMap(Map<dynamic, dynamic> map) => ChatMetadata(
        lastMessage: map['last_message'] as String? ?? '',
        lastSender: map['last_sender'] as String? ?? '',
        lastTimestamp: (map['last_timestamp'] as num?)?.toInt() ?? 0,
        createdAt: (map['created_at'] as num?)?.toInt(),
      );

  factory ChatMetadata.empty() =>
      ChatMetadata(lastMessage: '', lastSender: '', lastTimestamp: 0);

  Map<String, dynamic> toMap() => {
        'last_message': lastMessage,
        'last_sender': lastSender,
        'last_timestamp': lastTimestamp,
        if (createdAt != null) 'created_at': createdAt,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
class ParticipantStatus {
  final String status; // 'online' | 'offline'
  final int lastSeen;

  ParticipantStatus({required this.status, required this.lastSeen});

  bool get isOnline => status == 'online';

  factory ParticipantStatus.fromMap(Map<dynamic, dynamic> map) =>
      ParticipantStatus(
        status: map['status'] as String? ?? 'offline',
        lastSeen: (map['last_seen'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      );

  Map<String, dynamic> toMap() => {
        'status': status,
        'last_seen': lastSeen,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
class ChatMessage {
  final String id;
  final String text;
  final String senderId;
  final int timestamp;
  final Map<String, bool> readBy;     // { uid: true/false }
  final Map<String, int>  readAt;     // { uid: timestampMs } — quando foi lido

  ChatMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.timestamp,
    required this.readBy,
    this.readAt = const {},
  });

  bool isReadBy(String uid) => readBy[uid] == true;

  /// Retorna o timestamp em ms de quando [uid] leu, ou null se ainda não leu
  int? readAtBy(String uid) => readAt[uid];

  factory ChatMessage.fromMap(String id, Map<dynamic, dynamic> map) {
    final readByMap = map['read_by'] as Map<dynamic, dynamic>? ?? {};
    final readBy = <String, bool>{};
    readByMap.forEach((uid, val) {
      readBy[uid.toString()] = val == true;
    });

    final readAtMap = map['read_at'] as Map<dynamic, dynamic>? ?? {};
    final readAt = <String, int>{};
    readAtMap.forEach((uid, val) {
      final ts = (val as num?)?.toInt();
      if (ts != null) readAt[uid.toString()] = ts;
    });

    return ChatMessage(
      id:        id,
      text:      map['text']      as String? ?? '',
      senderId:  map['sender_id'] as String? ?? '',
      timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
      readBy:    readBy,
      readAt:    readAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'text':      text,
        'sender_id': senderId,
        'timestamp': timestamp,
        'read_by':   readBy,
        if (readAt.isNotEmpty) 'read_at': readAt,
      };
}