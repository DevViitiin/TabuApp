// lib/services/story_service.dart
import 'package:firebase_database/firebase_database.dart';
import 'package:tabuapp/models/story_model.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  STORY SERVICE  —  Firebase Realtime Database
//
//  Estrutura no RTDB:
//
//  Posts/
//    story/
//      {storyId}/
//        user_id, type, media_url, thumb_url?, background, central_text,
//        central_emoji, text_style, video_duration?,
//        created_at, expires_at, view_count
//        overlays/
//          0/  { type, content, pos_x, pos_y, scale, style }
//        views/
//          {viewerId}/  { viewer_id, seen_at, fully_watched }
// ══════════════════════════════════════════════════════════════════════════════

class StoryService {
  StoryService._();
  static final StoryService instance = StoryService._();

  final _db = FirebaseDatabase.instance;

  DatabaseReference get _storiesRef  => _db.ref('Posts/story');
  DatabaseReference _storyRef(String id)           => _storiesRef.child(id);
  DatabaseReference _viewsRef(String storyId)      => _storyRef(storyId).child('views');
  DatabaseReference _viewerRef(String storyId, String viewerId)
      => _viewsRef(storyId).child(viewerId);

  // ══════════════════════════════════════════════════════════════════════════
  //  CRIAR STORY
  // ══════════════════════════════════════════════════════════════════════════

