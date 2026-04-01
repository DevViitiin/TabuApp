// lib/models/comment_model.dart

class CommentModel {
  final String   id;
  final String   postId;
  final String   userId;
  final String   userName;
  final String?  userAvatar;
  final String   texto;
  final DateTime createdAt;
  int            likes;

  CommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.texto,
    required this.createdAt,
    this.likes = 0,
  });

  Map<String, dynamic> toMap() => {
    'post_id':    postId,
    'user_id':    userId,
    'user_name':  userName,
    if (userAvatar != null) 'user_avatar': userAvatar,
    'texto':      texto,
    'created_at': createdAt.millisecondsSinceEpoch,
    'likes':      likes,
  };

  factory CommentModel.fromMap(String id, Map<dynamic, dynamic> map) =>
      CommentModel(
        id:         id,
        postId:     map['post_id']   as String? ?? '',
        userId:     map['user_id']   as String? ?? '',
        userName:   map['user_name'] as String? ?? 'Anônimo',
        userAvatar: map['user_avatar'] as String?,
        texto:      map['texto']     as String? ?? '',
        createdAt:  DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        likes:      map['likes']     as int? ?? 0,
      );
}