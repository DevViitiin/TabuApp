// lib/services/services_administrative/party_service_paginated.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:firebase_database/firebase_database.dart';
import 'package:tabuapp/models/party_model.dart';
import 'package:tabuapp/services/services_app/cache_service.dart';

class PartyServicePaginated {
  PartyServicePaginated._();
  static final PartyServicePaginated instance = PartyServicePaginated._();

  final _db = FirebaseDatabase.instance;
  final _cache = CacheService.instance;

  /// Tamanho da página
  static const int pageSize = 10;

  /// TTL do cache: 3 minutos (festas mudam mais frequentemente)
  static const cacheTTL = Duration(minutes: 3);

  // ══════════════════════════════════════════════════════════════════════════
  //  BUSCA PAGINADA DE FESTAS
  // ══════════════════════════════════════════════════════════════════════════

  /// Busca festas com paginação
  ///
  /// [page]: Número da página (0-based)
  /// [query]: Texto de busca (opcional)
  /// [estadoSigla]: Filtro de estado (opcional)
  /// [cidadeNome]: Filtro de cidade (opcional)
  /// [bairro]: Filtro de bairro (opcional)
  Future<PaginatedPartiesResult> fetchParties({
    int page = 0,
    String? query,
    String? estadoSigla,
    String? cidadeNome,
    String? bairro,
  }) async {
    // Gera chave de cache única
    final cacheKey = _buildPartiesCacheKey(
      page: page,
      query: query,
      estadoSigla: estadoSigla,
      cidadeNome: cidadeNome,
      bairro: bairro,
    );

    // Tenta recuperar do cache
    final cached = _cache.get<PaginatedPartiesResult>(cacheKey);
    if (cached != null) {
      return cached;
    }

    // Busca do Firebase
    final allParties = await _fetchAllPartiesFromFirebase();

    // Aplica filtros
    var filtered = _applyPartyFilters(
      parties: allParties,
      query: query,
      estadoSigla: estadoSigla,
      cidadeNome: cidadeNome,
      bairro: bairro,
    );

    // Calcula paginação
    final totalCount = filtered.length;
    final totalPages = (totalCount / pageSize).ceil();
    final hasMore = page < totalPages - 1;

    final startIndex = page * pageSize;
    final endIndex = (startIndex + pageSize).clamp(0, totalCount);

    final pageParties = startIndex < totalCount
        ? filtered.sublist(startIndex, endIndex)
        : <PartyModel>[];

    final result = PaginatedPartiesResult(
      parties: pageParties,
      page: page,
      pageSize: pageSize,
      totalCount: totalCount,
      hasMore: hasMore,
    );

    // Armazena no cache
    _cache.set(cacheKey, result, ttl: cacheTTL);

    return result;
  }

  /// Busca todas as festas do Firebase (com cache)
  Future<List<PartyModel>> _fetchAllPartiesFromFirebase() async {
    final cacheKey = 'parties_all';
    final cached = _cache.get<List<PartyModel>>(cacheKey);
    if (cached != null) return cached;

    final snap = await _db.ref('Festas').get();
    if (!snap.exists || snap.value == null) return [];

    final raw = Map<dynamic, dynamic>.from(snap.value as Map);
    final list = <PartyModel>[];

    for (final entry in raw.entries) {
      if (entry.value is! Map) continue;

      try {
        final data = Map<String, dynamic>.from(entry.value as Map);
        data['id'] = entry.key as String;

        final party = PartyModel.fromMap(entry.key as String, data);
        list.add(party);
      } catch (e) {
        // Ignora festas com dados inválidos
        continue;
      }
    }

    // Remove festas que já terminaram
    final now = DateTime.now();
    list.removeWhere((p) => p.dataFim.isBefore(now));

    // Ordena por data de início (mais próximas primeiro)
    list.sort((a, b) => a.dataInicio.compareTo(b.dataInicio));

    // Cache por 2 minutos
    _cache.set(cacheKey, list, ttl: const Duration(minutes: 2));

    return list;
  }