  Future<String> createStory({
    required String userId,
    required String userName,
    String?  userAvatar,
    required String type,                // 'camera' | 'texto' | 'emoji' | 'video'
    String?  mediaUrl,
    String?  thumbUrl,                   // thumbnail do vídeo
    String?  background,
    String?  centralText,
    String?  centralEmoji,
    String?  textStyle,
    int?     videoDuration,              // duração em segundos
    List<StoryOverlay> overlays = const [],
    String visibilidade = 'publico',
  }) async {
    final newRef = _storiesRef.push();
    final id     = newRef.key!;

    final now     = DateTime.now();
    final expires = now.add(const Duration(hours: 24));

    final story = StoryModel(
      id:            id,
      userId:        userId,
      userName:      userName,
      userAvatar:    userAvatar,
      type:          type,
      mediaUrl:      mediaUrl,
      thumbUrl:      thumbUrl,
      background:    background,
      centralText:   centralText,
      centralEmoji:  centralEmoji,
      visibilidade:  visibilidade,
      textStyle:     textStyle,
      videoDuration: videoDuration,
      overlays:      overlays,
      createdAt:     now,
      expiresAt:     expires,
    );

    await newRef.set(story.toMap());
    return id;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  LER STORIES
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<StoryModel>> fetchActiveStories() async {
    final snap = await _storiesRef.get();
    if (!snap.exists || snap.value == null) return [];

    final raw   = Map<dynamic, dynamic>.from(snap.value as Map);
    final now   = DateTime.now().millisecondsSinceEpoch;
    final list  = <StoryModel>[];

    for (final entry in raw.entries) {
      if (entry.value is! Map) continue;
      final id   = entry.key as String;
      final data = Map<dynamic, dynamic>.from(entry.value as Map);
      final exp  = data['expires_at'] as int? ?? 0;
      if (exp > now) {
        list.add(StoryModel.fromMap(id, data));
      }
    }

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<List<StoryModel>> fetchStoriesByUser(String userId) async {
    final snap = await _storiesRef.get();
    if (!snap.exists || snap.value == null) return [];

    final raw  = Map<dynamic, dynamic>.from(snap.value as Map);
    final now  = DateTime.now().millisecondsSinceEpoch;
    final list = <StoryModel>[];

    for (final entry in raw.entries) {
      if (entry.value is! Map) continue;
      final id   = entry.key as String;
      final data = Map<dynamic, dynamic>.from(entry.value as Map);
      if (data['user_id'] != userId) continue;
      final exp = data['expires_at'] as int? ?? 0;
      if (exp > now) {
        list.add(StoryModel.fromMap(id, data));
      }
    }

    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  Future<StoryModel?> fetchStoryById(String storyId) async {
    final snap = await _storyRef(storyId).get();
    if (!snap.exists || snap.value == null) return null;
    return StoryModel.fromMap(storyId, Map<dynamic, dynamic>.from(snap.value as Map));
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  STREAM (tempo real)
  // ══════════════════════════════════════════════════════════════════════════

  Stream<List<StoryModel>> streamActiveStories() {
    return _storiesRef.onValue.map((event) {
      if (event.snapshot.value == null) return [];

      final raw  = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final now  = DateTime.now().millisecondsSinceEpoch;
      final list = <StoryModel>[];

      for (final entry in raw.entries) {
        if (entry.value is! Map) continue;
        final id   = entry.key as String;
        final data = Map<dynamic, dynamic>.from(entry.value as Map);
        final exp  = data['expires_at'] as int? ?? 0;
        if (exp > now) list.add(StoryModel.fromMap(id, data));
      }

      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Stream<List<StoryModel>> streamStoriesByUser(String userId) {
    return _storiesRef
        .orderByChild('user_id')
        .equalTo(userId)
        .onValue
        .map((event) {
      if (event.snapshot.value == null) return [];

      final raw  = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final now  = DateTime.now().millisecondsSinceEpoch;
      final list = <StoryModel>[];

      for (final entry in raw.entries) {
        if (entry.value is! Map) continue;
        final id   = entry.key as String;
        final data = Map<dynamic, dynamic>.from(entry.value as Map);
        final exp  = data['expires_at'] as int? ?? 0;
        if (exp > now) list.add(StoryModel.fromMap(id, data));
      }

      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  VISUALIZAÇÕES
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> markAsViewed({
    required String storyId,
    required String viewerId,
    bool fullyWatched = false,
  }) async {
    final view = StoryView(
      viewerId:     viewerId,
      seenAt:       DateTime.now(),
      fullyWatched: fullyWatched,
    );
    await _viewerRef(storyId, viewerId).set(view.toMap());
  }

  Future<void> updateFullyWatched({
    required String storyId,
    required String viewerId,
  }) async {
    await _viewerRef(storyId, viewerId).update({'fully_watched': true});
  }

  Future<List<StoryView>> fetchViews(String storyId) async {
    final snap = await _viewsRef(storyId).get();
    if (!snap.exists || snap.value == null) return [];

    final raw  = Map<dynamic, dynamic>.from(snap.value as Map);
    final list = raw.values
        .where((v) => v is Map)
        .map((v) => StoryView.fromMap(v as Map))
        .toList();

    list.sort((a, b) => b.seenAt.compareTo(a.seenAt));
    return list;
  }

  Future<bool> hasViewed(String storyId, String viewerId) async {
    final snap = await _viewerRef(storyId, viewerId).get();
    return snap.exists;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DELETAR
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> deleteStory({required String storyId}) async {
    await _db.ref('Posts/story/$storyId').remove();
  }

  Future<int> purgeExpiredStories() async {
    final snap = await _storiesRef.get();
    if (!snap.exists || snap.value == null) return 0;

    final raw = Map<dynamic, dynamic>.from(snap.value as Map);
    final now = DateTime.now().millisecondsSinceEpoch;
    int removed = 0;

    for (final entry in raw.entries) {
      final data = Map<dynamic, dynamic>.from(entry.value as Map);
      final exp  = data['expires_at'] as int? ?? 0;
      if (exp <= now) {
        await _storyRef(entry.key as String).remove();
        removed++;
      }
    }

    return removed;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  HELPERS DE AGRUPAMENTO
  // ══════════════════════════════════════════════════════════════════════════

  Future<Map<String, List<StoryModel>>> fetchStoriesGroupedByUser() async {
    final all = await fetchActiveStories();
    final map = <String, List<StoryModel>>{};
    for (final s in all) {
      map.putIfAbsent(s.userId, () => []).add(s);
    }
    return map;
  }

  Future<Map<String, List<StoryModel>>> fetchStoriesForUser({
    required String myUid,
    required List<String> followingIds,
    required List<String> vipIds,
  }) async {
    final all = await fetchActiveStories();
    final map = <String, List<StoryModel>>{};

    final followingSet = Set<String>.from(followingIds);
    final vipSet       = Set<String>.from(vipIds);

    for (final s in all) {
      final isOwn       = s.userId == myUid;
      final iFollow     = followingSet.contains(s.userId);
      final iAmVipDeles = vipSet.contains(s.userId);

      bool canSee = false;
      if (isOwn)                               canSee = true;
      else if (s.visibilidade == 'publico')    canSee = true;
      else if (s.visibilidade == 'seguidores') canSee = iFollow;
      else if (s.visibilidade == 'vip')        canSee = iAmVipDeles;

      if (canSee) map.putIfAbsent(s.userId, () => []).add(s);
    }
    return map;
  }

  Stream<Map<String, List<StoryModel>>> streamStoriesGroupedByUser() {
    return streamActiveStories().map((list) {
      final map = <String, List<StoryModel>>{};
      for (final s in list) {
        map.putIfAbsent(s.userId, () => []).add(s);
      }
      return map;
    });
  }
}