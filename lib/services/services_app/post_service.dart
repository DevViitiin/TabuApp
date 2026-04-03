// lib/services/services_app/post_service.dart
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:tabuapp/models/comment_model.dart';
import 'package:tabuapp/models/post_model.dart';

class PostService {
  PostService._();
  static final PostService instance = PostService._();

  final _db = FirebaseDatabase.instance;

  DatabaseReference get _postsRef       => _db.ref('Posts/post');
  DatabaseReference _postRef(String id) => _postsRef.child(id);
  DatabaseReference _likedByRef(String postId) =>
      _postRef(postId).child('liked_by');

  // ══════════════════════════════════════════════════════════════════════════
  //  CRIAR
  // ══════════════════════════════════════════════════════════════════════════

  Future<String> createPost({
    required String userId,
    required String userName,
    String?  userAvatar,
    required String titulo,
    String?  descricao,
    required String tipo,
    required String visibilidade,
    String?  mediaUrl,
    String?  thumbUrl,
    String?  emoji,
    int?     videoDuration,
  }) async {
    final ref = _postsRef.push();
    final id  = ref.key!;

    final post = PostModel(
      id:            id,
      userId:        userId,
      userName:      userName,
      userAvatar:    userAvatar,
      titulo:        titulo,
      descricao:     descricao,
      tipo:          tipo,
      visibilidade:  visibilidade,
      mediaUrl:      mediaUrl,
      thumbUrl:      thumbUrl,
      emoji:         emoji,
      videoDuration: videoDuration,
      createdAt:     DateTime.now(),
    );

    await ref.set(post.toMap());
    return id;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  LER — COM PAGINAÇÃO
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<PostModel>> fetchPosts({
    int limit = 10,
    DateTime? startAfter,
  }) async {
    final snap = await _postsRef.get();
    if (!snap.exists || snap.value == null) return [];

    final raw  = Map<dynamic, dynamic>.from(snap.value as Map);
    final list = <PostModel>[];

    for (final entry in raw.entries) {
      if (entry.value is! Map) continue;
      try {
        final data = Map<dynamic, dynamic>.from(entry.value as Map);
        if (data['user_id'] == null || data['created_at'] == null) continue;
        list.add(PostModel.fromMap(entry.key as String, data));
      } catch (_) {
        continue;
      }
    }

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (startAfter != null) {
      final filtered = list.where((p) => p.createdAt.isBefore(startAfter)).toList();
      return filtered.take(limit).toList();
    }

    return list.take(limit).toList();
  }

  // ✅ MÉTODO ATUALIZADO COM PAGINAÇÃO REAL
  Future<List<PostModel>> fetchPostsByUser(
    String userId, {
    int limit = 3,
    DateTime? startAfter,
  }) async {
    final snap = await _postsRef.get();
    if (!snap.exists || snap.value == null) return [];

    final raw  = Map<dynamic, dynamic>.from(snap.value as Map);
    final list = <PostModel>[];

    for (final entry in raw.entries) {
      if (entry.value is! Map) continue;

      try {
        final data = Map<dynamic, dynamic>.from(entry.value as Map);

        if (data['user_id'] != userId) continue;
        if (data['created_at'] == null) continue;

        final post = PostModel.fromMap(entry.key as String, data);

        // 🔥 FILTRO DE CURSOR (ESSENCIAL PRA PAGINAÇÃO)
        if (startAfter != null && !post.createdAt.isBefore(startAfter)) {
          continue;
        }

        list.add(post);
      } catch (e) {
        debugPrint('[PostService] parse error: $e');
      }
    }

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list.take(limit).toList();
  }

  Future<PostModel?> fetchPostById(String postId) async {
    final snap = await _postRef(postId).get();
    if (!snap.exists || snap.value == null) return null;

    return PostModel.fromMap(
      postId,
      Map<dynamic, dynamic>.from(snap.value as Map),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  STREAM TEMPO REAL
  // ══════════════════════════════════════════════════════════════════════════

  Stream<List<PostModel>> streamPosts({int limit = 30}) {
    return _postsRef.onValue.map((event) {
      if (event.snapshot.value == null) return [];

      final raw  = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final list = <PostModel>[];

      for (final entry in raw.entries) {
        if (entry.value is! Map) continue;
        try {
          final data = Map<dynamic, dynamic>.from(entry.value as Map);
          if (data['user_id'] == null || data['created_at'] == null) continue;
          list.add(PostModel.fromMap(entry.key as String, data));
        } catch (_) {
          continue;
        }
      }

      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list.take(limit).toList();
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CURTIR / DESCURTIR
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> toggleLike(String postId, String userId) async {
    final ref      = _likedByRef(postId).child(userId);
    final snap     = await ref.get();
    final jaLikado = snap.exists && snap.value == true;

    if (jaLikado) {
      await ref.remove();
      await _postRef(postId).child('likes').set(ServerValue.increment(-1));
      return false;
    } else {
      await ref.set(true);
      await _postRef(postId).child('likes').set(ServerValue.increment(1));
      return true;
    }
  }

  Future<bool> isLikedBy(String postId, String userId) async {
    final snap = await _likedByRef(postId).child(userId).get();
    return snap.exists && snap.value == true;
  }

  Stream<bool> streamIsLiked(String postId, String userId) {
    return _likedByRef(postId).child(userId).onValue.map(
      (e) => e.snapshot.exists && e.snapshot.value == true,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  COMENTÁRIOS
  // ══════════════════════════════════════════════════════════════════════════

  DatabaseReference _commentsRef(String postId) =>
      _postRef(postId).child('comments');

  DatabaseReference _commentRef(String postId, String commentId) =>
      _commentsRef(postId).child(commentId);

  Future<CommentModel> addComment({
    required String postId,
    required String userId,
    required String userName,
    String?  userAvatar,
    required String texto,
  }) async {
    final ref = _commentsRef(postId).push();
    final id  = ref.key!;

    final comment = CommentModel(
      id:         id,
      postId:     postId,
      userId:     userId,
      userName:   userName,
      userAvatar: userAvatar,
      texto:      texto,
      createdAt:  DateTime.now(),
    );

    await ref.set(comment.toMap());
    await _postRef(postId).child('comment_count')
        .set(ServerValue.increment(1));

    return comment;
  }

  Future<List<CommentModel>> fetchComments(String postId) async {
    final snap = await _commentsRef(postId).get();
    if (!snap.exists || snap.value == null) return [];

    final raw  = Map<dynamic, dynamic>.from(snap.value as Map);
    final list = <CommentModel>[];

    for (final entry in raw.entries) {
      if (entry.value is! Map) continue;
      try {
        final data = Map<dynamic, dynamic>.from(entry.value as Map);
        if (data['user_id'] == null || data['created_at'] == null) continue;
        list.add(CommentModel.fromMap(entry.key as String, data));
      } catch (_) {
        continue;
      }
    }

    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  Stream<List<CommentModel>> streamComments(String postId) {
    return _commentsRef(postId).onValue.map((event) {
      if (event.snapshot.value == null) return [];

      final raw  = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final list = <CommentModel>[];

      for (final entry in raw.entries) {
        if (entry.value is! Map) continue;
        try {
          final data = Map<dynamic, dynamic>.from(entry.value as Map);
          if (data['user_id'] == null || data['created_at'] == null) continue;
          list.add(CommentModel.fromMap(entry.key as String, data));
        } catch (_) {
          continue;
        }
      }

      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return list;
    });
  }

  Future<void> deleteComment(String postId, String commentId) async {
    await _commentRef(postId, commentId).remove();
    await _postRef(postId).child('comment_count')
        .set(ServerValue.increment(-1));
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DELETAR POST
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> deletePost(String postId) async {
    await _postRef(postId).remove();
  }
}