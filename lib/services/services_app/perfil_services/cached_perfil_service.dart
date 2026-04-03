// lib/services/services_app/cache_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ══════════════════════════════════════════════════════════════════════════════
///  CACHE SERVICE
///  
///  Cache em memória + persistência local com expiração.
///  Usado por PostService e GalleryService para evitar downloads repetidos.
/// ══════════════════════════════════════════════════════════════════════════════

class CacheService {
  CacheService._();
  static final CacheService instance = CacheService._();

  // Cache em memória (acesso rápido)
  final Map<String, _CacheEntry> _memoryCache = {};

  // Duração padrão do cache (30 minutos)
  static const Duration _defaultTTL = Duration(minutes: 30);

  /// Salva no cache (memória + disco)
  Future<void> set(
    String key,
    dynamic data, {
    Duration ttl = _defaultTTL,
  }) async {
    final expiry = DateTime.now().add(ttl);
    _memoryCache[key] = _CacheEntry(data: data, expiry: expiry);

    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode({
        'data': data,
        'expiry': expiry.millisecondsSinceEpoch,
      });
      await prefs.setString('cache_$key', json);
    } catch (e) {
      debugPrint('[Cache] ⚠️  Erro ao persistir $key: $e');
    }
  }

  /// Busca do cache (memória primeiro, depois disco)
  Future<T?> get<T>(String key) async {
    // 1. Tenta memória
    final memEntry = _memoryCache[key];
    if (memEntry != null) {
      if (memEntry.expiry.isAfter(DateTime.now())) {
        debugPrint('[Cache] ✅ Hit (memória): $key');
        return memEntry.data as T?;
      } else {
        _memoryCache.remove(key);
      }
    }

    // 2. Tenta disco
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('cache_$key');
      if (json == null) return null;

      final decoded = jsonDecode(json);
      final expiry = DateTime.fromMillisecondsSinceEpoch(decoded['expiry']);

      if (expiry.isAfter(DateTime.now())) {
        final data = decoded['data'] as T;
        _memoryCache[key] = _CacheEntry(data: data, expiry: expiry);
        debugPrint('[Cache] ✅ Hit (disco): $key');
        return data;
      } else {
        await prefs.remove('cache_$key');
      }
    } catch (e) {
      debugPrint('[Cache] ❌ Erro ao ler $key: $e');
    }

    debugPrint('[Cache] ❌ Miss: $key');
    return null;
  }

  /// Remove entrada específica
  Future<void> remove(String key) async {
    _memoryCache.remove(key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cache_$key');
  }

  /// Limpa todo o cache
  Future<void> clear() async {
    _memoryCache.clear();
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('cache_'));
    for (final key in keys) {
      await prefs.remove(key);
    }
    debugPrint('[Cache] 🗑️  Cache limpo');
  }

  /// Invalida caches com prefixo (ex: 'posts_', 'gallery_')
  Future<void> invalidatePrefix(String prefix) async {
    _memoryCache.removeWhere((k, _) => k.startsWith(prefix));
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('cache_$prefix'));
    for (final key in keys) {
      await prefs.remove(key);
    }
    debugPrint('[Cache] 🗑️  Invalidado: $prefix*');
  }
}

class _CacheEntry {
  final dynamic data;
  final DateTime expiry;
  _CacheEntry({required this.data, required this.expiry});
}