// lib/services/services_app/video_preload_service.dart
//
// ══════════════════════════════════════════════════════════════════════════════
//  VIDEO PRELOAD SERVICE
//
//  Mantém um cache de VideoPlayerControllers já inicializados,
//  prontos para uso imediato no feed e no fullscreen player.
//
//  Uso:
//    1. Ao montar o _PostCard de vídeo, chame:
//         VideoPreloadService.instance.preload(postId, videoUrl)
//
//    2. Ao abrir o fullscreen, passe o controller já pronto:
//         VideoPreloadService.instance.getController(postId)
//
//    3. Ao remover o post da tela, libere controllers antigos:
//         VideoPreloadService.instance.evict(postId)
//
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

class VideoPreloadService {
  VideoPreloadService._();
  static final VideoPreloadService instance = VideoPreloadService._();

  // Máximo de controllers mantidos em memória simultaneamente.
  // Ajuste conforme a RAM disponível (~3–5 é um bom equilíbrio).
  static const int _maxCached = 4;

  // Controller totalmente inicializado, pronto para play.
  final Map<String, VideoPlayerController> _ready = {};

  // Preloads em andamento para evitar dupla inicialização.
  final Set<String> _inProgress = {};

  // Ordem de inserção para política LRU simples.
  final List<String> _order = [];

  // ── API pública ────────────────────────────────────────────────────────────

  /// Retorna o controller pronto (ou null se ainda carregando / não iniciado).
  VideoPlayerController? getController(String postId) => _ready[postId];

  /// Verifica se o controller está pronto para uso imediato.
  bool isReady(String postId) => _ready.containsKey(postId);

  /// Inicia o carregamento em background.
  /// Seguro chamar múltiplas vezes — ignora se já está em progresso ou pronto.
  Future<void> preload(String postId, String videoUrl) async {
    if (_ready.containsKey(postId) || _inProgress.contains(postId)) return;
    _inProgress.add(postId);

    try {
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await ctrl.initialize();

      // Deixa pausado no frame 0 — pronto para play instantâneo.
      await ctrl.seekTo(Duration.zero);
      await ctrl.pause();

      _ready[postId] = ctrl;
      _order.add(postId);
      _evictOldest();

      debugPrint('[VideoPreload] ✅ Pronto: $postId');
    } catch (e) {
      debugPrint('[VideoPreload] ❌ Erro ao pré-carregar $postId: $e');
    } finally {
      _inProgress.remove(postId);
    }
  }

  /// Remove um controller específico da memória.
  Future<void> evict(String postId) async {
    final ctrl = _ready.remove(postId);
    _order.remove(postId);
    await ctrl?.dispose();
  }

  /// Libera tudo — chamar ao fazer logout.
  Future<void> disposeAll() async {
    for (final ctrl in _ready.values) {
      await ctrl.dispose();
    }
    _ready.clear();
    _order.clear();
    _inProgress.clear();
  }

  // ── Interno ────────────────────────────────────────────────────────────────

  void _evictOldest() {
    while (_order.length > _maxCached) {
      final oldest = _order.removeAt(0);
      final ctrl = _ready.remove(oldest);
      ctrl?.dispose();
      debugPrint('[VideoPreload] 🗑️  Evicted: $oldest');
    }
  }
}