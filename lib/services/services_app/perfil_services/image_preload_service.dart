// lib/services/services_app/image_preload_service.dart

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// ══════════════════════════════════════════════════════════════════════════════
///  IMAGE PRELOAD SERVICE
///  
///  Pré-carrega imagens em background e mantém cache LRU.
///  Usa flutter_cache_manager para cache em disco.
/// ══════════════════════════════════════════════════════════════════════════════

class ImagePreloadService {
  ImagePreloadService._();
  static final ImagePreloadService instance = ImagePreloadService._();

  static const int _maxCached = 20; // Máximo de imagens em memória
  final Set<String> _preloaded = {};
  final List<String> _order = [];

  final _cacheManager = DefaultCacheManager();

  /// Pré-carrega uma imagem
  Future<void> preload(BuildContext context, String imageUrl) async {
    if (_preloaded.contains(imageUrl)) return;
    _preloaded.add(imageUrl);

    try {
      // 1. Cache em disco
      await _cacheManager.downloadFile(imageUrl);

      // 2. Cache em memória (ImageCache do Flutter)
      final image = NetworkImage(imageUrl);
      await precacheImage(image, context);

      _order.add(imageUrl);
      _evictOldest();

      debugPrint('[ImagePreload] ✅ Pronto: ${imageUrl.substring(0, 50)}...');
    } catch (e) {
      debugPrint('[ImagePreload] ❌ Erro: $e');
      _preloaded.remove(imageUrl);
    }
  }

  /// Pré-carrega lista de imagens
  Future<void> preloadBatch(BuildContext context, List<String> urls) async {
    for (final url in urls.take(5)) {
      // Limita a 5 simultâneos
      unawaited(preload(context, url));
    }
  }

  /// Remove imagem do cache
  Future<void> evict(String imageUrl) async {
    _preloaded.remove(imageUrl);
    _order.remove(imageUrl);
    await _cacheManager.removeFile(imageUrl);
  }

  /// Limpa todo o cache
  Future<void> clearAll() async {
    _preloaded.clear();
    _order.clear();
    await _cacheManager.emptyCache();
  }

  void _evictOldest() {
    while (_order.length > _maxCached) {
      final oldest = _order.removeAt(0);
      _preloaded.remove(oldest);
      _cacheManager.removeFile(oldest);
    }
  }

  bool isPreloaded(String url) => _preloaded.contains(url);
}

// Helper para não esperar futures
void unawaited(Future<void> future) {}