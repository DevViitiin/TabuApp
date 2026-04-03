// lib/services/services_app/search_service_paginated.dart
import 'dart:async';
import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:tabuapp/models/user_search.dart';
import 'package:tabuapp/services/services_app/cache_service.dart';

class SearchServicePaginated {
  SearchServicePaginated._();
  static final SearchServicePaginated instance = SearchServicePaginated._();

  final _db = FirebaseDatabase.instance;
  final _cache = CacheService.instance;

  /// Tamanho da página
  static const int pageSize = 10;

  /// TTL do cache: 5 minutos
  static const cacheTTL = Duration(minutes: 5);

  // ══════════════════════════════════════════════════════════════════════════
  //  BUSCA PAGINADA DE USUÁRIOS
  // ══════════════════════════════════════════════════════════════════════════

  /// Busca usuários com paginação
  /// 
  /// [myUid]: UID do usuário atual (para excluir)
  /// [followingIds]: IDs dos usuários que já sigo
  /// [page]: Número da página (0-based)
  /// [query]: Texto de busca (opcional)
  /// [estadoSigla]: Filtro de estado (opcional)
  /// [cidadeNome]: Filtro de cidade (opcional)
  Future<PaginatedUsersResult> fetchUsers({
    required String myUid,
    required Set<String> followingIds,
    int page = 0,
    String? query,
    String? estadoSigla,
    String? cidadeNome,
  }) async {
    // Gera chave de cache única baseada nos filtros
    final cacheKey = _buildUsersCacheKey(
      myUid: myUid,
      page: page,
      query: query,
      estadoSigla: estadoSigla,
      cidadeNome: cidadeNome,
    );

    // Tenta recuperar do cache
    final cached = _cache.get<PaginatedUsersResult>(cacheKey);
    if (cached != null) {
      return cached;
    }

    // Busca do Firebase
    final allUsers = await _fetchAllUsersFromFirebase(myUid, followingIds);

    // Aplica filtros
    var filtered = _applyUserFilters(
      users: allUsers,
      query: query,
      estadoSigla: estadoSigla,
      cidadeNome: cidadeNome,
    );

    // Calcula paginação
    final totalCount = filtered.length;
    final totalPages = (totalCount / pageSize).ceil();
    final hasMore = page < totalPages - 1;

    final startIndex = page * pageSize;
    final endIndex = (startIndex + pageSize).clamp(0, totalCount);

    final pageUsers = startIndex < totalCount
        ? filtered.sublist(startIndex, endIndex)
        : <UserSearchResult>[];

    final result = PaginatedUsersResult(
      users: pageUsers,
      page: page,
      pageSize: pageSize,
      totalCount: totalCount,
      hasMore: hasMore,
    );

    // Armazena no cache
    _cache.set(cacheKey, result, ttl: cacheTTL);

    return result;
  }

  /// Busca todos os usuários do Firebase (com cache)
  Future<List<UserSearchResult>> _fetchAllUsersFromFirebase(
    String myUid,
    Set<String> followingIds,
  ) async {
    // Cache de todos os usuários (chave simples, sem filtros)
    final cacheKey = 'users_all_$myUid';
    final cached = _cache.get<List<UserSearchResult>>(cacheKey);
    if (cached != null) return cached;

    final snap = await _db.ref('Users').get();
    if (!snap.exists || snap.value == null) return [];

    final raw = Map<dynamic, dynamic>.from(snap.value as Map);
    final list = <UserSearchResult>[];

    for (final entry in raw.entries) {
      if (entry.value is! Map) continue;
      final uid = entry.key as String;
      if (uid == myUid) continue;

      final data = Map<String, dynamic>.from(entry.value as Map);
      final name = (data['name'] as String? ?? '').trim();
      if (name.isEmpty) continue;

      final followersMap = data['followers'];
      final followingMap = data['following'];

      list.add(UserSearchResult(
        uid: uid,
        name: name,
        avatar: data['avatar'] as String? ?? '',
        bio: (data['bio'] as String? ?? '').trim(),
        city: data['city'] as String? ?? '',
        state: data['state'] as String? ?? '',
        followersCount: followersMap is Map ? followersMap.length : 0,
        followingCount: followingMap is Map ? followingMap.length : 0,
        latitude: (data['latitude'] as num?)?.toDouble(),
        longitude: (data['longitude'] as num?)?.toDouble(),
      ));
    }

    // Ordena: seguindo primeiro, depois alfabético
    list.sort((a, b) {
      final aFollow = followingIds.contains(a.uid) ? 0 : 1;
      final bFollow = followingIds.contains(b.uid) ? 0 : 1;
      if (aFollow != bFollow) return aFollow.compareTo(bFollow);
      return a.name.compareTo(b.name);
    });

    // Cache por 3 minutos (menos que queries específicas)
    _cache.set(cacheKey, list, ttl: const Duration(minutes: 3));

    return list;
  }

  /// Aplica filtros aos usuários
  List<UserSearchResult> _applyUserFilters({
    required List<UserSearchResult> users,
    String? query,
    String? estadoSigla,
    String? cidadeNome,
  }) {
    var filtered = users;

    // Filtro de estado
    if (estadoSigla != null && estadoSigla.isNotEmpty) {
      final s = _normalize(estadoSigla);
      filtered = filtered.where((u) => _normalize(u.state) == s).toList();
    }

    // Filtro de cidade
    if (cidadeNome != null && cidadeNome.isNotEmpty) {
      final c = _normalize(cidadeNome);
      filtered = filtered.where((u) => _normalize(u.city) == c).toList();
    }

    // Filtro de texto (com ranking)
    if (query != null && query.trim().isNotEmpty) {
      filtered = _filterAndRankByQuery(filtered, query.trim());
    }

    return filtered;
  }

