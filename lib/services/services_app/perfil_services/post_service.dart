// lib/services/services_app/post_service_paginated.dart

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:tabuapp/models/post_model.dart';
import 'package:tabuapp/services/services_app/perfil_services/cached_perfil_service.dart';

/// ══════════════════════════════════════════════════════════════════════════════
///  POST SERVICE (COM PAGINAÇÃO E CACHE)
/// ══════════════════════════════════════════════════════════════════════════════

class PostServicePaginated {
  PostServicePaginated._();
  static final PostServicePaginated instance = PostServicePaginated._();

  final _db = FirebaseDatabase.instance;
  final _cache = CacheService.instance;

  DatabaseReference get _postsRef => _db.ref('Posts/post');

  static const int pageSize = 10; // Posts por página

  /// Busca posts com paginação (cursor-based)
  Future<List<PostModel>> fetchPostsByUser(
    String userId, {
    DateTime? startAfter, // Cursor de paginação
    bool useCache = true,
  }) async {
    final cacheKey = 'posts_$userId${startAfter != null ? '_${startAfter.millisecondsSinceEpoch}' : ''}';

    // 1. Tenta cache
    if (useCache) {
      final cached = await _cache.get<List>(cacheKey);
      if (cached != null) {
        return cached
            .map((json) => PostModel.fromMap(json['id'], json))
            .toList()
            .cast<PostModel>();
      }
    }

    // 2. Busca do Firebase
    debugPrint('[PostService] 🌐 Buscando posts de $userId...');
    final snap = await _postsRef.get();
    if (!snap.exists || snap.value == null) return [];

    final raw = Map<dynamic, dynamic>.from(snap.value as Map);
    final List<PostModel> list = [];

    for (final entry in raw.entries) {
      if (entry.value is! Map) continue;
      try {
        final data = Map<dynamic, dynamic>.from(entry.value as Map);
        if (data['user_id'] != userId) continue;
        if (data['created_at'] == null) continue;

        final post = PostModel.fromMap(entry.key as String, data);

        // Filtro de paginação
        if (startAfter != null && !post.createdAt.isBefore(startAfter)) continue;

        list.add(post);
      } catch (e) {
        debugPrint('[PostService] ⚠️  Parse error: $e');
      }
    }

    // Ordena e limita
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final page = list.take(pageSize).toList();

    // 3. Salva no cache
    await _cache.set(
      cacheKey,
      page.map((p) => {...p.toMap(), 'id': p.id}).toList(),
      ttl: const Duration(minutes: 15),
    );

    debugPrint('[PostService] ✅ ${page.length} posts carregados');
    return page;
  }

  /// Invalida cache de posts do usuário
  Future<void> invalidateUserCache(String userId) async {
    await _cache.invalidatePrefix('posts_$userId');
  }
}