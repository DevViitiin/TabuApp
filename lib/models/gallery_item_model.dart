class GalleryItem {
  final String id;
  final String userId;
  final String type;          // 'foto' ou 'video'
  final String mediaUrl;
  final String? thumbUrl;     // Para vídeos
  final int? videoDuration;   // Para vídeos (em segundos)
  final DateTime createdAt;

  const GalleryItem({
    required this.id,
    required this.userId,
    required this.type,
    required this.mediaUrl,
    this.thumbUrl,
    this.videoDuration,
    required this.createdAt,
  });

  // ✅ VERSÃO 1: Para fetchItems() (recebe o map já com 'id' e 'userId')
  factory GalleryItem.fromMap(Map<String, dynamic> map) {
    return GalleryItem(
      id: map['id'] as String? ?? '',
      userId: map['userId'] as String? ?? map['user_id'] as String? ?? '',
      type: map['type'] as String? ?? 'foto',
      mediaUrl: map['mediaUrl'] as String? ?? map['media_url'] as String? ?? '',
      thumbUrl: map['thumbUrl'] as String? ?? map['thumb_url'] as String?,
      videoDuration: map['videoDuration'] as int? ?? map['video_duration'] as int?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['createdAt']?.millisecondsSinceEpoch ?? 
        map['created_at'] as int? ?? 0,
      ),
    );
  }

  // ✅ VERSÃO 2: Para compatibilidade antiga (mantém por segurança)
  factory GalleryItem.fromMapLegacy(String id, Map<dynamic, dynamic> map) {
    return GalleryItem(
      id: id,
      userId: map['user_id'] as String? ?? '',
      type: map['type'] as String? ?? 'foto',
      mediaUrl: map['media_url'] as String? ?? '',
      thumbUrl: map['thumb_url'] as String?,
      videoDuration: map['video_duration'] as int?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at'] as int? ?? 0,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'type': type,
      'media_url': mediaUrl,
      if (thumbUrl != null) 'thumb_url': thumbUrl,
      if (videoDuration != null) 'video_duration': videoDuration,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }
}