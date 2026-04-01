// lib/screens/screens_home/criar_story_screen.dart
//
// MUDANÇAS vs versão anterior:
//   • Novo modo _StoryMode.video — grava/escolhe vídeo até 30s
//   • VideoPlayerController para preview na etapa de edição
//   • Upload do vídeo para Firebase Storage (stories/$uid/videos/)
//   • Overlays (texto/emoji) funcionam sobre vídeo na etapa de edição
//   • Badge de duração + barra de progresso no player inline
//   • Validação de duração máxima (_maxVideoSeconds = 30)
//
import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/models/story_model.dart';
import 'package:tabuapp/services/services_app/story_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  CRIAR STORY SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class CreateStoryScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const CreateStoryScreen({super.key, required this.userData});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

enum _PermissaoStatus { verificando, pendente, negadoPermanente, concedido }

class _Overlay {
  final String conteudo;
  final bool isEmoji;
  double dx;
  double dy;
  double scale;

  _Overlay({
    required this.conteudo,
    required this.isEmoji,
    required this.dx,
    required this.dy,
    this.scale = 1.0,
  });
}

enum _PublishStep { idle, uploadingMedia, salvando, concluido, erro }

class _CreateStoryScreenState extends State<CreateStoryScreen>
    with TickerProviderStateMixin {

  static const int _maxVideoSeconds = 15;

  // ── Câmera ──────────────────────────────────────────────────────────────────
  CameraController? _cameraCtrl;
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;
  bool _flashOn = false;
  bool _cameraReady = false;

  // ── Controllers ─────────────────────────────────────────────────────────────
  final _textCtrl  = TextEditingController();
  final _textFocus = FocusNode();
  final _picker    = ImagePicker();

  // ── Animações ────────────────────────────────────────────────────────────────
  late AnimationController _captureAnimCtrl;
  late AnimationController _toolbarAnimCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _permissaoAnimCtrl;
  late Animation<double>   _captureAnim;
  late Animation<double>   _toolbarAnim;
  late Animation<double>   _pulseAnim;
  late Animation<double>   _permissaoAnim;

  // ── Permissões ───────────────────────────────────────────────────────────────
  _PermissaoStatus _permissaoCamera  = _PermissaoStatus.verificando;
  _PermissaoStatus _permissaoStorage = _PermissaoStatus.verificando;
  bool _solicitando = false;

  // ── Estado geral ─────────────────────────────────────────────────────────────
  _StoryMode _modoAtual  = _StoryMode.camera;
  _StoryStep _etapa      = _StoryStep.captura;
  File?      _midia;
  String?    _emojiSelecionado;
  _TextStyle _estiloTexto      = _TextStyle.branco;
  _Fundo     _fundoSelecionado = _Fundo.escuro;
  bool       _capturando       = false;

  // ── Vídeo ────────────────────────────────────────────────────────────────────
  VideoPlayerController? _videoCtrl;
  Duration?              _videoDuration;
  bool                   _videoPlaying = false;

  // ── Publicação ────────────────────────────────────────────────────────────────
  _PublishStep _publishStep   = _PublishStep.idle;
  double       _uploadProgress = 0.0;
  String?      _erroMsg;
  String       _visibilidade  = 'publico';

  // ── Ajuste de imagem da galeria ──────────────────────────────────────────────
  double _ajusteScale    = 1.0;
  double _ajusteRotation = 0.0;
  Offset _ajusteOffset   = Offset.zero;

  bool get _publicando =>
      _publishStep != _PublishStep.idle &&
      _publishStep != _PublishStep.concluido &&
      _publishStep != _PublishStep.erro;

  bool get _videoDuracaoValida =>
      _videoDuration != null &&
      _videoDuration!.inSeconds <= _maxVideoSeconds &&
      _videoDuration!.inSeconds > 0;

  // ── Overlays ─────────────────────────────────────────────────────────────────
  final List<_Overlay> _overlays     = [];
  bool  _toolTextOpen  = false;
  bool  _toolEmojiOpen = false;
  int?  _overlayAtivo;

  // ── Texto/emoji centralizado ─────────────────────────────────────────────────
  String _textoCentral = '';

  // ── Dimensões reais do editor ─────────────────────────────────────────────────
  double _editorW = 0;
  double _editorH = 0;

  static const _emojis = [
    '🔥','🎉','💃','🥂','😈','✨','💋','👑','🌙','⚡',
    '🍸','🎶','🤩','😍','💜','🩷','🎊','🌟','🪩','🎸',
  ];

  static const _fundoGradients = {
    _Fundo.escuro:    [Color(0xFF0D0010), Color(0xFF1A0020)],
    _Fundo.rosaFogo:  [Color(0xFF3D0018), Color(0xFF8B003A)],
    _Fundo.roxo:      [Color(0xFF0D0030), Color(0xFF4B0070)],
    _Fundo.ouro:      [Color(0xFF2A1500), Color(0xFF6B3500)],
    _Fundo.azulNoite: [Color(0xFF000518), Color(0xFF001240)],
    _Fundo.verde:     [Color(0xFF001A0A), Color(0xFF003A18)],
  };

  // ══════════════════════════════════════════════════════════════════════════
  //  INIT / DISPOSE
  // ══════════════════════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();

    _captureAnimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _captureAnim = Tween<double>(begin: 1.0, end: 0.88).animate(
        CurvedAnimation(parent: _captureAnimCtrl, curve: Curves.easeInOut));

    _toolbarAnimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    _toolbarAnim = CurvedAnimation(parent: _toolbarAnimCtrl, curve: Curves.easeOutCubic);
    _toolbarAnimCtrl.forward();

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _permissaoAnimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _permissaoAnim = CurvedAnimation(parent: _permissaoAnimCtrl, curve: Curves.easeOutCubic);

    _verificarPermissoes();
  }

  @override
  void dispose() {
    _cameraCtrl?.dispose();
    _textCtrl.dispose();
    _textFocus.dispose();
    _captureAnimCtrl.dispose();
    _toolbarAnimCtrl.dispose();
    _pulseCtrl.dispose();
    _permissaoAnimCtrl.dispose();
    _videoCtrl?.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PERMISSÕES
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _verificarPermissoes() async {
    final camera  = await Permission.camera.status;
    final storage = await _storageStatus();
    if (!mounted) return;
    setState(() {
      _permissaoCamera  = _mapear(camera);
      _permissaoStorage = _mapear(storage);
    });
    _permissaoAnimCtrl.forward();
    if (_permissaoCamera == _PermissaoStatus.concedido) _iniciarCamera();
  }

  Future<PermissionStatus> _storageStatus() async {
    if (Platform.isAndroid) {
      final m = await Permission.photos.status;
      if (m != PermissionStatus.denied && m != PermissionStatus.permanentlyDenied) return m;
      return Permission.storage.status;
    }
    return Permission.photos.status;
  }

  _PermissaoStatus _mapear(PermissionStatus s) {
    switch (s) {
      case PermissionStatus.granted:
      case PermissionStatus.limited:
        return _PermissaoStatus.concedido;
      case PermissionStatus.permanentlyDenied:
        return _PermissaoStatus.negadoPermanente;
      default:
        return _PermissaoStatus.pendente;
    }
  }

  Future<void> _solicitarPermissoes() async {
    if (_solicitando) return;
    setState(() => _solicitando = true);
    HapticFeedback.mediumImpact();
    final camera = await Permission.camera.request();
    PermissionStatus storage;
    if (Platform.isAndroid) {
      storage = await Permission.photos.request();
      if (storage == PermissionStatus.denied || storage == PermissionStatus.permanentlyDenied)
        storage = await Permission.storage.request();
    } else {
      storage = await Permission.photos.request();
    }
    if (!mounted) return;
    setState(() {
      _solicitando      = false;
      _permissaoCamera  = _mapear(camera);
      _permissaoStorage = _mapear(storage);
    });
    if (_permissaoCamera == _PermissaoStatus.concedido) {
      HapticFeedback.mediumImpact();
      _iniciarCamera();
    }
  }

  bool get _cameraLiberada   => _permissaoCamera  == _PermissaoStatus.concedido;
  bool get _storageLiberado  => _permissaoStorage == _PermissaoStatus.concedido;
  bool get _negadoPerm       =>
      _permissaoCamera  == _PermissaoStatus.negadoPermanente ||
      _permissaoStorage == _PermissaoStatus.negadoPermanente;

  // ══════════════════════════════════════════════════════════════════════════
  //  CÂMERA
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _iniciarCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;
      await _montarCamera(_cameraIndex);
    } catch (_) {}
  }

  Future<void> _montarCamera(int index) async {
    await _cameraCtrl?.dispose();
    if (!mounted) return;
    final ctrl = CameraController(_cameras[index], ResolutionPreset.medium, enableAudio: true);
    try {
      await ctrl.initialize();
      if (!mounted) { ctrl.dispose(); return; }
      await ctrl.setFlashMode(_flashOn ? FlashMode.torch : FlashMode.off);
      setState(() { _cameraCtrl = ctrl; _cameraReady = true; });
    } catch (_) { ctrl.dispose(); }
  }

  Future<void> _virarCamera() async {
    if (_cameras.length < 2) return;
    setState(() => _cameraReady = false);
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _montarCamera(_cameraIndex);
  }

  Future<void> _toggleFlash() async {
    if (_cameraCtrl == null || !_cameraReady) return;
    _flashOn = !_flashOn;
    await _cameraCtrl!.setFlashMode(_flashOn ? FlashMode.torch : FlashMode.off);
    setState(() {});
  }

  Future<void> _tirarFoto() async {
    if (_capturando || _cameraCtrl == null || !_cameraReady) return;
    setState(() => _capturando = true);
    HapticFeedback.mediumImpact();
    await _captureAnimCtrl.forward();
    await _captureAnimCtrl.reverse();
    try {
      final xFile = await _cameraCtrl!.takePicture();
      if (!mounted) return;
      setState(() {
        _midia     = File(xFile.path);
        _etapa     = _StoryStep.edicao;
        _capturando = false;
      });
      _toolbarAnimCtrl..reset()..forward();
    } catch (_) {
      setState(() => _capturando = false);
    }
  }

  // ── Gravar vídeo pela câmera ───────────────────────────────────────────────
  Future<void> _gravarVideoCamera() async {
    if (_cameraCtrl == null || !_cameraReady) return;

    if (_cameraCtrl!.value.isRecordingVideo) {
      // Para a gravação
      HapticFeedback.heavyImpact();
      final xFile = await _cameraCtrl!.stopVideoRecording();
      await _processarVideoFile(File(xFile.path));
    } else {
      // Inicia a gravação
      HapticFeedback.mediumImpact();
      await _cameraCtrl!.prepareForVideoRecording();
      await _cameraCtrl!.startVideoRecording();
      setState(() {});

      // Para automaticamente após _maxVideoSeconds
      Future.delayed(Duration(seconds: _maxVideoSeconds), () async {
        if (_cameraCtrl?.value.isRecordingVideo == true) {
          final xFile = await _cameraCtrl!.stopVideoRecording();
          await _processarVideoFile(File(xFile.path));
        }
      });
    }
  }

  bool get _gravandoVideo => _cameraCtrl?.value.isRecordingVideo == true;

  Future<void> _pickGaleriaVideo() async {
    final p = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: _maxVideoSeconds),
    );
    if (p == null) return;
    await _processarVideoFile(File(p.path));
  }

  Future<void> _processarVideoFile(File file) async {
    final ctrl = VideoPlayerController.file(file);
    await ctrl.initialize();
    final dur = ctrl.value.duration;

    if (dur.inSeconds > _maxVideoSeconds) {
      ctrl.dispose();
      if (mounted) _snack('Vídeo muito longo. Máximo: $_maxVideoSeconds segundos.');
      return;
    }

    ctrl.setLooping(true);
    ctrl.addListener(() { if (mounted) setState(() => _videoPlaying = ctrl.value.isPlaying); });

    if (!mounted) { ctrl.dispose(); return; }

    await _videoCtrl?.dispose();
    setState(() {
      _midia         = file;
      _videoCtrl     = ctrl;
      _videoDuration = dur;
      _videoPlaying  = false;
      _etapa         = _StoryStep.edicao;
    });
    _toolbarAnimCtrl..reset()..forward();
  }

  void _toggleVideoPlay() {
    if (_videoCtrl == null) return;
    if (_videoCtrl!.value.isPlaying) {
      _videoCtrl!.pause();
    } else {
      if (_videoCtrl!.value.position >= _videoCtrl!.value.duration)
        _videoCtrl!.seekTo(Duration.zero);
      _videoCtrl!.play();
    }
    HapticFeedback.selectionClick();
  }

  Future<void> _pickGaleria() async {
    if (!_storageLiberado) {
      await _solicitarPermissoes();
      if (!_storageLiberado) return;
    }
    final p = await _picker.pickImage(
      source: ImageSource.gallery, maxWidth: 1920, maxHeight: 1920, imageQuality: 95);
    if (p == null) return;

    if (!mounted) return;
    final result = await Navigator.push<_AdjustResult>(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => _ImageAdjustScreen(imageFile: File(p.path)),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut), child: child),
        transitionDuration: const Duration(milliseconds: 220),
      ),
    );

    if (result == null || !mounted) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _midia          = result.file;
      _ajusteScale    = result.scale;
      _ajusteRotation = result.rotation;
      _ajusteOffset   = Offset(result.offsetXNorm, result.offsetYNorm);
      _etapa          = _StoryStep.edicao;
    });
    _toolbarAnimCtrl..reset()..forward();
  }

  void _voltarCaptura() {
    _videoCtrl?.dispose();
    setState(() {
      _midia          = null;
      _etapa          = _StoryStep.captura;
      _ajusteScale    = 1.0;
      _ajusteRotation = 0.0;
      _ajusteOffset   = Offset.zero;
      _overlays.clear();
      _toolTextOpen   = false;
      _toolEmojiOpen  = false;
      _overlayAtivo   = null;
      _textoCentral   = '';
      _emojiSelecionado = null;
      _publishStep    = _PublishStep.idle;
      _uploadProgress = 0.0;
      _erroMsg        = null;
      _editorW        = 0;
      _editorH        = 0;
      _videoCtrl      = null;
      _videoDuration  = null;
      _videoPlaying   = false;
    });
    _toolbarAnimCtrl..reset()..forward();
    if (_cameraLiberada && (_cameraCtrl == null || !_cameraReady)) _iniciarCamera();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PUBLICAR
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _publicar() async {
    if (_publicando) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();

    final uid =
        FirebaseAuth.instance.currentUser?.uid ??
        (widget.userData['uid'] as String?) ??
        (widget.userData['id'] as String?) ?? '';
    if (uid.isEmpty) { _snack('Erro: usuário não autenticado.'); return; }

    setState(() { _publishStep = _PublishStep.uploadingMedia; _uploadProgress = 0.0; _erroMsg = null; });

    try {
      String? mediaUrl;
      int?    videoDurationSec;

      final isVideoMode = _modoAtual == _StoryMode.video;

      if (isVideoMode && _midia != null) {
        // ── Upload vídeo ──────────────────────────────────────────────────────
        videoDurationSec = _videoDuration?.inSeconds;
        final ts  = DateTime.now().millisecondsSinceEpoch;
        final ref = FirebaseStorage.instance.ref('stories/$uid/videos/${ts}.mp4');

        final task = ref.putFile(_midia!, SettableMetadata(contentType: 'video/mp4'));
        task.snapshotEvents.listen((snap) {
          if (!mounted) return;
          setState(() => _uploadProgress =
              snap.bytesTransferred / (snap.totalBytes == 0 ? 1 : snap.totalBytes));
        });
        await task;
        mediaUrl = await ref.getDownloadURL();

      } else if (_modoAtual == _StoryMode.camera && _midia != null) {
        // ── Upload foto ───────────────────────────────────────────────────────
        final ref = FirebaseStorage.instance
            .ref('stories/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg');
        final task = ref.putFile(_midia!, SettableMetadata(contentType: 'image/jpeg'));
        task.snapshotEvents.listen((snap) {
          if (!mounted) return;
          setState(() => _uploadProgress =
              snap.bytesTransferred / (snap.totalBytes == 0 ? 1 : snap.totalBytes));
        });
        await task;
        mediaUrl = await ref.getDownloadURL();
      }

      if (!mounted) return;
      setState(() => _publishStep = _PublishStep.salvando);

      final edW = _editorW > 0 ? _editorW : MediaQuery.of(context).size.width;
      final edH = _editorH > 0 ? _editorH : MediaQuery.of(context).size.height;

      final overlaysSalvar = _overlays.map((o) => StoryOverlay(
        type:    o.isEmoji ? 'emoji' : 'text',
        content: o.conteudo,
        posX:    (o.dx / edW).clamp(0.0, 1.0),
        posY:    (o.dy / edH).clamp(0.0, 1.0),
        scale:   o.scale,
        style:   o.isEmoji ? null : {'fontStyle': _estiloTexto.name},
      )).toList();

      await StoryService.instance.createStory(
        userId:        uid,
        userName:      (widget.userData['name'] as String? ?? 'Anônimo').toUpperCase(),
        userAvatar:    widget.userData['avatar'] as String?,
        type:          _modoAtual.name,
        mediaUrl:      mediaUrl,
        background:    _fundoSelecionado.name,
        centralText:   _textoCentral.isEmpty ? null : _textoCentral,
        centralEmoji:  _emojiSelecionado,
        textStyle:     _estiloTexto.name,
        overlays:      overlaysSalvar,
        visibilidade:  _visibilidade,
        videoDuration: videoDurationSec,
      );

      if (!mounted) return;
      setState(() => _publishStep = _PublishStep.concluido);
      HapticFeedback.mediumImpact();
      _snack('Story publicado! ✨ Expira em 24h', success: true);
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.pop(context, true);

    } catch (e) {
      if (!mounted) return;
      setState(() { _publishStep = _PublishStep.erro; _erroMsg = 'Erro ao publicar. Tente novamente.'; });
      _snack(_erroMsg!);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _publishStep = _PublishStep.idle);
    }
  }

  void _snack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: success ? TabuColors.rosaDeep : const Color(0xFF3D0A0A),
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
      content: Text(msg, style: const TextStyle(
        fontFamily: TabuTypography.bodyFont,
        fontSize: 12, fontWeight: FontWeight.w700,
        letterSpacing: 1.5, color: TabuColors.branco)),
    ));
  }

  void _confirmarTexto() {
    final txt = _textCtrl.text.trim();
    if (txt.isEmpty) return;

    if (_etapa == _StoryStep.captura && _modoAtual == _StoryMode.texto) {
      setState(() {
        _textoCentral = txt; _textCtrl.clear();
        _etapa = _StoryStep.edicao; _toolTextOpen = false;
      });
      FocusScope.of(context).unfocus();
      HapticFeedback.mediumImpact();
      _toolbarAnimCtrl..reset()..forward();
      return;
    }

    final edW = _editorW > 0 ? _editorW : MediaQuery.of(context).size.width;
    final edH = _editorH > 0 ? _editorH : MediaQuery.of(context).size.height;
    setState(() {
      _overlays.add(_Overlay(
        conteudo: txt, isEmoji: false,
        dx: edW * 0.5,
        dy: edH * 0.42 + (_overlays.length * 52.0),
      ));
      _textCtrl.clear(); _toolTextOpen = false;
    });
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
  }

  void _confirmarEmoji() {
    if (_emojiSelecionado == null) return;
    setState(() { _etapa = _StoryStep.edicao; _toolTextOpen = false; _toolEmojiOpen = false; });
    HapticFeedback.mediumImpact();
    _toolbarAnimCtrl..reset()..forward();
  }

  void _adicionarEmojiOverlay(String emoji) {
    final edW = _editorW > 0 ? _editorW : MediaQuery.of(context).size.width;
    final edH = _editorH > 0 ? _editorH : MediaQuery.of(context).size.height;
    final rng = math.Random();
    setState(() {
      _overlays.add(_Overlay(
        conteudo: emoji, isEmoji: true,
        dx: edW * (0.35 + rng.nextDouble() * 0.3),
        dy: edH * (0.35 + rng.nextDouble() * 0.2),
        scale: 1.0,
      ));
      _toolEmojiOpen = false;
    });
    HapticFeedback.selectionClick();
  }

  void _removerOverlay(int index) {
    setState(() { _overlays.removeAt(index); _overlayAtivo = null; });
    HapticFeedback.mediumImpact();
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
        body: FadeTransition(
          opacity: _permissaoAnim,
          child: _cameraLiberada
              ? (_etapa == _StoryStep.captura ? _buildCapturaStep() : _buildEdicaoStep())
              : _buildPermissaoGate(),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PERMISSÃO GATE  (igual ao original)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildPermissaoGate() {
    return Stack(children: [
      Positioned.fill(child: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(
          colors: [Color(0xFF0A0010), Color(0xFF130020)],
          begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: CustomPaint(painter: _ParticlePainter(color: TabuColors.rosaPrincipal, seed: 7, count: 40)),
      )),
      Positioned.fill(child: Container(decoration: BoxDecoration(
        gradient: RadialGradient(center: Alignment.center, radius: 0.8,
          colors: [TabuColors.rosaPrincipal.withOpacity(0.07), Colors.transparent])))),
      _neonLine(),
      SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
          child: Row(children: [
            _IconBtn(icon: Icons.close, onTap: () => Navigator.pop(context)),
            const Spacer(), _storyLabel(), const Spacer(),
            const SizedBox(width: 40),
          ])),
        const Spacer(),
        ScaleTransition(scale: _pulseAnim, child: Stack(alignment: Alignment.center, children: [
          Container(width: 110, height: 110, decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: TabuColors.rosaPrincipal.withOpacity(0.2), width: 1),
            gradient: RadialGradient(colors: [TabuColors.rosaPrincipal.withOpacity(0.06), Colors.transparent]))),
          Container(width: 80, height: 80, decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: TabuColors.rosaPrincipal.withOpacity(0.1),
            border: Border.all(color: TabuColors.rosaPrincipal.withOpacity(0.4), width: 1.5),
            boxShadow: [BoxShadow(color: TabuColors.glow.withOpacity(0.3), blurRadius: 20, spreadRadius: 2)]),
            child: const Icon(Icons.photo_camera_outlined, color: TabuColors.rosaPrincipal, size: 34)),
        ])),
        const SizedBox(height: 32),
        const Text('ACESSO NECESSÁRIO', style: TextStyle(fontFamily: TabuTypography.displayFont,
            fontSize: 22, letterSpacing: 5, color: TabuColors.branco)),
        const SizedBox(height: 12),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text('Para criar stories incríveis, o Tabu precisa acessar sua câmera e galeria.',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: TabuTypography.bodyFont,
              fontSize: 13, letterSpacing: 0.3, height: 1.6,
              color: Colors.white.withOpacity(0.55)))),
        const SizedBox(height: 36),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Column(children: [
          _PermissaoCard(icon: Icons.photo_camera_outlined, titulo: 'CÂMERA',
            descricao: 'Tirar fotos e gravar vídeos', status: _permissaoCamera),
          const SizedBox(height: 12),
          _PermissaoCard(icon: Icons.photo_library_outlined, titulo: 'GALERIA',
            descricao: 'Escolher imagens e vídeos', status: _permissaoStorage),
        ])),
        const SizedBox(height: 32),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _negadoPerm ? _btnConfiguracoes() : _btnPermitir()),
        if (_negadoPerm) ...[
          const SizedBox(height: 16),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text('Você bloqueou permanentemente. Vá em Configurações para habilitar.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: TabuTypography.bodyFont,
                fontSize: 11, color: Colors.white.withOpacity(0.35)))),
        ],
        const Spacer(), const SizedBox(height: 24),
      ])),
    ]);
  }

  Widget _btnPermitir() => GestureDetector(
    onTap: _solicitando ? null : _solicitarPermissoes,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity, height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [TabuColors.rosaDeep, TabuColors.rosaPrincipal],
          begin: Alignment.centerLeft, end: Alignment.centerRight),
        border: Border.all(color: TabuColors.rosaPrincipal, width: 1),
        boxShadow: [BoxShadow(color: TabuColors.glow.withOpacity(0.5), blurRadius: 24, spreadRadius: 2)]),
      child: Center(child: _solicitando
          ? const SizedBox(width: 22, height: 22,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Row(mainAxisSize: MainAxisSize.min, children: const [
              Icon(Icons.lock_open_rounded, color: Colors.white, size: 18), SizedBox(width: 10),
              Text('PERMITIR ACESSO', style: TextStyle(fontFamily: TabuTypography.bodyFont,
                  fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 3, color: Colors.white)),
            ]))));

  Widget _btnConfiguracoes() => GestureDetector(
    onTap: () => openAppSettings(),
    child: Container(width: double.infinity, height: 56,
      decoration: BoxDecoration(border: Border.all(color: TabuColors.rosaPrincipal.withOpacity(0.6), width: 1)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
        Icon(Icons.settings_outlined, color: TabuColors.rosaPrincipal, size: 18), SizedBox(width: 10),
        Text('ABRIR CONFIGURAÇÕES', style: TextStyle(fontFamily: TabuTypography.bodyFont,
            fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 2.5, color: TabuColors.rosaPrincipal)),
      ])));

  // ══════════════════════════════════════════════════════════════════════════
  //  ETAPA 1 — CAPTURA
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildCapturaStep() {
    return Stack(children: [
      Positioned.fill(child: _buildViewfinder()),
      Positioned(top: 0, left: 0, right: 0, height: 180,
        child: Container(decoration: const BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xCC000000), Colors.transparent])))),
      Positioned(bottom: 0, left: 0, right: 0, height: 280,
        child: Container(decoration: const BoxDecoration(gradient: LinearGradient(
          begin: Alignment.bottomCenter, end: Alignment.topCenter,
          colors: [Color(0xDD000000), Colors.transparent])))),
      _neonLine(),
      SafeArea(child: Column(children: [
        _buildTopBarCaptura(),
        Expanded(child: _buildModeContent()),
        _buildModoSelector(),
        _buildBottomCaptura(),
        const SizedBox(height: 20),
      ])),
    ]);
  }

  Widget _buildViewfinder() {
    if (_modoAtual == _StoryMode.camera || _modoAtual == _StoryMode.video) {
      if (_cameraReady && _cameraCtrl != null) {
        return SizedBox.expand(child: FittedBox(fit: BoxFit.cover,
          child: SizedBox(
            width:  _cameraCtrl!.value.previewSize!.height,
            height: _cameraCtrl!.value.previewSize!.width,
            child:  CameraPreview(_cameraCtrl!))));
      }
      return Container(color: Colors.black, child: Center(
        child: SizedBox(width: 32, height: 32,
          child: CircularProgressIndicator(
            color: TabuColors.rosaPrincipal.withOpacity(0.6), strokeWidth: 1.5))));
    }
    if (_modoAtual == _StoryMode.texto) {
      final colors = _fundoGradients[_fundoSelecionado]!;
      return Container(
        decoration: BoxDecoration(gradient: LinearGradient(
          colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: CustomPaint(painter: _ParticlePainter(color: Colors.white, seed: 42, count: 60)));
    }
    return Container(color: Colors.black);
  }

  Widget _buildTopBarCaptura() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(children: [
        _IconBtn(icon: Icons.close, onTap: () => Navigator.pop(context)),
        const Spacer(), _storyLabel(), const Spacer(),
        if (_modoAtual == _StoryMode.camera || _modoAtual == _StoryMode.video)
          Row(children: [
            if (_modoAtual == _StoryMode.camera)
              _IconBtn(
                icon: _flashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                onTap: _toggleFlash, active: _flashOn),
            const SizedBox(width: 6),
            _IconBtn(icon: Icons.cameraswitch_outlined, onTap: _virarCamera),
          ])
        else
          const SizedBox(width: 88),
      ]),
    );
  }

  Widget _buildModeContent() {
    if (_modoAtual == _StoryMode.texto) return _buildModoTexto();
    if (_modoAtual == _StoryMode.emoji) return _buildModoEmoji();
    // camera e video mostram apenas o viewfinder (sem conteúdo extra central)
    return const SizedBox.shrink();
  }

  Widget _buildModoTexto() {
    return GestureDetector(
      onTap: () => FocusScope.of(context).requestFocus(_textFocus),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(height: 40, child: ListView(scrollDirection: Axis.horizontal,
            children: _Fundo.values.map((f) {
              final sel    = _fundoSelecionado == f;
              final colors = _fundoGradients[f]!;
              return GestureDetector(
                onTap: () => setState(() => _fundoSelecionado = f),
                child: AnimatedContainer(duration: const Duration(milliseconds: 150),
                  width: 32, height: 32, margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                    border: Border.all(color: sel ? TabuColors.branco : Colors.white.withOpacity(0.2),
                      width: sel ? 2 : 0.8))));
            }).toList())),
          const SizedBox(height: 32),
          Container(constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              border: Border.all(
                color: _textFocus.hasFocus
                    ? TabuColors.rosaPrincipal.withOpacity(0.6)
                    : Colors.white.withOpacity(0.15), width: 1)),
            child: TextField(
              controller: _textCtrl, focusNode: _textFocus,
              maxLines: 5, maxLength: 200,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              style: TextStyle(
                fontFamily: _estiloTexto == _TextStyle.display
                    ? TabuTypography.displayFont : TabuTypography.bodyFont,
                fontSize: 22, fontWeight: FontWeight.w700,
                color: _estiloTexto == _TextStyle.branco ? Colors.white
                    : _estiloTexto == _TextStyle.rosa ? TabuColors.rosaClaro : Colors.black,
                letterSpacing: _estiloTexto == _TextStyle.display ? 3 : 0.5, height: 1.4,
                shadows: [Shadow(color: Colors.black.withOpacity(0.7), blurRadius: 8)]),
              decoration: InputDecoration(
                hintText: 'O que está rolando?',
                hintStyle: TextStyle(fontFamily: TabuTypography.bodyFont,
                  fontSize: 20, color: Colors.white.withOpacity(0.3), fontWeight: FontWeight.w400),
                border: InputBorder.none, counterText: '', contentPadding: EdgeInsets.zero))),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.center,
            children: _TextStyle.values.map((s) {
              final sel = _estiloTexto == s;
              return GestureDetector(
                onTap: () => setState(() => _estiloTexto = s),
                child: AnimatedContainer(duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? TabuColors.rosaPrincipal.withOpacity(0.2) : Colors.black.withOpacity(0.3),
                    border: Border.all(
                      color: sel ? TabuColors.rosaPrincipal : Colors.white.withOpacity(0.2),
                      width: sel ? 1.2 : 0.5)),
                  child: Text(s.label, style: TextStyle(
                    fontFamily: s == _TextStyle.display ? TabuTypography.displayFont : TabuTypography.bodyFont,
                    fontSize: s == _TextStyle.display ? 10 : 9, fontWeight: FontWeight.w700,
                    letterSpacing: s == _TextStyle.display ? 2 : 1.5,
                    color: sel ? TabuColors.rosaPrincipal : Colors.white.withOpacity(0.6)))));
            }).toList()),
        ])));
  }

  Widget _buildModoEmoji() {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        AnimatedSwitcher(duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
          child: _emojiSelecionado != null
              ? Text(_emojiSelecionado!, key: ValueKey(_emojiSelecionado),
                  style: const TextStyle(fontSize: 110))
              : Column(key: const ValueKey('ph'), children: [
                  Icon(Icons.emoji_emotions_outlined, color: Colors.white.withOpacity(0.2), size: 60),
                  const SizedBox(height: 10),
                  Text('ESCOLHA UM EMOJI', style: TextStyle(fontFamily: TabuTypography.bodyFont,
                    fontSize: 10, fontWeight: FontWeight.w700,
                    letterSpacing: 2.5, color: Colors.white.withOpacity(0.3))),
                ])),
        const SizedBox(height: 32),
        Container(padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5)),
          child: GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1),
            itemCount: _emojis.length,
            itemBuilder: (_, i) {
              final emoji = _emojis[i];
              final sel   = _emojiSelecionado == emoji;
              return GestureDetector(
                onTap: () { setState(() => _emojiSelecionado = sel ? null : emoji); HapticFeedback.selectionClick(); },
                child: AnimatedContainer(duration: const Duration(milliseconds: 140),
                  decoration: BoxDecoration(
                    color: sel ? TabuColors.rosaPrincipal.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                    border: Border.all(
                      color: sel ? TabuColors.rosaPrincipal : Colors.white.withOpacity(0.1),
                      width: sel ? 1.5 : 0.5),
                    borderRadius: BorderRadius.circular(6)),
                  child: Center(child: Text(emoji, style: const TextStyle(fontSize: 28)))));
            })),
      ]));
  }

  Widget _buildModoSelector() {
  return Padding(
    padding: const EdgeInsets.only(bottom: 20, top: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: _StoryMode.values.map((m) {
        final sel = _modoAtual == m;
        return Expanded(
          child: GestureDetector(
            onTap: () { setState(() => _modoAtual = m); HapticFeedback.selectionClick(); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
              decoration: BoxDecoration(
                color: sel ? TabuColors.rosaPrincipal.withOpacity(0.18) : Colors.transparent,
                border: Border.all(
                  color: sel ? TabuColors.rosaPrincipal : Colors.white.withOpacity(0.25),
                  width: sel ? 1.2 : 0.5)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(m.icon, size: 14,
                  color: sel ? TabuColors.rosaPrincipal : Colors.white.withOpacity(0.55)),
                const SizedBox(height: 3),
                Text(m.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: sel ? TabuColors.rosaPrincipal : Colors.white.withOpacity(0.55))),
              ]))));
      }).toList()));
}
  Widget _buildBottomCaptura() {
    if (_modoAtual == _StoryMode.texto) {
      final ok = _textCtrl.text.trim().isNotEmpty;
      return Padding(padding: const EdgeInsets.symmetric(horizontal: 40),
        child: GestureDetector(onTap: ok ? _confirmarTexto : null,
          child: AnimatedContainer(duration: const Duration(milliseconds: 200),
            width: double.infinity, height: 52,
            decoration: BoxDecoration(
              color: ok ? TabuColors.rosaPrincipal : Colors.white.withOpacity(0.1),
              border: Border.all(
                color: ok ? TabuColors.rosaPrincipal : Colors.white.withOpacity(0.2), width: 0.8),
              boxShadow: ok ? [BoxShadow(color: TabuColors.glow.withOpacity(0.4), blurRadius: 20)] : null),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('CONTINUAR', style: TextStyle(fontFamily: TabuTypography.bodyFont,
                fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 3,
                color: ok ? TabuColors.branco : Colors.white.withOpacity(0.3))),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded,
                color: ok ? TabuColors.branco : Colors.white.withOpacity(0.3), size: 13),
            ]))));
    }

    if (_modoAtual == _StoryMode.emoji) {
      final ok = _emojiSelecionado != null;
      return Padding(padding: const EdgeInsets.symmetric(horizontal: 40),
        child: GestureDetector(onTap: ok ? _confirmarEmoji : null,
          child: AnimatedContainer(duration: const Duration(milliseconds: 200),
            width: double.infinity, height: 52,
            decoration: BoxDecoration(
              color: ok ? TabuColors.rosaPrincipal : Colors.white.withOpacity(0.1),
              border: Border.all(
                color: ok ? TabuColors.rosaPrincipal : Colors.white.withOpacity(0.2), width: 0.8),
              boxShadow: ok ? [BoxShadow(color: TabuColors.glow.withOpacity(0.4), blurRadius: 20)] : null),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (_emojiSelecionado != null) ...[
                Text(_emojiSelecionado!, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
              ],
              Text('USAR EMOJI', style: TextStyle(fontFamily: TabuTypography.bodyFont,
                fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 3,
                color: ok ? TabuColors.branco : Colors.white.withOpacity(0.3))),
            ]))));
    }

    // ── CÂMERA (foto) ──────────────────────────────────────────────────────────
    if (_modoAtual == _StoryMode.camera) {
      return Padding(padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center, children: [
          GestureDetector(onTap: _pickGaleria,
            child: Container(width: 52, height: 52,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                color: Colors.white.withOpacity(0.15),
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 0.8)),
              child: const Icon(Icons.photo_library_outlined, color: Colors.white, size: 22))),
          GestureDetector(onTap: _tirarFoto,
            child: ScaleTransition(scale: _captureAnim,
              child: Stack(alignment: Alignment.center, children: [
                ScaleTransition(scale: _pulseAnim, child: Container(width: 88, height: 88,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    border: Border.all(color: TabuColors.rosaPrincipal.withOpacity(0.5), width: 2)))),
                Container(width: 74, height: 74, decoration: BoxDecoration(shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.25), blurRadius: 16, spreadRadius: 2)])),
                Container(width: 64, height: 64, decoration: BoxDecoration(shape: BoxShape.circle,
                  border: Border.all(color: TabuColors.rosaPrincipal.withOpacity(0.3), width: 2))),
              ]))),
          GestureDetector(onTap: _virarCamera,
            child: Container(width: 52, height: 52,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                color: Colors.white.withOpacity(0.15),
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 0.8)),
              child: const Icon(Icons.cameraswitch_outlined, color: Colors.white, size: 22))),
        ]));
    }

    // ── VÍDEO ──────────────────────────────────────────────────────────────────
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Botão principal de gravação
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center, children: [
          // Galeria
          GestureDetector(onTap: _pickGaleriaVideo,
            child: Container(width: 52, height: 52,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                color: Colors.white.withOpacity(0.15),
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 0.8)),
              child: const Icon(Icons.video_library_outlined, color: Colors.white, size: 22))),
          // Botão gravar
          GestureDetector(onTap: _gravarVideoCamera,
            child: ScaleTransition(scale: _captureAnim,
              child: Stack(alignment: Alignment.center, children: [
                ScaleTransition(scale: _gravandoVideo ? _pulseAnim : const AlwaysStoppedAnimation(1.0),
                  child: Container(width: 88, height: 88,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                      border: Border.all(
                        color: _gravandoVideo
                            ? const Color(0xFFE85D5D)
                            : TabuColors.rosaPrincipal.withOpacity(0.5),
                        width: 2)))),
                AnimatedContainer(duration: const Duration(milliseconds: 200),
                  width: 74, height: 74,
                  decoration: BoxDecoration(
                    shape: _gravandoVideo ? BoxShape.rectangle : BoxShape.circle,
                    borderRadius: _gravandoVideo ? BorderRadius.circular(8) : null,
                    color: _gravandoVideo ? const Color(0xFFE85D5D) : Colors.white,
                    boxShadow: [BoxShadow(
                      color: (_gravandoVideo ? const Color(0xFFE85D5D) : Colors.white).withOpacity(0.25),
                      blurRadius: 16, spreadRadius: 2)])),
              ]))),
          // Virar câmera
          GestureDetector(onTap: _virarCamera,
            child: Container(width: 52, height: 52,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                color: Colors.white.withOpacity(0.15),
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 0.8)),
              child: const Icon(Icons.cameraswitch_outlined, color: Colors.white, size: 22))),
        ]),
        const SizedBox(height: 10),
        Text(
          _gravandoVideo ? '● GRAVANDO... (toque para parar)' : 'Toque para gravar · máx $_maxVideoSeconds seg',
          style: TextStyle(fontFamily: TabuTypography.bodyFont,
            fontSize: 10, fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: _gravandoVideo ? const Color(0xFFE85D5D) : Colors.white.withOpacity(0.5))),
      ]));
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ETAPA 2 — EDIÇÃO
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildEdicaoStep() {
    return LayoutBuilder(builder: (context, constraints) {
      final sw = constraints.maxWidth;
      final sh = constraints.maxHeight;
      _editorW = sw;
      _editorH = sh;

      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => setState(() {
          _overlayAtivo  = null;
          _toolTextOpen  = false;
          _toolEmojiOpen = false;
        }),
        child: Stack(children: [
          Positioned.fill(child: _buildEdicaoPreview()),
          // Gradientes
          Positioned(top: 0, left: 0, right: 0, height: 160,
            child: Container(decoration: const BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xBB000000), Colors.transparent])))),
          Positioned(bottom: 0, left: 0, right: 0, height: 200,
            child: Container(decoration: const BoxDecoration(gradient: LinearGradient(
              begin: Alignment.bottomCenter, end: Alignment.topCenter,
              colors: [Color(0xCC000000), Colors.transparent])))),
          // Texto centralizado (modo texto)
          if (_modoAtual == _StoryMode.texto && _textoCentral.isNotEmpty)
            Positioned.fill(child: IgnorePointer(child: Center(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(_textoCentral, textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: _estiloTexto == _TextStyle.display
                      ? TabuTypography.displayFont : TabuTypography.bodyFont,
                  fontSize: 28, fontWeight: FontWeight.w700,
                  color: _estiloTexto == _TextStyle.branco ? Colors.white
                      : _estiloTexto == _TextStyle.rosa ? TabuColors.rosaClaro : Colors.black,
                  letterSpacing: _estiloTexto == _TextStyle.display ? 3 : 0.5, height: 1.35,
                  shadows: const [
                    Shadow(color: Colors.black87, blurRadius: 12, offset: Offset(0, 2)),
                    Shadow(color: Colors.black54, blurRadius: 24),
                  ])))))),
          // Emoji centralizado (modo emoji)
          if (_modoAtual == _StoryMode.emoji && _emojiSelecionado != null)
            Positioned.fill(child: IgnorePointer(child: Center(
              child: Text(_emojiSelecionado!,
                style: const TextStyle(fontSize: 160,
                  shadows: [Shadow(color: Colors.black38, blurRadius: 8)]))))),
          // Overlays arrastáveis
          ..._overlays.asMap().entries.map((e) =>
              _buildOverlayWidget(e.key, e.value, sw, sh)),
          _neonLine(),
          if (_publicando) _buildPublishOverlay(),
          SafeArea(child: AnimatedBuilder(
            animation: _toolbarAnim,
            builder: (_, child) => Opacity(opacity: _toolbarAnim.value,
              child: Transform.translate(
                offset: Offset(0, -8 * (1 - _toolbarAnim.value)), child: child!)),
            child: Column(children: [
              _buildTopBarEdicao(),
              Expanded(child: _buildEdicaoMiddle()),
              _buildBottomEdicao(),
              const SizedBox(height: 20),
            ]),
          )),
        ]),
      );
    });
  }

  Widget _buildEdicaoPreview() {
    switch (_modoAtual) {
      case _StoryMode.camera:
        if (_midia != null)
          return Container(color: Colors.black, child: LayoutBuilder(builder: (ctx, constraints) {
            final px = _ajusteOffset.dx * constraints.maxWidth;
            final py = _ajusteOffset.dy * constraints.maxHeight;
            return ClipRect(child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..translate(px, py)
                ..rotateZ(_ajusteRotation)
                ..scale(_ajusteScale),
              child: Image.file(_midia!, fit: BoxFit.contain,
                width: double.infinity, height: double.infinity)));
          }));
        return Container(color: Colors.black);

      case _StoryMode.video:
        if (_videoCtrl != null && _videoCtrl!.value.isInitialized) {
          return GestureDetector(
            onTap: _toggleVideoPlay,
            child: Container(color: Colors.black, child: Stack(
              alignment: Alignment.center, children: [
                SizedBox.expand(child: FittedBox(fit: BoxFit.cover,
                  child: SizedBox(
                    width:  _videoCtrl!.value.size.width,
                    height: _videoCtrl!.value.size.height,
                    child:  VideoPlayer(_videoCtrl!)))),
                // Play overlay
                AnimatedOpacity(
                  opacity: _videoPlaying ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(width: 60, height: 60,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.5),
                      border: Border.all(color: TabuColors.rosaPrincipal, width: 1.5)),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32))),
                // Progress bar
                Positioned(bottom: 0, left: 0, right: 0,
                  child: _StoryVideoProgressBar(controller: _videoCtrl!)),
                // Duration badge
                Positioned(bottom: 8, left: 10, child: _buildVideoDuracaoBadge()),
              ])));
        }
        return Container(color: Colors.black);

      case _StoryMode.texto:
        final colors = _fundoGradients[_fundoSelecionado]!;
        return Container(
          decoration: BoxDecoration(gradient: LinearGradient(
            colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
          child: CustomPaint(painter: _ParticlePainter(color: Colors.white, seed: 42, count: 60)));

      case _StoryMode.emoji:
        return Container(
          decoration: const BoxDecoration(gradient: LinearGradient(
            colors: [Color(0xFF0D0010), Color(0xFF1A0020)],
            begin: Alignment.topLeft, end: Alignment.bottomRight)),
          child: CustomPaint(painter: _ParticlePainter(color: Colors.white, seed: 99, count: 40)));
    }
  }

  Widget _buildVideoDuracaoBadge() {
    if (_videoDuration == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        border: Border.all(color: TabuColors.rosaPrincipal.withOpacity(0.5), width: 0.8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.videocam_outlined, size: 11, color: TabuColors.rosaPrincipal),
        const SizedBox(width: 4),
        Text('${_videoDuration!.inSeconds}s',
          style: const TextStyle(fontFamily: TabuTypography.bodyFont,
            fontSize: 10, fontWeight: FontWeight.w700,
            letterSpacing: 1, color: TabuColors.branco)),
      ]));
  }

  Widget _buildPublishOverlay() {
    final label = switch (_publishStep) {
      _PublishStep.uploadingMedia => 'ENVIANDO VÍDEO...',
      _PublishStep.salvando       => 'PUBLICANDO...',
      _                           => 'AGUARDE...',
    };
    return Positioned.fill(child: Container(
      color: Colors.black.withOpacity(0.60),
      child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 72, height: 72, child: Stack(alignment: Alignment.center, children: [
          CircularProgressIndicator(
            value: _publishStep == _PublishStep.uploadingMedia ? _uploadProgress : null,
            color: TabuColors.rosaPrincipal,
            backgroundColor: Colors.white.withOpacity(0.1), strokeWidth: 3),
          if (_publishStep == _PublishStep.uploadingMedia)
            Text('${(_uploadProgress * 100).toInt()}%', style: const TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
        ])),
        const SizedBox(height: 20),
        Text(label, style: const TextStyle(fontFamily: TabuTypography.bodyFont,
          fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2.5, color: Colors.white)),
      ]))));
  }

  Widget _buildOverlayWidget(int index, _Overlay ov, double sw, double sh) {
    final isAtivo = _overlayAtivo == index;
    const halfText = 80.0;
    const halfEmoji = 32.0;
    final halfW = ov.isEmoji ? halfEmoji : halfText;
    final halfH = ov.isEmoji ? halfEmoji : 22.0;

    return Positioned(
      left: ov.dx - halfW, top: ov.dy - halfH,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() { _overlayAtivo = isAtivo ? null : index; _toolTextOpen = false; _toolEmojiOpen = false; });
          HapticFeedback.selectionClick();
        },
        onPanStart: (_) => setState(() => _overlayAtivo = index),
        onPanUpdate: (d) => setState(() {
          ov.dx = (ov.dx + d.delta.dx).clamp(24.0, sw - 24.0);
          ov.dy = (ov.dy + d.delta.dy).clamp(24.0, sh - 24.0);
        }),
        child: AnimatedContainer(duration: const Duration(milliseconds: 120),
          padding: ov.isEmoji
              ? const EdgeInsets.all(4)
              : const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: ov.isEmoji ? Colors.transparent : Colors.black.withOpacity(isAtivo ? 0.65 : 0.45),
            borderRadius: BorderRadius.circular(6),
            border: isAtivo
                ? Border.all(color: TabuColors.rosaPrincipal, width: 1.8)
                : (ov.isEmoji ? null : Border.all(color: Colors.white.withOpacity(0.1), width: 0.5))),
          child: Stack(clipBehavior: Clip.none, children: [
            ov.isEmoji
                ? Text(ov.conteudo, style: TextStyle(fontSize: 56 * ov.scale,
                    shadows: const [Shadow(color: Colors.black38, blurRadius: 4)]))
                : Text(ov.conteudo, style: const TextStyle(fontFamily: TabuTypography.bodyFont,
                    fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5,
                    shadows: [Shadow(color: Colors.black, blurRadius: 10)])),
            if (isAtivo)
              Positioned(top: -14, right: -14, child: GestureDetector(
                onTap: () => _removerOverlay(index),
                child: Container(width: 24, height: 24,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFE85D5D),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 4)]),
                  child: const Icon(Icons.close, color: Colors.white, size: 13)))),
          ]))));
  }

  Widget _buildTopBarEdicao() {
    return Padding(padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(children: [
        _IconBtn(icon: Icons.arrow_back_ios_new, onTap: _publicando ? () {} : _voltarCaptura),
        const Spacer(),
        if (!_publicando) Row(children: [
          _ToolBtn(icon: Icons.text_fields_rounded, label: 'Aa', active: _toolTextOpen,
            onTap: () {
              setState(() { _toolTextOpen = !_toolTextOpen; _toolEmojiOpen = false; _overlayAtivo = null; });
              if (_toolTextOpen)
                Future.delayed(const Duration(milliseconds: 80),
                  () => FocusScope.of(context).requestFocus(_textFocus));
            }),
          const SizedBox(width: 8),
          _ToolBtn(icon: Icons.emoji_emotions_outlined, active: _toolEmojiOpen,
            onTap: () => setState(() {
              _toolEmojiOpen = !_toolEmojiOpen; _toolTextOpen = false; _overlayAtivo = null;
              FocusScope.of(context).unfocus();
            })),
        ]),
      ]));
  }

  Widget _buildEdicaoMiddle() {
    if (_publicando) return const SizedBox.shrink();
    if (_toolTextOpen) return _buildPainelTexto();
    if (_toolEmojiOpen) return _buildPainelEmoji();
    if (_overlays.isEmpty && _textoCentral.isEmpty && _emojiSelecionado == null) {
      return Center(child: Text('Toque em Aa ou 😊 para adicionar elementos',
        style: TextStyle(fontFamily: TabuTypography.bodyFont,
          fontSize: 11, color: Colors.white.withOpacity(0.25), letterSpacing: 1)));
    }
    return const SizedBox.shrink();
  }

  Widget _buildPainelTexto() {
    return GestureDetector(onTap: () {},
      child: Center(child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 28),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.70),
          border: Border.all(color: TabuColors.rosaPrincipal.withOpacity(0.5), width: 1)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.center,
            children: _TextStyle.values.map((s) {
              final sel = _estiloTexto == s;
              return GestureDetector(
                onTap: () => setState(() => _estiloTexto = s),
                child: AnimatedContainer(duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: sel ? TabuColors.rosaPrincipal.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                    border: Border.all(
                      color: sel ? TabuColors.rosaPrincipal : Colors.white.withOpacity(0.15),
                      width: sel ? 1.2 : 0.5)),
                  child: Text(s.label, style: TextStyle(
                    fontFamily: s == _TextStyle.display ? TabuTypography.displayFont : TabuTypography.bodyFont,
                    fontSize: 8, fontWeight: FontWeight.w700,
                    letterSpacing: s == _TextStyle.display ? 2 : 1.5,
                    color: sel ? TabuColors.rosaPrincipal : Colors.white.withOpacity(0.6)))));
            }).toList()),
          const SizedBox(height: 12),
          TextField(
            controller: _textCtrl, focusNode: _textFocus,
            maxLines: 3, maxLength: 120,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            style: TextStyle(
              fontFamily: _estiloTexto == _TextStyle.display
                  ? TabuTypography.displayFont : TabuTypography.bodyFont,
              fontSize: 18,
              color: _estiloTexto == _TextStyle.branco ? Colors.white
                  : _estiloTexto == _TextStyle.rosa ? TabuColors.rosaClaro : Colors.black,
              fontWeight: FontWeight.w700,
              letterSpacing: _estiloTexto == _TextStyle.display ? 2 : 0.3),
            decoration: InputDecoration(
              hintText: 'Digite aqui...',
              hintStyle: TextStyle(fontFamily: TabuTypography.bodyFont,
                fontSize: 16, color: Colors.white.withOpacity(0.3)),
              border: InputBorder.none, counterText: '', contentPadding: EdgeInsets.zero)),
          const SizedBox(height: 12),
          GestureDetector(onTap: _confirmarTexto,
            child: AnimatedContainer(duration: const Duration(milliseconds: 200),
              width: double.infinity, height: 44,
              decoration: BoxDecoration(
                color: _textCtrl.text.trim().isNotEmpty
                    ? TabuColors.rosaPrincipal : TabuColors.rosaPrincipal.withOpacity(0.25),
                border: Border.all(color: TabuColors.rosaPrincipal, width: 0.8)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                Icon(Icons.add_rounded, color: Colors.white, size: 16), SizedBox(width: 6),
                Text('ADICIONAR AO STORY', style: TextStyle(fontFamily: TabuTypography.bodyFont,
                  fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2.5, color: Colors.white)),
              ]))),
        ]))));
  }

  Widget _buildPainelEmoji() {
    return Center(child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 28),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.70),
        border: Border.all(color: TabuColors.rosaPrincipal.withOpacity(0.3), width: 0.8)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('TOQUE PARA ADICIONAR', style: TextStyle(fontFamily: TabuTypography.bodyFont,
            fontSize: 8, fontWeight: FontWeight.w700,
            letterSpacing: 2, color: Colors.white.withOpacity(0.4))),
          GestureDetector(onTap: () => setState(() => _toolEmojiOpen = false),
            child: Icon(Icons.close, color: Colors.white.withOpacity(0.4), size: 16)),
        ]),
        const SizedBox(height: 10),
        GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1),
          itemCount: _emojis.length,
          itemBuilder: (_, i) => GestureDetector(
            onTap: () => _adicionarEmojiOverlay(_emojis[i]),
            child: Container(
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5)),
              child: Center(child: Text(_emojis[i], style: const TextStyle(fontSize: 28)))))),
      ])));
  }

  Widget _buildBottomEdicao() {
    return Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _VisibBtn(label: 'PÚBLICO',     icon: Icons.public_rounded,          value: 'publico',     current: _visibilidade, onTap: () => setState(() => _visibilidade = 'publico')),
          const SizedBox(width: 8),
          _VisibBtn(label: 'SEGUIDORES',  icon: Icons.people_outline_rounded,  value: 'seguidores',  current: _visibilidade, onTap: () => setState(() => _visibilidade = 'seguidores')),
          const SizedBox(width: 8),
          _VisibBtn(label: 'VIP',         icon: Icons.star_border_rounded,     value: 'vip',         current: _visibilidade, onTap: () => setState(() => _visibilidade = 'vip')),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          GestureDetector(onTap: _publicando ? null : _voltarCaptura,
            child: AnimatedContainer(duration: const Duration(milliseconds: 200),
              height: 52, width: 52,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(_publicando ? 0.05 : 0.1),
                border: Border.all(color: Colors.white.withOpacity(_publicando ? 0.1 : 0.25), width: 0.8)),
              child: Icon(Icons.refresh_rounded,
                color: Colors.white.withOpacity(_publicando ? 0.3 : 1.0), size: 20))),
          const SizedBox(width: 12),
          Expanded(child: GestureDetector(
            onTap: _publicando ? null : _publicar,
            child: AnimatedContainer(duration: const Duration(milliseconds: 200), height: 52,
              decoration: BoxDecoration(
                color: _publishStep == _PublishStep.erro ? const Color(0xFFE85D5D) : TabuColors.rosaPrincipal,
                border: Border.all(color: TabuColors.rosaPrincipal, width: 1),
                boxShadow: _publicando ? null : [BoxShadow(color: TabuColors.glow.withOpacity(0.5), blurRadius: 20, spreadRadius: 2)]),
              child: Center(child: _publicando
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : _publishStep == _PublishStep.erro
                  ? Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                      Icon(Icons.error_outline_rounded, color: Colors.white, size: 14), SizedBox(width: 5),
                      Text('TENTAR NOVAMENTE', style: TextStyle(fontFamily: TabuTypography.bodyFont,
                        fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2, color: Colors.white)),
                    ])
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                      Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 14), SizedBox(width: 5),
                      Text('PUBLICAR STORY', style: TextStyle(fontFamily: TabuTypography.bodyFont,
                        fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2.5, color: Colors.white)),
                    ])))),
          ),
          const SizedBox(width: 12),
          GestureDetector(onTap: _publicando ? null : () => _snack('Enviar para amigos — em breve!'),
            child: Container(height: 52, width: 52,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(_publicando ? 0.05 : 0.1),
                border: Border.all(color: Colors.white.withOpacity(_publicando ? 0.1 : 0.25), width: 0.8)),
              child: Icon(Icons.send_rounded,
                color: Colors.white.withOpacity(_publicando ? 0.3 : 1.0), size: 20))),
        ]),
      ]));
  }

  Widget _neonLine() => Positioned(top: 0, left: 0, right: 0,
    child: Container(height: 2, decoration: const BoxDecoration(
      gradient: LinearGradient(colors: [
        TabuColors.rosaDeep, TabuColors.rosaPrincipal, TabuColors.rosaClaro,
        TabuColors.rosaPrincipal, TabuColors.rosaDeep]))));

  Widget _storyLabel() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(color: Colors.black.withOpacity(0.4),
      border: Border.all(color: Colors.white.withOpacity(0.15), width: 0.5)),
    child: const Text('STORY', style: TextStyle(fontFamily: TabuTypography.displayFont,
      fontSize: 14, letterSpacing: 5, color: TabuColors.branco)));
}

