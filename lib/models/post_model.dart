// lib/models/post_model.dart

// ══════════════════════════════════════════════════════════════════════════════
//  POST MODEL
// ══════════════════════════════════════════════════════════════════════════════
class PostModel {
  final String  id;
  final String  userId;
  final String  userName;
  final String? userAvatar;
  final String  titulo;
  final String? descricao;
  final String  tipo;           // 'foto' | 'texto' | 'emoji' | 'video'
  final String  visibilidade;   // 'publico' | 'amigos' | 'privado'
  final String? mediaUrl;       // URL da foto ou vídeo (Firebase Storage)
  final String? thumbUrl;       // thumbnail do vídeo (gerada no upload)
  final String? emoji;          // emoji escolhido (tipo emoji)
  final int?    videoDuration;  // duração em segundos (tipo video)
  final DateTime createdAt;
  int    likes;
  int    commentCount;  // campo separado do nó comments/ no RTDB

  PostModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.titulo,
    this.descricao,
    required this.tipo,
    required this.visibilidade,
    this.mediaUrl,
    this.thumbUrl,
    this.emoji,
    this.videoDuration,
    required this.createdAt,
    this.likes        = 0,
    this.commentCount = 0,
  });

  bool get isVideo => tipo == 'video';

  Map<String, dynamic> toMap() => {
    'user_id':       userId,
    'user_name':     userName,
    if (userAvatar     != null) 'user_avatar':     userAvatar,
    'titulo':        titulo,
    if (descricao    != null) 'descricao':         descricao,
    'tipo':          tipo,
    'visibilidade':  visibilidade,
    if (mediaUrl     != null) 'media_url':         mediaUrl,
    if (thumbUrl     != null) 'thumb_url':         thumbUrl,
    if (emoji        != null) 'emoji':             emoji,
    if (videoDuration != null) 'video_duration':   videoDuration,
    'created_at':    createdAt.millisecondsSinceEpoch,
    'likes':          likes,
    'comment_count':  commentCount,
  };

  factory PostModel.fromMap(String id, Map<dynamic, dynamic> map) => PostModel(
    id:             id,
    userId:         map['user_id']       as String,
    userName:       map['user_name']     as String? ?? '',
    userAvatar:     map['user_avatar']   as String?,
    titulo:         map['titulo']        as String? ?? '',
    descricao:      map['descricao']     as String?,
    tipo:           map['tipo']          as String? ?? 'texto',
    visibilidade:   map['visibilidade']  as String? ?? 'publico',
    mediaUrl:       map['media_url']     as String?,
    thumbUrl:       map['thumb_url']     as String?,
    emoji:          map['emoji']         as String?,
    videoDuration:  map['video_duration'] as int?,
    createdAt:      DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    likes:          (map['likes']         as int? ?? 0),
    commentCount:   (map['comment_count'] as int? ?? (map['comments'] as int? ?? 0)),
  );
}