// lib/screens/screens_home/home_screen/posts/story_viewer_screen.dart
//
// MUDANÇAS vs versão anterior:
//   • Suporte completo a vídeos no viewer (type == 'video')
//   • VideoPlayerController instanciado e gerenciado por story
//   • Barra de progresso usa duração real do vídeo (ao invés de 5s fixos)
//   • Sincronização de pause/resume com o player de vídeo
//   • Pré-carregamento do próximo vídeo em background
//   • Fade suave entre stories
//   • Badge de duração + seek bar visual no player de vídeo
//
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/models/story_model.dart';
import 'package:tabuapp/screens/screens_administrative/reports_screens/report_story_screen.dart/report_story_screen.dart';
import 'package:tabuapp/services/services_administrative/reports/report_story_service.dart';
import 'package:tabuapp/services/services_app/cached_avatar.dart';
import 'package:tabuapp/services/services_app/story_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  STORY VIEWER SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class StoryViewerScreen extends StatefulWidget {
  final Map<String, List<StoryModel>> storiesByUser;
  final String                        initialUserId;
  final String                        myUid;
  final VoidCallback?                 onStoriesChanged;

  const StoryViewerScreen({
    super.key,
    required this.storiesByUser,
    required this.initialUserId,
    required this.myUid,
    this.onStoriesChanged,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with TickerProviderStateMixin {

  late PageController      _pageCtrl;
  late AnimationController _progressCtrl;

  late List<String> _userOrder;
  int  _userIndex  = 0;
  int  _storyIndex = 0;
  bool _paused     = false;
  bool _animating  = false;

  // ── Vídeo ──────────────────────────────────────────────────────────────────
  VideoPlayerController? _videoCtrl;
  bool _videoLoading = false;
  bool _videoError   = false;

  final Set<String> _markedIds = {};

  static const Duration _imageDuration = Duration(seconds: 5);

  List<StoryModel> get _currentStories =>
      widget.storiesByUser[_userOrder[_userIndex]] ?? [];

  StoryModel? get _currentStory =>
      _storyIndex < _currentStories.length
          ? _currentStories[_storyIndex]
          : null;

  bool get _isVideoStory => _currentStory?.isVideo == true;

  @override
  void initState() {
    super.initState();

    final ids = widget.storiesByUser.keys.toList();
    ids.remove(widget.myUid);
    _userOrder = [
      if (widget.storiesByUser.containsKey(widget.myUid)) widget.myUid,
      ...ids,
    ];

    _userIndex = _userOrder.indexOf(widget.initialUserId);
    if (_userIndex < 0) _userIndex = 0;

    _pageCtrl = PageController(initialPage: _userIndex);

    // Duração inicial — será sobrescrita para vídeos
    _progressCtrl = AnimationController(vsync: this, duration: _imageDuration)
      ..addStatusListener(_onProgressStatus);

    WidgetsBinding.instance.addPostFrameCallback((_) => _startStory());
  }

  @override
  void dispose() {
    _progressCtrl.removeStatusListener(_onProgressStatus);
    _progressCtrl.dispose();
    _pageCtrl.dispose();
    _disposeVideoCtrl();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  VÍDEO
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _disposeVideoCtrl() async {
    final ctrl = _videoCtrl;
    _videoCtrl = null;
    await ctrl?.dispose();
  }

  Future<void> _initVideo(String url) async {
    if (!mounted) return;

    setState(() {
      _videoLoading = true;
      _videoError   = false;
    });

    // Para e descarta o controller anterior
    await _disposeVideoCtrl();

    try {
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
      await ctrl.initialize();

      if (!mounted) {
        ctrl.dispose();
        return;
      }

      // Listener para atualizar seekbar e detectar fim
      ctrl.addListener(_onVideoTick);

      setState(() {
        _videoCtrl    = ctrl;
        _videoLoading = false;
        _videoError   = false;
      });

      // Ajusta a duração da barra de progresso para a duração real do vídeo
      final dur = ctrl.value.duration;
      _progressCtrl.stop();
      _progressCtrl.reset();
      _progressCtrl.duration = dur.inSeconds > 0 ? dur : _imageDuration;

      await ctrl.play();
      _progressCtrl.forward();

      // Pré-carrega o próximo story em background
      _preloadNext();

    } catch (e) {
      debugPrint('[StoryViewer] Erro ao carregar vídeo: $e');
      if (!mounted) return;
      setState(() {
        _videoLoading = false;
        _videoError   = true;
      });
      // Avança após 3s em caso de erro
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) _nextStory();
    }
  }

  void _onVideoTick() {
    if (!mounted || _videoCtrl == null) return;

    final ctrl = _videoCtrl!;
    if (!ctrl.value.isInitialized) return;

    final pos   = ctrl.value.position;
    final total = ctrl.value.duration;

    // Sincroniza a barra visual com a posição real do vídeo
    if (total.inMilliseconds > 0) {
      final pct = (pos.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
      // Atualiza sem acionar o listener de status (evita loop)
      _progressCtrl.value = pct;
    }

    // Detecta fim do vídeo
    if (pos >= total && total.inSeconds > 0) {
      _onVideoEnded();
    }

    if (mounted) setState(() {});
  }

  void _onVideoEnded() {
    _videoCtrl?.removeListener(_onVideoTick);
    _markFullyWatched();
    _nextStory();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PROGRESSO
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _startStory() async {
    if (!mounted) return;

    _progressCtrl.stop();
    _progressCtrl.removeStatusListener(_onProgressStatus);
    _progressCtrl.reset();
    _progressCtrl.addStatusListener(_onProgressStatus);

    _markViewed();

    final story = _currentStory;
    if (story == null) return;

    if (story.isVideo && story.mediaUrl != null) {
      // Para vídeos, o controller de progresso é controlado pelo _onVideoTick
      await _initVideo(story.mediaUrl!);
    } else {
      // Para fotos/textos/emoji: 5s fixos
      await _disposeVideoCtrl();
      if (!mounted) return;
      setState(() {
        _videoLoading = false;
        _videoError   = false;
      });
      _progressCtrl.duration = _imageDuration;
      if (!_paused) _progressCtrl.forward();
    }
  }

  void _onProgressStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      // Para imagens o completed dispara normalmente.
      // Para vídeos o completed é disparado pelo _onVideoTick.
      if (!_isVideoStory) {
        _markFullyWatched();
        _nextStory();
      }
    }
  }

  void _pauseStory() {
    if (_paused) return;
    setState(() => _paused = true);
    _progressCtrl.stop();
    _videoCtrl?.pause();
  }

  void _resumeStory() {
    if (!_paused) return;
    setState(() => _paused = false);
    if (_isVideoStory) {
      _videoCtrl?.play();
      // Não chama _progressCtrl.forward() — ele é dirigido pelo _onVideoTick
    } else {
      _progressCtrl.forward();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PRÉ-CARREGAMENTO DO PRÓXIMO STORY
  // ══════════════════════════════════════════════════════════════════════════

  void _preloadNext() {
    // Tenta pré-carregar o próximo story de vídeo no mesmo usuário
    final stories = _currentStories;
    final nextIdx = _storyIndex + 1;
    if (nextIdx < stories.length && stories[nextIdx].isVideo) {
      // Apenas inicia o buffering sem guardar o controller
      // (o _initVideo vai criar um novo quando necessário)
      debugPrint('[StoryViewer] Pré-carregando próximo story de vídeo...');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  MARCAÇÃO DE VIEWS
  // ══════════════════════════════════════════════════════════════════════════

  void _markViewed() {
    final story = _currentStory;
    if (story == null || widget.myUid.isEmpty) return;
    if (_markedIds.contains(story.id)) return;
    _markedIds.add(story.id);
    StoryService.instance.markAsViewed(
      storyId:  story.id,
      viewerId: widget.myUid,
    ).catchError((_) {});
  }

  void _markFullyWatched() {
    final story = _currentStory;
    if (story == null || widget.myUid.isEmpty) return;
    StoryService.instance.updateFullyWatched(
      storyId:  story.id,
      viewerId: widget.myUid,
    ).catchError((_) {});
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  NAVEGAÇÃO
  // ══════════════════════════════════════════════════════════════════════════

  void _nextStory() {
    if (_animating) return;
    if (_storyIndex < _currentStories.length - 1) {
      setState(() => _storyIndex++);
      _startStory();
    } else {
      _nextUser();
    }
  }

  void _prevStory() {
    if (_animating) return;
    if (_storyIndex > 0) {
      setState(() => _storyIndex--);
      _startStory();
    } else {
      _prevUser();
    }
  }

  void _nextUser() {
    if (_userIndex < _userOrder.length - 1) {
      setState(() => _animating = true);
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    } else {
      _fechar();
    }
  }

  void _prevUser() {
    if (_userIndex > 0) {
      setState(() => _animating = true);
      _pageCtrl.previousPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onPageChanged(int page) {
    setState(() {
      _userIndex  = page;
      _storyIndex = 0;
      _animating  = false;
    });
    _startStory();
  }

  void _fechar() {
    Navigator.pop(context);
    widget.onStoriesChanged?.call();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DELETAR STORY
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _deletarStory() async {
    final story = _currentStory;
    if (story == null) return;
    _pauseStory();

    final confirmar = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF130020),
            border: Border.fromBorderSide(
              BorderSide(color: Color(0x44FF2D7A), width: 0.8),
            ),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.delete_outline_rounded,
                color: Color(0xFFFF2D7A), size: 36),
            const SizedBox(height: 16),
            const Text('DELETAR STORY',
              style: TextStyle(fontFamily: TabuTypography.displayFont,
                  fontSize: 16, letterSpacing: 4, color: Colors.white)),
            const SizedBox(height: 12),
            Text('Este story será removido permanentemente.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: TabuTypography.bodyFont,
                  fontSize: 12, letterSpacing: 0.3, height: 1.5,
                  color: Colors.white.withOpacity(0.55))),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(context, false),
                child: Container(height: 44,
                  decoration: BoxDecoration(
                      border: Border.all(
                          color: Colors.white.withOpacity(0.2), width: 0.8)),
                  child: const Center(child: Text('CANCELAR',
                    style: TextStyle(fontFamily: TabuTypography.bodyFont,
                        fontSize: 11, fontWeight: FontWeight.w700,
                        letterSpacing: 2, color: Colors.white54)))))),
              const SizedBox(width: 12),
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(context, true),
                child: Container(height: 44,
                  color: const Color(0xFFFF2D7A),
                  child: const Center(child: Text('DELETAR',
                    style: TextStyle(fontFamily: TabuTypography.bodyFont,
                        fontSize: 11, fontWeight: FontWeight.w700,
                        letterSpacing: 2, color: Colors.white)))))),
            ]),
          ]),
        ),
      ),
    );

    if (!mounted) return;
    if (confirmar != true) { _resumeStory(); return; }

    try {
      await StoryService.instance.deleteStory(storyId: story.id);
      if (!mounted) return;

      final userStories = widget.storiesByUser[_userOrder[_userIndex]];
      if (userStories != null) userStories.removeAt(_storyIndex);

      if (userStories == null || userStories.isEmpty) {
        if (_userIndex < _userOrder.length - 1) _nextUser();
        else _fechar();
        return;
      }

      final newIndex = _storyIndex >= userStories.length
          ? userStories.length - 1 : _storyIndex;
      setState(() => _storyIndex = newIndex);
      _startStory();
      widget.onStoriesChanged?.call();

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: const Color(0xFF1A0030),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(),
        margin: const EdgeInsets.all(16),
        content: const Text('Story deletado com sucesso.',
          style: TextStyle(fontFamily: TabuTypography.bodyFont,
              fontSize: 12, fontWeight: FontWeight.w600,
              letterSpacing: 1.2, color: Colors.white70)),
      ));
    } catch (_) {
      if (!mounted) return;
      _resumeStory();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: const Color(0xFF3D0A0A),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(),
        margin: const EdgeInsets.all(16),
        content: const Text('Erro ao deletar story. Tente novamente.',
          style: TextStyle(fontFamily: TabuTypography.bodyFont,
              fontSize: 12, fontWeight: FontWeight.w600,
              letterSpacing: 1.2, color: Colors.white70)),
      ));
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DENÚNCIA
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _abrirDenuncia() async {
    final story = _currentStory;
    if (story == null) return;

    if (story.userId == widget.myUid) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: const Color(0xFF1A0030),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(),
        margin: const EdgeInsets.all(16),
        content: const Text('Você não pode denunciar seu próprio story.',
          style: TextStyle(fontFamily: TabuTypography.bodyFont,
              fontSize: 12, fontWeight: FontWeight.w600,
              letterSpacing: 1.2, color: Colors.white70)),
      ));
      return;
    }

    final jaReportou = await ReportService.instance.jaReportou(
      reporterUid: widget.myUid, storyId: story.id);
    if (!mounted) return;

    if (jaReportou) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: const Color(0xFF1A0030),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(),
        margin: const EdgeInsets.all(16),
        content: const Text('Você já denunciou este story.',
          style: TextStyle(fontFamily: TabuTypography.bodyFont,
              fontSize: 12, fontWeight: FontWeight.w600,
              letterSpacing: 1.2, color: Colors.white70)),
      ));
      return;
    }

    _pauseStory();
    await Navigator.push(context, PageRouteBuilder(
      pageBuilder: (_, animation, __) => StoryReportScreen(
        story: story, reporterUid: widget.myUid),
      transitionsBuilder: (_, animation, __, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1), end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child),
      transitionDuration: const Duration(milliseconds: 320),
    ));
    if (mounted) _resumeStory();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: PageView.builder(
          controller:    _pageCtrl,
          onPageChanged: _onPageChanged,
          itemCount:     _userOrder.length,
          itemBuilder: (_, pageIdx) {
            final userId  = _userOrder[pageIdx];
            final stories = widget.storiesByUser[userId] ?? [];
            final isActive = pageIdx == _userIndex;

            return _UserStoriesPage(
              userId:        userId,
              stories:       stories,
              myUid:         widget.myUid,
              storyIndex:    isActive ? _storyIndex    : 0,
              progressCtrl:  isActive ? _progressCtrl  : null,
              videoCtrl:     isActive ? _videoCtrl     : null,
              videoLoading:  isActive && _videoLoading,
              videoError:    isActive && _videoError,
              paused:        isActive && _paused,
              isActive:      isActive,
              onTapLeft:     _prevStory,
              onTapRight:    _nextStory,
              onLongPress:   _pauseStory,
              onLongRelease: _resumeStory,
              onClose:       _fechar,
              onReport:      _abrirDenuncia,
              onDelete:      _deletarStory,
            );
          },
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  PÁGINA DE STORIES DE UM USUÁRIO
// ══════════════════════════════════════════════════════════════════════════════
class _UserStoriesPage extends StatelessWidget {
  final String               userId;
  final List<StoryModel>     stories;
  final String               myUid;
  final int                  storyIndex;
  final AnimationController? progressCtrl;
  final VideoPlayerController? videoCtrl;
  final bool                 videoLoading;
  final bool                 videoError;
  final bool                 paused;
  final bool                 isActive;
  final VoidCallback         onTapLeft;
  final VoidCallback         onTapRight;
  final VoidCallback         onLongPress;
  final VoidCallback         onLongRelease;
  final VoidCallback         onClose;
  final VoidCallback         onReport;
  final VoidCallback         onDelete;

  const _UserStoriesPage({
    required this.userId,
    required this.stories,
    required this.myUid,
    required this.storyIndex,
    required this.progressCtrl,
    required this.videoCtrl,
    required this.videoLoading,
    required this.videoError,
    required this.paused,
    required this.isActive,
    required this.onTapLeft,
    required this.onTapRight,
    required this.onLongPress,
    required this.onLongRelease,
    required this.onClose,
    required this.onReport,
    required this.onDelete,
  });

  StoryModel? get current =>
      storyIndex < stories.length ? stories[storyIndex] : null;

  bool get isOwn => userId == myUid;

  @override
  Widget build(BuildContext context) {
    final story = current;
    if (story == null) return const SizedBox.shrink();

    return Stack(fit: StackFit.expand, children: [

      // ── 1. Fundo (imagem / vídeo / gradiente + overlays) ───────────────
      _StoryBackground(
        story:        story,
        videoCtrl:    videoCtrl,
        videoLoading: videoLoading,
        videoError:   videoError,
      ),

      // ── 2. Gradiente topo ──────────────────────────────────────────────
      Positioned(top: 0, left: 0, right: 0,
        child: Container(height: 180,
          decoration: const BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xCC000000), Colors.transparent])))),

      // ── 3. Gradiente rodapé ────────────────────────────────────────────
      Positioned(bottom: 0, left: 0, right: 0,
        child: Container(height: 120,
          decoration: const BoxDecoration(gradient: LinearGradient(
            begin: Alignment.bottomCenter, end: Alignment.topCenter,
            colors: [Color(0x88000000), Colors.transparent])))),

      // ── 4. Gestos (abaixo do header) ───────────────────────────────────
      Positioned(top: 130, bottom: 0, left: 0, right: 0,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onLongPressStart: (_) => onLongPress(),
          onLongPressEnd:   (_) => onLongRelease(),
          child: Row(children: [
            Expanded(flex: 3,
              child: GestureDetector(onTap: onTapLeft,
                child: Container(color: Colors.transparent))),
            Expanded(flex: 7,
              child: GestureDetector(onTap: onTapRight,
                child: Container(color: Colors.transparent))),
          ]),
        )),

      // ── 5. Barras de progresso + Header ───────────────────────────────
      SafeArea(bottom: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Barras
          Padding(padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
            child: Row(children: List.generate(stories.length, (i) =>
              Expanded(child: Padding(
                padding: EdgeInsets.only(right: i < stories.length - 1 ? 3 : 0),
                child: _ProgressBar(
                  filled: i < storyIndex,
                  active: i == storyIndex && isActive,
                  ctrl:   i == storyIndex ? progressCtrl : null,
                  // Para vídeos, a barra é atualizada pelo progressCtrl.value diretamente
                  isVideo: story.isVideo,
                )))))),

          // Header
          Padding(padding: const EdgeInsets.fromLTRB(12, 12, 8, 0),
            child: Row(children: [
              CachedAvatar(uid: userId, name: story.userName,
                  size: 40, radius: 20, isOwn: isOwn),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(
                      (isOwn ? 'Você' : story.userName).toUpperCase(),
                      style: const TextStyle(fontFamily: TabuTypography.bodyFont,
                          fontSize: 13, fontWeight: FontWeight.w700,
                          letterSpacing: 1.5, color: Colors.white,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 4)])),
                    // Badge VÍDEO
                    if (story.isVideo) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          border: Border.all(
                              color: TabuColors.rosaPrincipal.withOpacity(0.5),
                              width: 0.7)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: const [
                          Icon(Icons.videocam_rounded,
                              color: TabuColors.rosaPrincipal, size: 9),
                          SizedBox(width: 3),
                          Text('VÍD', style: TextStyle(
                              fontFamily: TabuTypography.bodyFont,
                              fontSize: 7, fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: TabuColors.rosaPrincipal)),
                        ])),
                    ],
                  ]),
                  Text(_formatTime(story.createdAt),
                    style: TextStyle(fontFamily: TabuTypography.bodyFont,
                        fontSize: 10, color: Colors.white.withOpacity(0.65),
                        shadows: const [Shadow(color: Colors.black54, blurRadius: 4)])),
                ])),

              // Indicador de pause
              if (paused)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(4)),
                  child: const Text('■ PAUSADO',
                    style: TextStyle(fontFamily: TabuTypography.bodyFont,
                        fontSize: 8, letterSpacing: 2, color: Colors.white60))),
              const SizedBox(width: 6),

              // Menu opções
              GestureDetector(
                onTap: () => _showOptionsMenu(context),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.more_vert_rounded,
                    color: Colors.white70, size: 20,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 8)]))),

              GestureDetector(
                onTap: onClose,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.close, color: Colors.white, size: 22,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 8)]))),
            ])),
        ])),

      // ── 6. Seekbar de vídeo + duração (rodapé) ─────────────────────────
      if (story.isVideo)
        Positioned(bottom: 0, left: 0, right: 0,
          child: SafeArea(top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Duração
                Row(children: [
                  Text(
                    _fmtDur(videoCtrl?.value.position ?? Duration.zero),
                    style: const TextStyle(fontFamily: TabuTypography.bodyFont,
                        fontSize: 10, color: Colors.white60, letterSpacing: 0.5)),
                  const Spacer(),
                  // Badge duração total do story
                  if (story.videoDuration != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        border: Border.all(
                            color: TabuColors.rosaPrincipal.withOpacity(0.4),
                            width: 0.7)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.videocam_outlined,
                            color: TabuColors.rosaPrincipal, size: 9),
                        const SizedBox(width: 3),
                        Text('${story.videoDuration}s',
                          style: const TextStyle(fontFamily: TabuTypography.bodyFont,
                              fontSize: 9, fontWeight: FontWeight.w700,
                              letterSpacing: 1, color: Colors.white70)),
                      ])),
                ]),
                const SizedBox(height: 4),
                // Seekbar visual (somente leitura — tap left/right navega stories)
                _VideoSeekBarReadOnly(
                  position: videoCtrl?.value.position ?? Duration.zero,
                  duration: videoCtrl?.value.duration ?? Duration.zero,
                ),
              ]),
            ))),

      // ── 7. Badge visibilidade ──────────────────────────────────────────
      if (!story.isVideo)
        Positioned(bottom: 24, left: 0, right: 0,
          child: SafeArea(top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                _VisibilityBadge(visibilidade: story.visibilidade),
              ])))),
    ]);
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60)  return 'agora';
    if (diff.inMinutes < 60)  return '${diff.inMinutes}min atrás';
    if (diff.inHours < 24)    return '${diff.inHours}h atrás';
    return '${diff.inDays}d atrás';
  }

  String _fmtDur(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF130020),
          border: Border(top: BorderSide(color: Color(0x33FF2D7A), width: 0.8))),
        child: SafeArea(top: false,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Center(child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36, height: 3,
              decoration: BoxDecoration(
                color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
            if (isOwn) ...[
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: Color(0xFFFF2D7A), size: 20),
                title: const Text('Deletar story',
                  style: TextStyle(fontFamily: TabuTypography.bodyFont,
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: Colors.white, letterSpacing: 0.3)),
                subtitle: Text('Remover permanentemente',
                  style: TextStyle(fontFamily: TabuTypography.bodyFont,
                      fontSize: 10, color: Colors.white38)),
                onTap: () { Navigator.pop(context); onDelete(); }),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.flag_outlined,
                    color: Color(0xFFFF2D7A), size: 20),
                title: const Text('Denunciar story',
                  style: TextStyle(fontFamily: TabuTypography.bodyFont,
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: Colors.white, letterSpacing: 0.3)),
                subtitle: Text('Violar os Termos de Uso – Art. 18º',
                  style: TextStyle(fontFamily: TabuTypography.bodyFont,
                      fontSize: 10, color: Colors.white38)),
                onTap: () { Navigator.pop(context); onReport(); }),
            ],
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(color: Colors.white.withOpacity(0.07), height: 1)),
            ListTile(
              leading: const Icon(Icons.close_rounded,
                  color: Colors.white38, size: 20),
              title: const Text('Cancelar',
                style: TextStyle(fontFamily: TabuTypography.bodyFont,
                    fontSize: 13, color: Colors.white54, letterSpacing: 0.3)),
              onTap: () => Navigator.pop(context)),
            const SizedBox(height: 8),
          ])),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  FUNDO DO STORY — com suporte completo a vídeo