  /// Filtra e ordena por relevância de busca
  List<UserSearchResult> _filterAndRankByQuery(
    List<UserSearchResult> users,
    String query,
  ) {
    final q = query.trim();
    if (q.isEmpty) return users;

    final scored = <MapEntry<UserSearchResult, int>>[];
    
    for (final u in users) {
      final nameScore = _score(u.name, q) * 3;
      final bioScore = _score(u.bio, q);
      final total = nameScore + bioScore;
      
      if (total > 0) {
        scored.add(MapEntry(u, total));
      }
    }

    // Ordena por score (maior primeiro)
    scored.sort((a, b) {
      if (b.value != a.value) return b.value.compareTo(a.value);
      return a.key.name.compareTo(b.key.name);
    });

    return scored.map((e) => e.key).toList();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUSCA COM PROXIMIDADE (SEM PAGINAÇÃO - ORDENADO POR DISTÂNCIA)
  // ══════════════════════════════════════════════════════════════════════════

  /// Busca usuários por proximidade
  /// Não usa paginação pois precisa calcular distância de todos
  Future<List<UserSearchResult>> fetchUsersByProximity({
    required String myUid,
    required Set<String> followingIds,
    required double latitude,
    required double longitude,
    required double radiusKm,
    String? query,
  }) async {
    final cacheKey = 'users_prox_${myUid}_${latitude.toStringAsFixed(3)}_${longitude.toStringAsFixed(3)}_${radiusKm}_$query';
    final cached = _cache.get<List<UserSearchResult>>(cacheKey);
    if (cached != null) return cached;

    final allUsers = await _fetchAllUsersFromFirebase(myUid, followingIds);

    // Filtra por raio
    var nearby = allUsers.where((u) {
      if (u.latitude == null || u.longitude == null) return false;
      final distance = _calculateDistance(
        latitude,
        longitude,
        u.latitude!,
        u.longitude!,
      );
      return distance <= radiusKm;
    }).toList();

    // Ordena por distância
    nearby.sort((a, b) {
      final distA = _calculateDistance(latitude, longitude, a.latitude!, a.longitude!);
      final distB = _calculateDistance(latitude, longitude, b.latitude!, b.longitude!);
      return distA.compareTo(distB);
    });

    // Aplica filtro de texto se houver
    if (query != null && query.trim().isNotEmpty) {
      nearby = _filterAndRankByQuery(nearby, query.trim());
    }

    // Cache por 2 minutos (proximidade muda menos)
    _cache.set(cacheKey, nearby, ttl: const Duration(minutes: 2));

    return nearby;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  INVALIDAÇÃO DE CACHE
  // ══════════════════════════════════════════════════════════════════════════

  /// Invalida todo o cache de usuários
  void invalidateUsersCache() {
    _cache.removeByPrefix('users_');
  }

  /// Invalida cache de um usuário específico
  void invalidateUserCache(String myUid) {
    _cache.removeByPrefix('users_all_$myUid');
    _cache.removeByPrefix('users_page_$myUid');
    _cache.removeByPrefix('users_prox_$myUid');
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  UTILITÁRIOS
  // ══════════════════════════════════════════════════════════════════════════

  String _buildUsersCacheKey({
    required String myUid,
    required int page,
    String? query,
    String? estadoSigla,
    String? cidadeNome,
  }) {
    final parts = [
      'users_page',
      myUid,
      page.toString(),
      query ?? 'null',
      estadoSigla ?? 'null',
      cidadeNome ?? 'null',
    ];
    return parts.join('_');
  }

  static String _normalize(String s) {
    const accents = 'àáâãäåæçèéêëìíîïðñòóôõöøùúûüýþÿ';
    const normal = 'aaaaaaeceeeeiiiidnoooooouuuuyby';
    var r = s.toLowerCase();
    for (int i = 0; i < accents.length; i++) {
      r = r.replaceAll(accents[i], i < normal.length ? normal[i] : '');
    }
    return r;
  }

  static int _score(String candidate, String query) {
    if (candidate.isEmpty || query.isEmpty) return 0;
    final c = _normalize(candidate);
    final q = _normalize(query);

    if (c == q) return 100;
    if (c.startsWith(q)) return 80;
    if (c.contains(q)) return 60;

    final queryTokens = q.split(RegExp(r'\s+'))
        .where((t) => t.length >= 2)
        .toList();
    if (queryTokens.isNotEmpty) {
      final allMatch = queryTokens.every((t) => c.contains(t));
      if (allMatch) return 50;
      final anyMatch = queryTokens.any((t) => c.contains(t));
      if (anyMatch) return 30;
    }

    final candidateWords = c.split(RegExp(r'\s+'));
    if (candidateWords.any((w) => w.startsWith(q))) return 40;

    return 0;
  }

  /// Calcula distância entre dois pontos (fórmula de Haversine)
  static double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371.0; // Raio da Terra em km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * asin(sqrt(a));
    return R * c;
  }

  static double _toRadians(double degrees) => degrees * 3.141592653589793 / 180.0;
}

// ══════════════════════════════════════════════════════════════════════════
//  RESULTADO PAGINADO
// ══════════════════════════════════════════════════════════════════════════

class PaginatedUsersResult {
  final List<UserSearchResult> users;
  final int page;
  final int pageSize;
  final int totalCount;
  final bool hasMore;

  const PaginatedUsersResult({
    required this.users,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.hasMore,
  });

  int get totalPages => (totalCount / pageSize).ceil();
  bool get isEmpty => users.isEmpty;
  bool get isNotEmpty => users.isNotEmpty;
}