// ══════════════════════════════════════════════════════════════════════════════
//  WIDGET — BARRA DE PROGRESSO DO VÍDEO (story)
// ══════════════════════════════════════════════════════════════════════════════
class _StoryVideoProgressBar extends StatefulWidget {
  final VideoPlayerController controller;
  const _StoryVideoProgressBar({required this.controller});
  @override
  State<_StoryVideoProgressBar> createState() => _StoryVideoProgressBarState();
}
class _StoryVideoProgressBarState extends State<_StoryVideoProgressBar> {
  @override
  void initState() { super.initState(); widget.controller.addListener(_u); }
  @override
  void dispose() { widget.controller.removeListener(_u); super.dispose(); }
  void _u() { if (mounted) setState(() {}); }

  @override
  Widget build(BuildContext context) {
    final pos   = widget.controller.value.position.inMilliseconds.toDouble();
    final total = widget.controller.value.duration.inMilliseconds.toDouble();
    final pct   = total > 0 ? (pos / total).clamp(0.0, 1.0) : 0.0;
    return Container(height: 3, color: Colors.white.withOpacity(0.15),
      child: FractionallySizedBox(widthFactor: pct, alignment: Alignment.centerLeft,
        child: Container(decoration: const BoxDecoration(gradient: LinearGradient(
          colors: [TabuColors.rosaDeep, TabuColors.rosaPrincipal])))));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  WIDGET — CARD DE PERMISSÃO
// ══════════════════════════════════════════════════════════════════════════════
class _PermissaoCard extends StatelessWidget {
  final IconData icon; final String titulo; final String descricao;
  final _PermissaoStatus status;
  const _PermissaoCard({required this.icon, required this.titulo,
    required this.descricao, required this.status});

  Color get _cor => switch(status) {
    _PermissaoStatus.concedido          => const Color(0xFF4CAF50),
    _PermissaoStatus.negadoPermanente   => const Color(0xFFE85D5D),
    _PermissaoStatus.verificando        => Colors.white24,
    _PermissaoStatus.pendente           => Colors.white38,
  };
  IconData get _ic => switch(status) {
    _PermissaoStatus.concedido          => Icons.check_circle_rounded,
    _PermissaoStatus.negadoPermanente   => Icons.cancel_rounded,
    _PermissaoStatus.verificando        => Icons.hourglass_empty_rounded,
    _PermissaoStatus.pendente           => Icons.radio_button_unchecked_rounded,
  };
  String get _lb => switch(status) {
    _PermissaoStatus.concedido          => 'CONCEDIDO',
    _PermissaoStatus.negadoPermanente   => 'BLOQUEADO',
    _PermissaoStatus.verificando        => 'VERIFICANDO',
    _PermissaoStatus.pendente           => 'PENDENTE',
  };

  @override
  Widget build(BuildContext context) {
    final ok = status == _PermissaoStatus.concedido;
    return AnimatedContainer(duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: ok ? const Color(0xFF4CAF50).withOpacity(0.07) : Colors.white.withOpacity(0.04),
        border: Border.all(color: _cor.withOpacity(ok ? 0.4 : 0.15), width: ok ? 1 : 0.5)),
      child: Row(children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(color: _cor.withOpacity(0.1),
            border: Border.all(color: _cor.withOpacity(0.3), width: 0.8)),
          child: Icon(icon, color: _cor, size: 20)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo, style: TextStyle(fontFamily: TabuTypography.bodyFont,
            fontSize: 11, fontWeight: FontWeight.w700,
            letterSpacing: 2, color: Colors.white.withOpacity(0.9))),
          const SizedBox(height: 3),
          Text(descricao, style: TextStyle(fontFamily: TabuTypography.bodyFont,
            fontSize: 10, letterSpacing: 0.3, color: Colors.white.withOpacity(0.4))),
        ])),
        const SizedBox(width: 10),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(_ic, color: _cor, size: 14), const SizedBox(width: 4),
          Text(_lb, style: TextStyle(fontFamily: TabuTypography.bodyFont,
            fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: _cor)),
        ]),
      ]));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ENUMS