  /// Aplica filtros às festas
  List<PartyModel> _applyPartyFilters({
    required List<PartyModel> parties,
    String? query,
    String? estadoSigla,
    String? cidadeNome,
    String? bairro,
  }) {
    var filtered = parties;

    // Filtro de estado
    if (estadoSigla != null && estadoSigla.isNotEmpty) {
      final s = estadoSigla.toLowerCase();
      filtered =
          filtered.where((p) => (p.state ?? '').toLowerCase() == s).toList();
    }

    // Filtro de cidade
    if (cidadeNome != null && cidadeNome.isNotEmpty) {
      final c = cidadeNome.toLowerCase();
      filtered =
          filtered.where((p) => (p.city ?? '').toLowerCase() == c).toList();
    }

    // Filtro de bairro
    if (bairro != null && bairro.isNotEmpty) {
      final b = bairro.toLowerCase();
      filtered = filtered
          .where((p) => (p.bairro ?? '').toLowerCase().contains(b))
          .toList();
    }

    // Filtro de texto (busca em múltiplos campos)
    if (query != null && query.trim().isNotEmpty) {
      final q = query.toLowerCase();
      filtered = filtered
          .where((p) =>
              p.nome.toLowerCase().contains(q) ||
              (p.local ?? '').toLowerCase().contains(q) ||
              p.descricao.toLowerCase().contains(q))
          .toList();
    }

    return filtered;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUSCA COM PROXIMIDADE (SEM PAGINAÇÃO - ORDENADO POR DISTÂNCIA)
  // ══════════════════════════════════════════════════════════════════════════

  /// Busca festas por proximidade
  Future<List<PartyModel>> fetchPartiesByProximity({
    required double latitude,
    required double longitude,
    required double radiusKm,
    String? query,
  }) async {
    final cacheKey =
        'parties_prox_${latitude.toStringAsFixed(3)}_${longitude.toStringAsFixed(3)}_${radiusKm}_$query';
    final cached = _cache.get<List<PartyModel>>(cacheKey);
    if (cached != null) return cached;

    final allParties = await _fetchAllPartiesFromFirebase();

    // Filtra por raio (apenas festas com coordenadas)
    var nearby = allParties.where((p) {
      if (!p.hasCoords) return false;
      final distance = _calculateDistance(
        latitude,
        longitude,
        p.latitude!,
        p.longitude!,
      );
      return distance <= radiusKm;
    }).toList();

    // Ordena por distância
    nearby.sort((a, b) {
      final distA =
          _calculateDistance(latitude, longitude, a.latitude!, a.longitude!);
      final distB =
          _calculateDistance(latitude, longitude, b.latitude!, b.longitude!);
      return distA.compareTo(distB);
    });

    // Aplica filtro de texto se houver
    if (query != null && query.trim().isNotEmpty) {
      final q = query.toLowerCase();
      nearby = nearby
          .where((p) =>
              p.nome.toLowerCase().contains(q) ||
              (p.local ?? '').toLowerCase().contains(q) ||
              p.descricao.toLowerCase().contains(q))
          .toList();
    }

    // Cache por 2 minutos
    _cache.set(cacheKey, nearby, ttl: const Duration(minutes: 2));

    return nearby;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  INVALIDAÇÃO DE CACHE
  // ══════════════════════════════════════════════════════════════════════════

  /// Invalida todo o cache de festas
  void invalidatePartiesCache() {
    _cache.removeByPrefix('parties_');
  }

  /// Invalida cache quando uma festa é modificada
  void invalidatePartyCache(String partyId) {
    _cache.removeByPrefix('parties_');
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  UTILITÁRIOS
  // ══════════════════════════════════════════════════════════════════════════

  String _buildPartiesCacheKey({
    required int page,
    String? query,
    String? estadoSigla,
    String? cidadeNome,
    String? bairro,
  }) {
    final parts = [
      'parties_page',
      page.toString(),
      query ?? 'null',
      estadoSigla ?? 'null',
      cidadeNome ?? 'null',
      bairro ?? 'null',
    ];
    return parts.join('_');
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

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.asin(math.sqrt(a));
    return R * c;
  }

  static double _toRadians(double degrees) =>
      degrees * 3.141592653589793 / 180.0;
}

// ══════════════════════════════════════════════════════════════════════════════
//  RESULTADO PAGINADO
// ══════════════════════════════════════════════════════════════════════════════

class PaginatedPartiesResult {
  final List<PartyModel> parties;
  final int page;
  final int pageSize;
  final int totalCount;
  final bool hasMore;

  const PaginatedPartiesResult({
    required this.parties,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.hasMore,
  });

  int get totalPages => (totalCount / pageSize).ceil();
  bool get isEmpty => parties.isEmpty;
  bool get isNotEmpty => parties.isNotEmpty;
}