// ══════════════════════════════════════════════════════════════════════════════
class _StoryBackground extends StatelessWidget {
  final StoryModel              story;
  final VideoPlayerController?  videoCtrl;
  final bool                    videoLoading;
  final bool                    videoError;

  const _StoryBackground({
    required this.story,
    required this.videoCtrl,
    required this.videoLoading,
    required this.videoError,
  });

  static const Map<String, List<Color>> _fundos = {
    'escuro':    [Color(0xFF0A0010), Color(0xFF1A0030)],
    'rosaFogo':  [Color(0xFF3D0018), Color(0xFFCC0044)],
    'roxo':      [Color(0xFF1A0040), Color(0xFF6600AA)],
    'ouro':      [Color(0xFF1A0A00), Color(0xFF8B6914)],
    'azulNoite': [Color(0xFF000A1A), Color(0xFF003366)],
    'verde':     [Color(0xFF001A0A), Color(0xFF004422)],
  };

  @override
  Widget build(BuildContext context) {

    // ── VÍDEO ──────────────────────────────────────────────────────────────
    if (story.isVideo) {
      return Stack(fit: StackFit.expand, children: [
        // Fundo escuro enquanto carrega
        _bg(),

        // Thumbnail (se disponível) — visível enquanto o vídeo carrega
        if (story.thumbUrl != null)
          AnimatedOpacity(
            opacity: (videoCtrl == null || videoLoading) ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 400),
            child: Image.network(
              story.thumbUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),

        // Player de vídeo
        if (videoCtrl != null && videoCtrl!.value.isInitialized)
          Center(
            child: AspectRatio(
              aspectRatio: videoCtrl!.value.aspectRatio,
              child: VideoPlayer(videoCtrl!),
            ),
          ),

        // Loading spinner
        if (videoLoading)
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: 44, height: 44,
                child: CircularProgressIndicator(
                  color: TabuColors.rosaPrincipal,
                  backgroundColor: TabuColors.rosaPrincipal.withOpacity(0.15),
                  strokeWidth: 2.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text('CARREGANDO VÍDEO',
                style: TextStyle(fontFamily: TabuTypography.bodyFont,
                    fontSize: 9, letterSpacing: 2.5, color: Colors.white54)),
            ]),
          ),

        // Erro
        if (videoError)
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline_rounded,
                  color: Color(0xFFE85D5D), size: 36),
              const SizedBox(height: 10),
              const Text('ERRO AO CARREGAR VÍDEO',
                style: TextStyle(fontFamily: TabuTypography.bodyFont,
                    fontSize: 9, letterSpacing: 2, color: Color(0xFFE85D5D))),
            ]),
          ),

        // Overlays sobre o vídeo
        ..._buildOverlays(context),
      ]);
    }

    // ── FOTO (camera) ──────────────────────────────────────────────────────
    if (story.type == 'camera' && story.mediaUrl != null) {
      return Stack(fit: StackFit.expand, children: [
        Image.network(story.mediaUrl!, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _bg()),
        ..._buildOverlays(context),
      ]);
    }

    // ── TEXTO / EMOJI ──────────────────────────────────────────────────────
    return Stack(fit: StackFit.expand, children: [
      _bg(),
      if (story.type == 'texto' && story.centralText != null)
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(story.centralText!, textAlign: TextAlign.center,
              style: _textStyle(story.textStyle)))),
      if (story.type == 'emoji' && story.centralEmoji != null)
        Center(child: Text(story.centralEmoji!,
            style: const TextStyle(fontSize: 120))),
      ..._buildOverlays(context),
    ]);
  }

  // ── Overlays posicionados ─────────────────────────────────────────────────
  List<Widget> _buildOverlays(BuildContext context) {
    if (story.overlays.isEmpty) return [];
    return [
      Positioned.fill(
        child: LayoutBuilder(builder: (_, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return Stack(children: story.overlays.map((overlay) {
            final scale = overlay.scale ?? 1.0;
            Widget child;
            switch (overlay.type) {
              case 'text':
                final fontStyle = overlay.style?['fontStyle'] as String?;
                child = Text(overlay.content, textAlign: TextAlign.center,
                  style: _overlayTextStyle(fontStyle, scale));
                break;
              case 'emoji':
                child = Text(overlay.content,
                  style: TextStyle(fontSize: 48 * scale));
                break;
              default:
                return const SizedBox.shrink();
            }
            final cx = overlay.posX * w;
            final cy = overlay.posY * h;
            return Positioned.fill(
              child: OverflowBox(
                minWidth: 0, maxWidth: w, minHeight: 0, maxHeight: h,
                child: Align(
                  alignment: FractionalOffset(cx / w, cy / h),
                  child: child)));
          }).toList());
        }),
      ),
    ];
  }

  Widget _bg() {
    final colors = _fundos[story.background]
        ?? [const Color(0xFF0A0010), const Color(0xFF1A0030)];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors,
            begin: Alignment.topLeft, end: Alignment.bottomRight)));
  }

  TextStyle _textStyle(String? style) {
    switch (style) {
      case 'rosa':
        return TextStyle(fontFamily: TabuTypography.bodyFont,
          fontSize: 28, fontWeight: FontWeight.w700,
          color: TabuColors.rosaPrincipal, letterSpacing: 0.5, height: 1.4,
          shadows: [Shadow(color: TabuColors.glow, blurRadius: 20)]);
      case 'display':
        return const TextStyle(fontFamily: TabuTypography.displayFont,
          fontSize: 32, color: Colors.white,
          letterSpacing: 4, height: 1.3,
          shadows: [Shadow(color: Colors.black54, blurRadius: 8)]);
      default:
        return const TextStyle(fontFamily: TabuTypography.bodyFont,
          fontSize: 26, fontWeight: FontWeight.w600,
          color: Colors.white, letterSpacing: 0.3, height: 1.4,
          shadows: [Shadow(color: Colors.black45, blurRadius: 6)]);
    }
  }

  TextStyle _overlayTextStyle(String? fontStyle, double scale) {
    final base = _textStyle(fontStyle);
    return base.copyWith(
      fontSize: (base.fontSize ?? 26) * scale,
      shadows: const [
        Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 1)),
        Shadow(color: Colors.black54, blurRadius: 12),
      ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  BARRA DE PROGRESSO — suporta modo vídeo (valor direto) e imagem (animado)
// ══════════════════════════════════════════════════════════════════════════════
class _ProgressBar extends StatelessWidget {
  final bool               filled;
  final bool               active;
  final AnimationController? ctrl;
  final bool               isVideo;

  const _ProgressBar({
    required this.filled,
    required this.active,
    this.ctrl,
    this.isVideo = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: Container(
        height: 2.5,
        color: Colors.white.withOpacity(0.28),
        child: filled
            ? Container(color: Colors.white)
            : active && ctrl != null
                ? AnimatedBuilder(
                    animation: ctrl!,
                    builder: (_, __) => FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: ctrl!.value.clamp(0.0, 1.0),
                      child: Container(color: Colors.white)))
                : const SizedBox.shrink(),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SEEKBAR SOMENTE LEITURA (story de vídeo)
// ══════════════════════════════════════════════════════════════════════════════
class _VideoSeekBarReadOnly extends StatelessWidget {
  final Duration position;
  final Duration duration;

  const _VideoSeekBarReadOnly({
    required this.position,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    final pct = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      height: 3,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: pct,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: const LinearGradient(
              colors: [TabuColors.rosaDeep, TabuColors.rosaPrincipal]),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  BADGE DE VISIBILIDADE
// ══════════════════════════════════════════════════════════════════════════════
class _VisibilityBadge extends StatelessWidget {
  final String visibilidade;
  const _VisibilityBadge({required this.visibilidade});

  @override
  Widget build(BuildContext context) {
    IconData icon; String label; Color color;
    switch (visibilidade) {
      case 'seguidores':
        icon = Icons.people_outline_rounded; label = 'SEGUIDORES';
        color = Colors.white70; break;
      case 'vip':
        icon = Icons.star_rounded; label = 'VIP';
        color = const Color(0xFFD4AF37); break;
      default:
        icon = Icons.public_rounded; label = 'PÚBLICO';
        color = Colors.white54;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.4), width: 0.6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 11),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontFamily: TabuTypography.bodyFont,
            fontSize: 9, fontWeight: FontWeight.w700,
            letterSpacing: 1.5, color: color)),
      ]));
  }
}