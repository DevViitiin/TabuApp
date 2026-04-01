// lib/models/chat_request_model.dart
//
// Estrutura Firebase:
//
// ChatRequests/
//   {requestId}/                         ← push key
//     from_uid:    "uid_remetente"
//     to_uid:      "uid_destinatario"
//     from_name:   "VICTOR"
//     from_avatar: "https://..."
//     status:      "pending" | "accepted" | "declined"
//     created_at:  1774020837569
//     seen:        false
//
// UserChatRequests/
//   {uid}/                               ← índice por destinatário (para stream rápido)
//     {requestId}: "pending" | "accepted" | "declined"

class ChatRequest {
  final String id;
  final String fromUid;
  final String toUid;
  final String fromName;
  final String fromAvatar;
  final String status; // 'pending' | 'accepted' | 'declined'
  final int createdAt;
  final bool seen;

  ChatRequest({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.fromName,
    required this.fromAvatar,
    required this.status,
    required this.createdAt,
    required this.seen,
  });

  bool get isPending  => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isDeclined => status == 'declined';

  factory ChatRequest.fromMap(String id, Map<dynamic, dynamic> map) {
    return ChatRequest(
      id:          id,
      fromUid:     map['from_uid']    as String? ?? '',
      toUid:       map['to_uid']      as String? ?? '',
      fromName:    map['from_name']   as String? ?? 'Usuário',
      fromAvatar:  map['from_avatar'] as String? ?? '',
      status:      map['status']      as String? ?? 'pending',
      createdAt:   (map['created_at'] as num?)?.toInt()
                       ?? DateTime.now().millisecondsSinceEpoch,
      seen:        map['seen']        as bool?   ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'from_uid':    fromUid,
    'to_uid':      toUid,
    'from_name':   fromName,
    'from_avatar': fromAvatar,
    'status':      status,
    'created_at':  createdAt,
    'seen':        seen,
  };

  ChatRequest copyWith({String? status, bool? seen}) => ChatRequest(
    id:          id,
    fromUid:     fromUid,
    toUid:       toUid,
    fromName:    fromName,
    fromAvatar:  fromAvatar,
    status:      status      ?? this.status,
    createdAt:   createdAt,
    seen:        seen        ?? this.seen,
  );
}