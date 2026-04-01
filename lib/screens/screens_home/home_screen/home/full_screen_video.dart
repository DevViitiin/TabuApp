// lib/screens/screens_home/home_screen/posts/fullscreen_video_screen.dart
//
// ══════════════════════════════════════════════════════════════════════════════
//  FULLSCREEN VIDEO SCREEN
//
//  Abre o vídeo em tela cheia estilo Instagram/TikTok.
//  Se o controller já foi pré-carregado pelo VideoPreloadService, o vídeo
//  começa a tocar instantaneamente. Caso contrário, inicializa no momento.
//
//  Uso no _PostCard:
//    Navigator.push(context, FullscreenVideoScreen.route(
//      postId:    post.id,
//      videoUrl:  post.mediaUrl!,
//      thumbUrl:  post.thumbUrl,
//      userName:  post.userName,
//      titulo:    post.titulo,
//      duration:  post.videoDuration,
//    ));
//
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/services/services_app/video_preload_service.dart';

class FullscreenVideoScreen extends StatefulWidget {
  final String postId;
  final String videoUrl;
  final String? thumbUrl;
  final String userName;
  final String titulo;
  final int? duration;

  const FullscreenVideoScreen({
    super.key,
    required this.postId,
    required this.videoUrl,
    this.thumbUrl,
    required this.userName,
    required this.titulo,
    this.duration,
  });

  /// Rota com transição fade suave (igual ao estilo do app).
  static Route<void> route({
    required String postId,
    required String videoUrl,
    String? thumbUrl,
    required String userName,
    required String titulo,
    int? duration,
  }) {
    return PageRouteBuilder(
      pageBuilder: (_, animation, __) => FullscreenVideoScreen(
        postId:   postId,
        videoUrl: videoUrl,
        thumbUrl: thumbUrl,
        userName: userName,
        titulo:   titulo,
        duration: duration,
      ),
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 220),
      opaque: true,
      barrierColor: Colors.black,
    );
  }

  @override
  State<FullscreenVideoScreen> createState() => _FullscreenVideoScreenState();
}

