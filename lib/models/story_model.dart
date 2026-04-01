// lib/models/story_model.dart

// ══════════════════════════════════════════════════════════════════════════════
//  OVERLAY MODEL
// ══════════════════════════════════════════════════════════════════════════════
class StoryOverlay {
  final String type;      // 'text' | 'emoji'
  final String content;
  final double posX;      // 0.0 – 1.0 (proporção da tela)
  final double posY;      // 0.0 – 1.0 (proporção da tela)
  final double? scale;
  final Map<String, dynamic>? style; // { fontStyle, color, etc }

  const StoryOverlay({
    required this.type,
    required this.content,
    required this.posX,
    required this.posY,
    this.scale = 1.0,
    this.style,
  });

  Map<String, dynamic> toMap() => {
    'type':    type,
    'content': content,
    'pos_x':   posX,
    'pos_y':   posY,
    'scale':   scale ?? 1.0,
    if (style != null) 'style': style,
  };

  factory StoryOverlay.fromMap(Map<dynamic, dynamic> map) => StoryOverlay(
    type:    map['type']    as String,
    content: map['content'] as String,
    posX:    (map['pos_x'] as num).toDouble(),
    posY:    (map['pos_y'] as num).toDouble(),
    scale:   (map['scale'] as num? ?? 1.0).toDouble(),
    style:   map['style'] != null
        ? Map<String, dynamic>.from(map['style'] as Map)
        : null,
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  STORY MODEL
// ══════════════════════════════════════════════════════════════════════════════
class StoryModel {
  final String  id;
  final String  userId;
  final String  userName;
  final String? userAvatar;
  final String  type;            // 'camera' | 'texto' | 'emoji' | 'video'
  final String? mediaUrl;
  final String? thumbUrl;        // thumbnail do vídeo
  final String? background;
  final String? centralText;
  final String? centralEmoji;
  final String? textStyle;
  final String  visibilidade;    // 'publico' | 'seguidores' | 'vip'
  final int?    videoDuration;   // duração em segundos (tipo video)
  final List<StoryOverlay> overlays;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int viewCount;

  const StoryModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.type,
    this.visibilidade = 'publico',
    this.mediaUrl,
    this.thumbUrl,
    this.background,
    this.centralText,
    this.centralEmoji,
    this.textStyle,
    this.videoDuration,
    this.overlays = const [],
    required this.createdAt,
    required this.expiresAt,
    this.viewCount = 0,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isActive  => !isExpired;
  bool get isVideo   => type == 'video';

  Map<String, dynamic> toMap() => {
    'user_id':       userId,
    'user_name':     userName,
    if (userAvatar    != null) 'user_avatar':   userAvatar,
    'type':          type,
    if (mediaUrl      != null) 'media_url':     mediaUrl,
    if (thumbUrl      != null) 'thumb_url':     thumbUrl,
    if (background    != null) 'background':    background,
    if (centralText   != null) 'central_text':  centralText,
    if (centralEmoji  != null) 'central_emoji': centralEmoji,
    'visibilidade':  visibilidade,
    if (textStyle     != null) 'text_style':    textStyle,
    if (videoDuration != null) 'video_duration': videoDuration,
    // Salva sempre como Map com índices string — consistente para leitura
    'overlays': {
      for (int i = 0; i < overlays.length; i++) '$i': overlays[i].toMap()
    },
    'created_at': createdAt.millisecondsSinceEpoch,
    'expires_at': expiresAt.millisecondsSinceEpoch,
    'view_count': viewCount,
  };

  factory StoryModel.fromMap(String id, Map<dynamic, dynamic> map) {
    final overlaysList = _parseOverlays(map['overlays']);

    return StoryModel(
      id:            id,
      userId:        map['user_id']        as String,
      userName:      map['user_name']      as String? ?? '',
      userAvatar:    map['user_avatar']    as String?,
      type:          map['type']           as String,
      mediaUrl:      map['media_url']      as String?,
      thumbUrl:      map['thumb_url']      as String?,
      background:    map['background']     as String?,
      centralText:   map['central_text']   as String?,
      centralEmoji:  map['central_emoji']  as String?,
      visibilidade:  map['visibilidade']   as String? ?? 'publico',
      textStyle:     map['text_style']     as String?,
      videoDuration: map['video_duration'] as int?,
      overlays:      overlaysList,
      createdAt:     DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      expiresAt:     DateTime.fromMillisecondsSinceEpoch(map['expires_at'] as int),
      viewCount:     (map['view_count']    as int? ?? 0),
    );
  }

  static List<StoryOverlay> _parseOverlays(dynamic raw) {
    if (raw == null) return const [];

    final result = <StoryOverlay>[];

    try {
      if (raw is List) {
        for (final item in raw) {
          if (item is Map) result.add(StoryOverlay.fromMap(item));
        }
      } else if (raw is Map) {
        final entries = raw.entries.toList()
          ..sort((a, b) {
            final ia = int.tryParse(a.key.toString()) ?? 0;
            final ib = int.tryParse(b.key.toString()) ?? 0;
            return ia.compareTo(ib);
          });
        for (final entry in entries) {
          if (entry.value is Map) result.add(StoryOverlay.fromMap(entry.value as Map));
        }
      }
    } catch (_) {}

    return result;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  STORY VIEW MODEL
// ══════════════════════════════════════════════════════════════════════════════
class StoryView {
  final String   viewerId;
  final DateTime seenAt;
  final bool     fullyWatched;

  const StoryView({
    required this.viewerId,
    required this.seenAt,
    this.fullyWatched = false,
  });

  Map<String, dynamic> toMap() => {
    'viewer_id':     viewerId,
    'seen_at':       seenAt.millisecondsSinceEpoch,
    'fully_watched': fullyWatched,
  };

  factory StoryView.fromMap(Map<dynamic, dynamic> map) => StoryView(
    viewerId:     map['viewer_id']    as String,
    seenAt:       DateTime.fromMillisecondsSinceEpoch(map['seen_at'] as int),
    fullyWatched: map['fully_watched'] as bool? ?? false,
  );
}