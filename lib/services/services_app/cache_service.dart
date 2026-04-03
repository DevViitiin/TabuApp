// lib/services/services_app/cache_service.dart

/// Sistema de cache genérico com Time-To-Live (TTL)
class CacheService {
  CacheService._();
  static final CacheService instance = CacheService._();

  final Map<String, CacheEntry<dynamic>> _cache = {};

  /// Duração padrão do cache: 5 minutos
  static const defaultTTL = Duration(minutes: 5);

  /// Armazena um valor no cache com TTL opcional
  void set<T>(
    String key,
    T value, {
    Duration ttl = defaultTTL,
  }) {
    _cache[key] = CacheEntry<T>(
      value: value,
      expiresAt: DateTime.now().add(ttl),
    );
  }

  /// Recupera um valor do cache (null se expirado ou inexistente)
  T? get<T>(String key) {
    final entry = _cache[key];
    if (entry == null) return null;

    // Verifica se expirou
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _cache.remove(key);
      return null;
    }

    return entry.value as T?;
  }

  /// Verifica se uma chave existe e está válida
  bool has(String key) {
    final entry = _cache[key];
    if (entry == null) return false;
    
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _cache.remove(key);
      return false;
    }
    
    return true;
  }

  /// Remove uma entrada específica
  void remove(String key) => _cache.remove(key);

  /// Remove todas as entradas com um prefixo
  void removeByPrefix(String prefix) {
    _cache.removeWhere((key, _) => key.startsWith(prefix));
  }

  /// Limpa todo o cache
  void clear() => _cache.clear();

  /// Remove entradas expiradas
  void cleanExpired() {
    final now = DateTime.now();
    _cache.removeWhere((_, entry) => now.isAfter(entry.expiresAt));
  }

  /// Retorna informações sobre o cache
  CacheStats getStats() {
    final now = DateTime.now();
    int valid = 0;
    int expired = 0;

    for (final entry in _cache.values) {
      if (now.isAfter(entry.expiresAt)) {
        expired++;
      } else {
        valid++;
      }
    }

    return CacheStats(
      totalEntries: _cache.length,
      validEntries: valid,
      expiredEntries: expired,
    );
  }
}

/// Entrada individual do cache
class CacheEntry<T> {
  final T value;
  final DateTime expiresAt;

  const CacheEntry({
    required this.value,
    required this.expiresAt,
  });
}

/// Estatísticas do cache
class CacheStats {
  final int totalEntries;
  final int validEntries;
  final int expiredEntries;

  const CacheStats({
    required this.totalEntries,
    required this.validEntries,
    required this.expiredEntries,
  });

  @override
  String toString() =>
      'CacheStats(total: $totalEntries, valid: $validEntries, expired: $expiredEntries)';
}