class _FullscreenVideoScreenState extends State<FullscreenVideoScreen>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _ctrl;
  bool _initialized  = false;
  bool _loading      = false;
  bool _hasError     = false;
  bool _playing      = false;
  bool _showControls = true;
  bool _muted        = false;

  late AnimationController _controlsAnim;
  late Animation<double>   _controlsFade;

  @override
  void initState() {
    super.initState();

    // Força orientação landscape para vídeos (opcional — remova se quiser portrait only)
    // SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _controlsAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: 1.0,
    );
    _controlsFade = CurvedAnimation(parent: _controlsAnim, curve: Curves.easeOut);

    _initController();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _controlsAnim.dispose();

    // Só libera o controller se NÃO está no cache (cache gerencia a vida dele)
    if (!VideoPreloadService.instance.isReady(widget.postId)) {
      _ctrl?.dispose();
    } else {
      // Pausa e rebobina para o cache reutilizar
      _ctrl?.pause();
      _ctrl?.seekTo(Duration.zero);
    }

    super.dispose();
  }

  Future<void> _initController() async {
    // ── Caminho 1: Controller pré-carregado (instantâneo) ─────────────────
    final cached = VideoPreloadService.instance.getController(widget.postId);
    if (cached != null && cached.value.isInitialized) {
      setState(() {
        _ctrl        = cached;
        _initialized = true;
        _playing     = true;
      });
      cached.addListener(_onVideoUpdate);
      await cached.play();
      _scheduleHideControls();
      return;
    }

    // ── Caminho 2: Inicialização fresh (fallback) ──────────────────────────
    setState(() => _loading = true);
    try {
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await ctrl.initialize();
      ctrl.addListener(_onVideoUpdate);

      if (!mounted) { ctrl.dispose(); return; }

      setState(() {
        _ctrl        = ctrl;
        _initialized = true;
        _loading     = false;
        _hasError    = false;
        _playing     = true;
      });

      await ctrl.play();
      _scheduleHideControls();
    } catch (e) {
      debugPrint('[FullscreenVideo] Erro: $e');
      if (mounted) setState(() { _loading = false; _hasError = true; });
    }
  }

  void _onVideoUpdate() {
    if (!mounted || _ctrl == null) return;

    // Loop automático
    if (_ctrl!.value.position >= _ctrl!.value.duration &&
        _ctrl!.value.duration.inSeconds > 0) {
      _ctrl!.seekTo(Duration.zero);
      _ctrl!.play();
      return;
    }

    if (mounted) setState(() => _playing = _ctrl!.value.isPlaying);
  }

  // ── Controles ─────────────────────────────────────────────────────────────

  void _togglePlay() {
    if (_ctrl == null || !_initialized) return;
    HapticFeedback.selectionClick();
    if (_ctrl!.value.isPlaying) {
      _ctrl!.pause();
      setState(() { _playing = false; _showControls = true; });
      _controlsAnim.forward();
    } else {
      _ctrl!.play();
      setState(() { _playing = true; });
      _scheduleHideControls();
    }
  }

  void _toggleMute() {
    if (_ctrl == null) return;
    HapticFeedback.selectionClick();
    setState(() => _muted = !_muted);
    _ctrl!.setVolume(_muted ? 0.0 : 1.0);
  }

  void _onTapScreen() {
    if (_showControls) {
      _hideControls();
    } else {
      _showControlsTemporarily();
    }
  }

  void _showControlsTemporarily() {
    setState(() => _showControls = true);
    _controlsAnim.forward();
    _scheduleHideControls();
  }

  void _hideControls() {
    if (!_playing) return;
    _controlsAnim.reverse().then((_) {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _scheduleHideControls() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _playing) _hideControls();
    });
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _onTapScreen,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── 1. Vídeo ou capa ──────────────────────────────────────────
            _buildVideoLayer(),

            // ── 2. Overlay de gradientes ───────────────────────────────────
            _buildGradients(),

            // ── 3. Header (fechar + mudo) ──────────────────────────────────
            _buildHeader(),

            // ── 4. Info + controles inferiores ─────────────────────────────
            _buildBottomInfo(),

            // ── 5. Botão play central ──────────────────────────────────────
            _buildCenterPlayButton(),

            // ── 6. Loading / erro ──────────────────────────────────────────
            if (_loading) _buildLoading(),
            if (_hasError) _buildError(),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoLayer() {
    if (_initialized && _ctrl != null) {
      return Center(
        child: AspectRatio(
          aspectRatio: _ctrl!.value.aspectRatio,
          child: VideoPlayer(_ctrl!),
        ),
      );
    }

    // Capa enquanto carrega
    if (widget.thumbUrl != null) {
      return Image.network(
        widget.thumbUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _darkBg(),
      );
    }

    return _darkBg();
  }

  Widget _darkBg() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF0D0010), Color(0xFF1A0020)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  );

  Widget _buildGradients() {
    return FadeTransition(
      opacity: _controlsFade,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Gradiente topo
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: 160,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.75), Colors.transparent],
                ),
              ),
            ),
          ),
          // Gradiente base
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.90), Colors.transparent],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: SafeArea(
        child: FadeTransition(
          opacity: _controlsFade,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              children: [
                // Botão fechar
                _IconBtn(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.pop(context),
                ),
                const Spacer(),
                // Botão mudo
                _IconBtn(
                  icon: _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  onTap: _toggleMute,
                  color: _muted
                      ? TabuColors.rosaPrincipal.withOpacity(0.8)
                      : Colors.white70,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomInfo() {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: SafeArea(
        child: FadeTransition(
          opacity: _controlsFade,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Nome do usuário
                Text(
                  '@${widget.userName.toLowerCase()}',
                  style: const TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                    color: TabuColors.rosaPrincipal,
                  ),
                ),
                const SizedBox(height: 4),
                // Título do post
                Text(
                  widget.titulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 16),
                // Tempo atual / total
                if (_initialized && _ctrl != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      Text(
                        _fmt(_ctrl!.value.position),
                        style: const TextStyle(
                          fontFamily: TabuTypography.bodyFont,
                          fontSize: 11,
                          color: Colors.white70,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _fmt(_ctrl!.value.duration),
                        style: const TextStyle(
                          fontFamily: TabuTypography.bodyFont,
                          fontSize: 11,
                          color: Colors.white38,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ]),
                  ),
                // SeekBar full
                if (_initialized && _ctrl != null)
                  _FullscreenSeekBar(controller: _ctrl!),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCenterPlayButton() {
    if (_loading || _hasError || !_showControls) return const SizedBox.shrink();

    return Center(
      child: FadeTransition(
        opacity: _controlsFade,
        child: GestureDetector(
          onTap: _togglePlay,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(0.55),
              border: Border.all(color: TabuColors.rosaPrincipal, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: TabuColors.glow.withOpacity(0.4),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 42,
            height: 42,
            child: CircularProgressIndicator(
              color: TabuColors.rosaPrincipal,
              backgroundColor: TabuColors.rosaPrincipal.withOpacity(0.15),
              strokeWidth: 2,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'CARREGANDO',
            style: TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 10,
              letterSpacing: 3,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFE85D5D), size: 42),
          const SizedBox(height: 12),
          const Text(
            'ERRO AO CARREGAR VÍDEO',
            style: TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 10,
              letterSpacing: 2.5,
              color: Color(0xFFE85D5D),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _initController,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(
                    color: const Color(0xFFE85D5D).withOpacity(0.5), width: 0.8),
                color: const Color(0xFFE85D5D).withOpacity(0.1),
              ),
              child: const Text(
                'TENTAR NOVAMENTE',
                style: TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 10,
                  letterSpacing: 2,
                  color: Color(0xFFE85D5D),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SEEKBAR FULLSCREEN — largura total, thumb arrastável
// ══════════════════════════════════════════════════════════════════════════════

class _FullscreenSeekBar extends StatefulWidget {
  final VideoPlayerController controller;
  const _FullscreenSeekBar({required this.controller});

  @override
  State<_FullscreenSeekBar> createState() => _FullscreenSeekBarState();
}

class _FullscreenSeekBarState extends State<_FullscreenSeekBar> {
  bool _dragging = false;
  double _dragValue = 0.0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_update);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_update);
    super.dispose();
  }

  void _update() { if (mounted) setState(() {}); }

  @override
  Widget build(BuildContext context) {
    final pos   = _dragging
        ? _dragValue
        : widget.controller.value.position.inMilliseconds.toDouble();
    final total = widget.controller.value.duration.inMilliseconds.toDouble();
    final pct   = total > 0 ? (pos / total).clamp(0.0, 1.0) : 0.0;

    return GestureDetector(
      onHorizontalDragStart: (d) {
        setState(() => _dragging = true);
        widget.controller.pause();
      },
      onHorizontalDragUpdate: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final localX = details.localPosition.dx.clamp(0.0, box.size.width);
        setState(() => _dragValue = (localX / box.size.width * total).clamp(0.0, total));
      },
      onHorizontalDragEnd: (_) async {
        await widget.controller.seekTo(Duration(milliseconds: _dragValue.toInt()));
        await widget.controller.play();
        setState(() => _dragging = false);
      },
      child: SizedBox(
        height: 28,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Track
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Progresso
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: pct,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: const LinearGradient(
                      colors: [TabuColors.rosaDeep, TabuColors.rosaPrincipal],
                    ),
                  ),
                ),
              ),
            ),
            // Thumb
            Align(
              alignment: Alignment(pct * 2 - 1, 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width:  _dragging ? 18 : 12,
                height: _dragging ? 18 : 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: TabuColors.rosaPrincipal,
                  boxShadow: [
                    BoxShadow(
                      color: TabuColors.glow.withOpacity(0.6),
                      blurRadius: _dragging ? 12 : 6,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  HELPER: Botão de ícone com fundo semi-transparente
// ══════════════════════════════════════════════════════════════════════════════

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _IconBtn({
    required this.icon,
    required this.onTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.6),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}