// ══════════════════════════════════════════════════════════════════════════════
class _VisibBtn extends StatelessWidget {
  final String label, value, current;
  final IconData icon;
  final VoidCallback onTap;
  const _VisibBtn({required this.label, required this.icon,
    required this.value, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = value == current;
    return GestureDetector(onTap: onTap,
      child: AnimatedContainer(duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? (value == 'vip' ? const Color(0xFF1A0A00) : Colors.white.withOpacity(0.15))
              : Colors.black.withOpacity(0.3),
          border: Border.all(
            color: active
                ? (value == 'vip' ? const Color(0xFFD4AF37) : Colors.white.withOpacity(0.7))
                : Colors.white.withOpacity(0.2),
            width: active ? 1 : 0.6)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11,
            color: active ? (value == 'vip' ? const Color(0xFFD4AF37) : Colors.white) : Colors.white.withOpacity(0.4)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontFamily: TabuTypography.bodyFont,
            fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.5,
            color: active ? (value == 'vip' ? const Color(0xFFD4AF37) : Colors.white) : Colors.white.withOpacity(0.4))),
        ])));
  }
}

enum _StoryMode {
  camera (Icons.photo_camera_outlined,     'CÂMERA'),
  texto  (Icons.text_fields_rounded,       'TEXTO'),
  emoji  (Icons.emoji_emotions_outlined,   'EMOJI'),
  video  (Icons.videocam_outlined,         'VÍDEO');

