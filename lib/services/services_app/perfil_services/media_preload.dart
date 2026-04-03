// lib/services/services_app/media_preload_service.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:tabuapp/models/gallery_item_model.dart';
import 'package:tabuapp/models/post_model.dart';
import 'package:video_player/video_player.dart';
import 'package:tabuapp/services/services_app/perfil_services/cached_perfil_service.dart';

class MediaPreloadService {
  MediaPreloadService._();
  static final MediaPreloadService instance = MediaPreloadService._();

  // ✅ Cache Manager corrigido
  final _cacheManager = CacheManager(Config(
    'tabuMediaCache',
    stalePeriod: const Duration(days: 7),
    maxNrOfCacheObjects: 200,
  ));

  final _cache = CacheService.instance;

  // Vídeos
  final Map<String, VideoPlayerController> _videoControllers = {};
  final Set<String> _preloadedVideos = {};
  final List<String> _videoLRU = [];

  // Imagens
  final Set<String> _preloadedImages = {};
  final List<String> _imageLRU = [];

  static const int _maxVideos = 15;
  static const int _maxImages = 50;

  /// 🎥 PRELOAD VÍDEO TURBO
  Future<bool> preloadVideo(String videoId, String url,
      {String? context}) async {
    if (_preloadedVideos.contains(videoId)) return true;

    try {
      final cacheKey = context != null ? '${context}_v_$videoId' : videoId;
      final cached = await _cache.get<String>(cacheKey);
      if (cached != null) {
        _preloadedVideos.add(videoId);
        _videoLRU.add(videoId);
        _evictOldVideos();
        return true;
      }

      final fileInfo = await _cacheManager.getSingleFile(url);
      if (!await fileInfo.exists()) return false;

      final controller = VideoPlayerController.file(File(fileInfo.path));
      await controller.initialize();

      _bufferVideo(controller, videoId);

      _videoControllers[videoId] = controller;
      _preloadedVideos.add(videoId);
      _videoLRU.add(videoId);
      await _cache.set(cacheKey, 'READY', ttl: const Duration(hours: 24));

      _evictOldVideos();
      debugPrint('[MediaPreload] ⚡ Vídeo pronto: $videoId');
      return true;
    } catch (e) {
      debugPrint('[MediaPreload] ❌ Vídeo $videoId: $e');
      return false;
    }
  }

  /// 🖼️ PRELOAD IMAGEM TURBO
  Future<bool> preloadImage(BuildContext context, String url,
      {String? contextKey}) async {
    if (_preloadedImages.contains(url)) return true;

    try {
      final cacheKey =
          contextKey != null ? '${contextKey}_img_$url' : 'img_$url';
      final cached = await _cache.get<bool>(cacheKey);
      if (cached == true) {
        _preloadedImages.add(url);
        _imageLRU.add(url);
        _evictOldImages();
        return true;
      }

      // Precarga inteligente
      await precacheImage(NetworkImage(url), context);

      _preloadedImages.add(url);
      _imageLRU.add(url);
      await _cache.set(cacheKey, true, ttl: const Duration(hours: 24));

      _evictOldImages();
      debugPrint(
          '[MediaPreload] 🖼️ Imagem pronta: ${url.substring(0, 30)}...');
      return true;
    } catch (e) {
      debugPrint('[MediaPreload] ❌ Imagem: $e');
      return false;
    }
  }

  /// 🎬 BUFFER VÍDEO
  void _bufferVideo(VideoPlayerController controller, String videoId) {
    controller.setVolume(0);
    controller.play();
    Future.delayed(const Duration(milliseconds: 800), () {
      if (controller.value.isInitialized) {
        controller.pause();
        controller.seekTo(Duration.zero);
        controller.setVolume(1);
      }
    });
  }

  /// 📱 PRELOAD POSTS COMPLETO
  Future<void> preloadPostsMedia(BuildContext context, List<PostModel> posts,
      {String? contextKey}) async {
    final videos = <Map<String, String>>[];
    final images = <String>[];

    for (final post in posts) {
      if (post.tipo == 'video' && post.mediaUrl != null) {
        videos.add({'id': 'post_${post.id}', 'url': post.mediaUrl!});
      } else if (post.tipo == 'foto' && post.mediaUrl != null) {
        images.add(post.mediaUrl!);
      }
    }

    // Paralelo
    await Future.wait([
      MediaPreloadService.instance
          .preloadVideosBatch(videos, context: contextKey),
      MediaPreloadService.instance
          .preloadImagesBatch(context, images, contextKey: contextKey),
    ]);
  }

  /// 🖼️ PRELOAD GALERIA COMPLETO
  Future<void> preloadGalleryMedia(
      BuildContext context, List<GalleryItem> items,
      {required String userId}) async {
    final videos = <Map<String, String>>[];
    final images = <String>[];

    for (final item in items) {
      if (item.type == 'video' && item.mediaUrl != null) {
        videos
            .add({'id': 'gallery_${userId}_${item.id}', 'url': item.mediaUrl!});
      } else if (item.type == 'foto' && item.mediaUrl != null) {
        images.add(item.mediaUrl!);
      }
    }

    await Future.wait([
      MediaPreloadService.instance
          .preloadVideosBatch(videos, context: 'gallery_$userId'),
      MediaPreloadService.instance
          .preloadImagesBatch(context, images, contextKey: 'gallery_$userId'),
    ]);
  }

  /// 🔄 BATCH VÍDEOS
  Future<void> preloadVideosBatch(List<Map<String, String>> videos,
      {String? context}) async {
    final futures = videos
        .take(8)
        .map((v) => preloadVideo(v['id']!, v['url']!, context: context))
        .toList();
    await Future.wait(futures);
  }

  /// 🔄 BATCH IMAGENS
  Future<void> preloadImagesBatch(BuildContext context, List<String> images,
      {String? contextKey}) async {
    final futures = images
        .take(20)
        .map((url) => preloadImage(context, url, contextKey: contextKey))
        .toList();
    await Future.wait(futures);
  }

  /// 🎬 GET VIDEO CONTROLLER
  VideoPlayerController? getVideoController(String videoId) {
    final controller = _videoControllers[videoId];
    if (controller != null && controller.value.isInitialized) {
      controller.seekTo(Duration.zero);
      return controller;
    }
    return null;
  }

  /// 🧹 LIMPEZA
  void _evictOldVideos() {
    while (_videoLRU.length > _maxVideos) {
      final oldest = _videoLRU.removeAt(0);
      _preloadedVideos.remove(oldest);
      _videoControllers.remove(oldest)?.dispose();
    }
  }

  void _evictOldImages() {
    while (_imageLRU.length > _maxImages) {
      final oldest = _imageLRU.removeAt(0);
      _preloadedImages.remove(oldest);
    }
  }

  Future<void> clearContext(String context) async {
    // Vídeos
    final videoKeys =
        _videoControllers.keys.where((k) => k.startsWith(context)).toList();
    for (final key in videoKeys) {
      _videoControllers.remove(key)?.dispose();
      _preloadedVideos.remove(key);
      _videoLRU.remove(key);
    }

    // Cache
    await _cache.invalidatePrefix(context);
  }

  bool isVideoReady(String videoId) => _preloadedVideos.contains(videoId);
  bool isImageReady(String url) => _preloadedImages.contains(url);
}