  final IconData icon;
  final String   label;
  const _StoryMode(this.icon, this.label);
}

enum _StoryStep { captura, edicao }

enum _TextStyle {
  branco('BRANCO'), rosa('ROSA'), display('DISPLAY');
  final String label;
  const _TextStyle(this.label);
}

enum _Fundo { escuro, rosaFogo, roxo, ouro, azulNoite, verde }

class _IconBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap; final bool active;
  const _IconBtn({required this.icon, required this.onTap, this.active = false});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Container(width: 40, height: 40,
      decoration: BoxDecoration(shape: BoxShape.circle,
        color: active ? TabuColors.rosaPrincipal.withOpacity(0.3) : Colors.black.withOpacity(0.45),
        border: Border.all(
          color: active ? TabuColors.rosaPrincipal : Colors.white.withOpacity(0.2),
          width: active ? 1.2 : 0.5)),
      child: Icon(icon, color: active ? TabuColors.rosaClaro : Colors.white, size: 18)));
}

class _ToolBtn extends StatelessWidget {
  final IconData icon; final String? label; final VoidCallback onTap; final bool active;
  const _ToolBtn({required this.icon, required this.onTap, this.label, this.active = false});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: AnimatedContainer(duration: const Duration(milliseconds: 160),
      width: 42, height: 42,
      decoration: BoxDecoration(
        color: active ? TabuColors.rosaPrincipal.withOpacity(0.25) : Colors.black.withOpacity(0.5),
        border: Border.all(
          color: active ? TabuColors.rosaPrincipal : Colors.white.withOpacity(0.2),
          width: active ? 1.5 : 0.5),
        boxShadow: active ? [BoxShadow(color: TabuColors.glow.withOpacity(0.35), blurRadius: 10)] : null),
      child: label != null
          ? Center(child: Text(label!, style: TextStyle(fontFamily: TabuTypography.bodyFont,
              fontSize: 13, fontWeight: FontWeight.w700,
              color: active ? TabuColors.rosaPrincipal : Colors.white)))
          : Icon(icon, color: active ? TabuColors.rosaPrincipal : Colors.white, size: 20)));
}

class _ParticlePainter extends CustomPainter {
  final Color color; final int seed; final int count;
  const _ParticlePainter({required this.color, required this.seed, required this.count});
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);
    final p = Paint()..color = color.withOpacity(0.03);
    for (int i = 0; i < count; i++)
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        rng.nextDouble() * 2.5 + 0.5, p);
  }
  @override
  bool shouldRepaint(_ParticlePainter o) => false;
}

// ══════════════════════════════════════════════════════════════════════════════
//  TELA DE AJUSTE DE IMAGEM (inalterada)
// ══════════════════════════════════════════════════════════════════════════════
class _AdjustResult {
  final File file; final double scale; final double rotation;
  final double offsetXNorm; final double offsetYNorm;
  const _AdjustResult({required this.file, required this.scale, required this.rotation,
    required this.offsetXNorm, required this.offsetYNorm});
}

class _ImageAdjustScreen extends StatefulWidget {
  final File imageFile;
  const _ImageAdjustScreen({required this.imageFile});
  @override
  State<_ImageAdjustScreen> createState() => _ImageAdjustScreenState();
}

class _ImageAdjustScreenState extends State<_ImageAdjustScreen>
    with SingleTickerProviderStateMixin {

  double _scale = 1.0, _rotation = 0.0;
  Offset _offset = Offset.zero;
  double _baseScale = 1.0, _baseRotation = 0.0;
  Offset _baseOffset = Offset.zero;
  static const double _minScale = 0.5, _maxScale = 6.0;
  bool _mostrarGrade = false;

  late AnimationController _entradaCtrl;
  late Animation<double>   _entradaAnim;

  @override
  void initState() {
    super.initState();
    _entradaCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _entradaAnim = CurvedAnimation(parent: _entradaCtrl, curve: Curves.easeOutCubic);
    _entradaCtrl.forward();
  }
  @override
  void dispose() { _entradaCtrl.dispose(); super.dispose(); }

  void _onScaleStart(ScaleStartDetails d) {
    _baseScale = _scale; _baseRotation = _rotation; _baseOffset = _offset;
    setState(() => _mostrarGrade = true);
  }
  void _onScaleUpdate(ScaleUpdateDetails d) => setState(() {
    _scale    = (_baseScale * d.scale).clamp(_minScale, _maxScale);
    _rotation = _baseRotation + d.rotation;
    _offset   = _baseOffset + d.focalPointDelta;
  });
  void _onScaleEnd(ScaleEndDetails _) => setState(() => _mostrarGrade = false);

  void _resetar() {
    setState(() { _scale = 1.0; _rotation = 0.0; _offset = Offset.zero; });
    HapticFeedback.selectionClick();
  }

  void _confirmar() {
    HapticFeedback.mediumImpact();
    final size  = MediaQuery.of(context).size;
    double frameW = size.width;
    double frameH = frameW * 16 / 9;
    final maxH = size.height - MediaQuery.of(context).padding.top
                             - MediaQuery.of(context).padding.bottom - 52 - 80;
    if (frameH > maxH) { frameH = maxH; frameW = frameH * 9 / 16; }
    Navigator.pop(context, _AdjustResult(
      file: widget.imageFile, scale: _scale, rotation: _rotation,
      offsetXNorm: frameW > 0 ? _offset.dx / frameW : 0,
      offsetYNorm: frameH > 0 ? _offset.dy / frameH : 0));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(backgroundColor: Colors.black,
        body: FadeTransition(opacity: _entradaAnim,
          child: SafeArea(child: Column(children: [
            Container(height: 52, padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(
                color: Colors.white.withOpacity(0.08), width: 0.5))),
              child: Row(children: [
                GestureDetector(onTap: () => Navigator.pop(context),
                  child: Container(width: 36, height: 36,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.08),
                      border: Border.all(color: Colors.white.withOpacity(0.15), width: 0.5)),
                    child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 15))),
                const SizedBox(width: 12),
                const Text('AJUSTAR IMAGEM', style: TextStyle(fontFamily: TabuTypography.displayFont,
                  fontSize: 12, letterSpacing: 2, color: Colors.white)),
                const Spacer(),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.12), width: 0.5)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.zoom_in_rounded, color: Colors.white60, size: 11), const SizedBox(width: 4),
                    Text('${(_scale * 100).toStringAsFixed(0)}%', style: const TextStyle(
                      fontFamily: TabuTypography.bodyFont, fontSize: 10,
                      fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5)),
                    const SizedBox(width: 8),
                    const Icon(Icons.rotate_right_rounded, color: Colors.white60, size: 11), const SizedBox(width: 4),
                    Text('${(_rotation * 180 / math.pi).toStringAsFixed(1)}°', style: const TextStyle(
                      fontFamily: TabuTypography.bodyFont, fontSize: 10,
                      fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5)),
                  ])),
              ])),
            Expanded(child: LayoutBuilder(builder: (ctx, constraints) {
              final maxW = constraints.maxWidth, maxH = constraints.maxHeight;
              double frameW = maxW, frameH = frameW * 16 / 9;
              if (frameH > maxH) { frameH = maxH; frameW = frameH * 9 / 16; }
              return Stack(alignment: Alignment.center, children: [
                Container(color: Colors.black),
                SizedBox(width: frameW, height: frameH, child: Stack(fit: StackFit.expand, children: [
                  CustomPaint(painter: _CheckerPainter()),
                  ClipRect(child: GestureDetector(
                    onScaleStart: _onScaleStart, onScaleUpdate: _onScaleUpdate, onScaleEnd: _onScaleEnd,
                    child: Transform(alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..translate(_offset.dx, _offset.dy)
                        ..rotateZ(_rotation)
                        ..scale(_scale),
                      child: Image.file(widget.imageFile, fit: BoxFit.cover, width: frameW, height: frameH)))),
                  if (_mostrarGrade) IgnorePointer(child: CustomPaint(painter: _GridPainter())),
                  IgnorePointer(child: Container(decoration: BoxDecoration(
                    border: Border.all(color: TabuColors.rosaPrincipal.withOpacity(0.4), width: 1)))),
                ])),
                if (_scale == 1.0 && _offset == Offset.zero && _rotation == 0.0)
                  Positioned(bottom: 16, child: IgnorePointer(child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.pinch_outlined, color: Colors.white54, size: 14), SizedBox(width: 8),
                      Text('Pinch · Arraste · 2 dedos p/ girar', style: TextStyle(
                        fontFamily: TabuTypography.bodyFont, fontSize: 10, letterSpacing: 0.3, color: Colors.white54)),
                    ])))),
              ]);
            })),
            Container(padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(color: Colors.black, border: Border(top: BorderSide(
                color: Colors.white.withOpacity(0.08), width: 0.5))),
              child: Row(children: [
                GestureDetector(onTap: _resetar,
                  child: Container(height: 50, width: 110,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.07),
                      border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.8)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                      Icon(Icons.refresh_rounded, color: Colors.white70, size: 15), SizedBox(width: 6),
                      Text('RESETAR', style: TextStyle(fontFamily: TabuTypography.bodyFont,
                        fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2, color: Colors.white70)),
                    ]))),
                const SizedBox(width: 12),
                Expanded(child: GestureDetector(onTap: _confirmar,
                  child: Container(height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [TabuColors.rosaDeep, TabuColors.rosaPrincipal],
                        begin: Alignment.centerLeft, end: Alignment.centerRight),
                      border: Border.all(color: TabuColors.rosaPrincipal, width: 1),
                      boxShadow: [BoxShadow(color: TabuColors.glow.withOpacity(0.45), blurRadius: 16, spreadRadius: 1)]),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                      Icon(Icons.check_rounded, color: Colors.white, size: 16), SizedBox(width: 8),
                      Text('USAR IMAGEM', style: TextStyle(fontFamily: TabuTypography.bodyFont,
                        fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 2.5, color: Colors.white)),
                    ])))),
              ])),
          ])))));
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withOpacity(0.20)..strokeWidth = 0.7;
    canvas.drawLine(Offset(size.width / 3, 0), Offset(size.width / 3, size.height), p);
    canvas.drawLine(Offset(size.width * 2 / 3, 0), Offset(size.width * 2 / 3, size.height), p);
    canvas.drawLine(Offset(0, size.height / 3), Offset(size.width, size.height / 3), p);
    canvas.drawLine(Offset(0, size.height * 2 / 3), Offset(size.width, size.height * 2 / 3), p);
  }
  @override
  bool shouldRepaint(_GridPainter o) => false;
}

class _CheckerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const sq = 18.0;
    final dark = Paint()..color = const Color(0xFF1C1C1C);
    final lite = Paint()..color = const Color(0xFF262626);
    final cols = (size.width  / sq).ceil();
    final rows = (size.height / sq).ceil();
    for (int r = 0; r < rows; r++)
      for (int c = 0; c < cols; c++)
        canvas.drawRect(Rect.fromLTWH(c * sq, r * sq, sq, sq),
          (r + c) % 2 == 0 ? dark : lite);
  }
  @override
  bool shouldRepaint(_CheckerPainter o) => false;
}