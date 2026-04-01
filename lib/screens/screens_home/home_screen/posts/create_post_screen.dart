// lib/screens/screens_home/home_screen/posts/create_post_screen.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/services/services_app/post_service.dart';
import 'package:tabuapp/services/services_app/video_compress_service.dart';
import 'package:tabuapp/services/services_app/watermark_service.dart';
import 'package:tabuapp/services/services_app/video_watermark_service.dart'; // PATCH 1

class CreatePostScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const CreatePostScreen({super.key, required this.userData});

  @override
  State<CreatePostScreen> createState() => _CriarPostScreenState();
}

// PATCH 2 — enum com novo step marcandoVideo
enum _PublishStep {
  idle, aplicandoMarca, comprimindoVideo, marcandoVideo, uploadingMedia, uploadingThumb, salvando, concluido, erro,
}

class _CriarPostScreenState extends State<CreatePostScreen>
    with SingleTickerProviderStateMixin {

  final _tituloCtrl  = TextEditingController();
  final _descCtrl    = TextEditingController();
  final _tituloFocus = FocusNode();
  final _descFocus   = FocusNode();
  final _picker      = ImagePicker();

  late TabController _tabController;

  File?   _foto;
  String? _emojiSelecionado;

  int _videoSessionId = 0;
  File?                  _video;
  File?                  _videoComprimido;
  Uint8List?             _thumbBytes;
  File?                  _thumbFile;
  VideoPlayerController? _videoCtrl;
  Duration?              _videoDuration;
  bool                   _videoPlaying    = false;
  bool                   _capaPersonalizada = false;

  String? _videoTamanhoOriginal;
  String? _videoTamanhoComprimido;

  _Visibilidade  _visibilidade     = _Visibilidade.publico;
  _PublishStep   _publishStep      = _PublishStep.idle;
  double         _uploadProgress   = 0.0;
  double         _compressProgress = 0.0;

  static const int _maxVideoSeconds = 30;

  bool get _publicando =>
      _publishStep != _PublishStep.idle &&
      _publishStep != _PublishStep.concluido &&
      _publishStep != _PublishStep.erro;

  static const _emojiGroups = {
    'FESTA': ['🔥','🎉','🥂','🍾','💃','🕺','🎶','🎵','🎊','✨','🪩','🎸'],
    'VIBE':  ['😈','🤩','😍','🥵','💋','👑','💎','🖤','❤️','💜','🩷','⚡'],
    'BAR':   ['🍸','🍹','🥃','🍺','🍻','🧉','🥤','🫗','🍷','🍾','🫧','🧊'],
    'NOITE': ['🌙','🌃','🌆','⭐','🌟','💫','🌠','🎆','🎇','🪐','🌌','🌛'],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descCtrl.dispose();
    _tituloFocus.dispose();
    _descFocus.dispose();
    _tabController.dispose();
    _videoCtrl?.dispose();
    super.dispose();
  }

  bool get _podePublicar {
    if (_publicando) return false;
    if (_tituloCtrl.text.trim().isEmpty) return false;
    final tab = _tabController.index;
    if (tab == 0) return _foto != null;
    if (tab == 1) return _descCtrl.text.trim().isNotEmpty;
    if (tab == 2) return _emojiSelecionado != null;
    if (tab == 3) return _video != null && _videoDuracaoValida;
    return false;
  }

  bool get _videoDuracaoValida {
    if (_videoDuration == null) return false;
    return _videoDuration!.inSeconds <= _maxVideoSeconds && _videoDuration!.inSeconds > 0;
  }

  String get _tipoAtual {
    switch (_tabController.index) {
      case 0:  return 'foto';
      case 1:  return 'texto';
      case 2:  return 'emoji';
      case 3:  return 'video';
      default: return 'texto';
    }
  }

  String get _userName => (widget.userData['name'] as String? ?? 'usuário').toUpperCase();

  // ── FOTO ──────────────────────────────────────────────────────────────────
  Future<void> _pickFoto(ImageSource src) async {
    Navigator.pop(context);
    final p = await _picker.pickImage(source: src, maxWidth: 1080, maxHeight: 1080, imageQuality: 85);
    if (p == null) return;
    setState(() => _foto = File(p.path));
  }

  // ── VÍDEO ─────────────────────────────────────────────────────────────────
  Future<void> _pickVideo(ImageSource src) async {
    Navigator.pop(context);
    final p = await _picker.pickVideo(source: src, maxDuration: const Duration(seconds: _maxVideoSeconds));
    if (p == null) return;
    await _carregarVideo(File(p.path));
  }

  Future<void> _carregarVideo(File file) async {
    await VideoCompressService.instance.cancelCompression();
    await _videoCtrl?.dispose();
    final int mySession = ++_videoSessionId;

    setState(() {
      _video = null; _videoComprimido = null; _thumbBytes = null; _thumbFile = null;
      _videoTamanhoOriginal = null; _videoTamanhoComprimido = null;
      _videoPlaying = false; _capaPersonalizada = false; _compressProgress = 0.0; _videoCtrl = null;
    });

    final tmpCtrl = VideoPlayerController.file(file);
    await tmpCtrl.initialize();
    final dur = tmpCtrl.value.duration;
    await tmpCtrl.dispose();

    if (dur.inSeconds > _maxVideoSeconds) { if (mounted) _snack('Vídeo muito longo. Máximo: $_maxVideoSeconds segundos.'); return; }
    if (dur.inSeconds == 0) { if (mounted) _snack('Vídeo inválido ou corrompido.'); return; }
    if (_videoSessionId != mySession) return;

    final ctrl = VideoPlayerController.file(file);
    await ctrl.initialize();
    ctrl.addListener(() { if (mounted) setState(() => _videoPlaying = ctrl.value.isPlaying); });

    if (!mounted || _videoSessionId != mySession) { ctrl.dispose(); return; }

    setState(() {
      _video = file; _videoCtrl = ctrl; _videoDuration = dur;
      _videoTamanhoOriginal = VideoCompressService.fileSizeMB(file);
    });

    final File snap = file;
    _comprimirVideoBackground(snap, mySession);
    _gerarThumbnailPrimeiroFrame(snap, mySession);
  }

  Future<void> _comprimirVideoBackground(File original, int mySession) async {
    final comprimido = await VideoCompressService.instance.compress(
      original, quality: VideoQuality.MediumQuality,
      onProgress: (p) { if (mounted && _videoSessionId == mySession) setState(() => _compressProgress = p); },
    );
    if (!mounted || _videoSessionId != mySession) return;
    setState(() {
      _videoComprimido = comprimido;
      _videoTamanhoComprimido = comprimido != null ? VideoCompressService.fileSizeMB(comprimido) : null;
      _compressProgress = 1.0;
    });
  }

  Future<void> _gerarThumbnailPrimeiroFrame(File videoFile, int mySession) async {
    try {
      final bytes = await VideoCompress.getByteThumbnail(videoFile.path, quality: 85, position: -1);
      if (!mounted || bytes == null || _videoSessionId != mySession || _capaPersonalizada) return;
      await _aplicarThumbBytes(bytes, mySession: mySession);
    } catch (e) {
      debugPrint('[Thumb] $e');
    }
  }

  Future<void> _aplicarThumbBytes(Uint8List bytes, {int? mySession}) async {
    final tmp  = await getTemporaryDirectory();
    final path = '${tmp.path}/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final file = await File(path).writeAsBytes(bytes);
    if (!mounted) { file.deleteSync(); return; }
    if (mySession != null && _videoSessionId != mySession) { file.deleteSync(); return; }
    final old = _thumbFile;
    setState(() { _thumbBytes = bytes; _thumbFile = file; });
    if (old != null && old.path != file.path) old.deleteSync(recursive: false);
  }

  void _toggleVideoPlay() {
    if (_videoCtrl == null) return;
    if (_videoCtrl!.value.isPlaying) {
      _videoCtrl!.pause();
    } else {
      if (_videoCtrl!.value.position >= _videoCtrl!.value.duration) _videoCtrl!.seekTo(Duration.zero);
      _videoCtrl!.play();
    }
    HapticFeedback.selectionClick();
  }

  void _removerVideo() {
    VideoCompressService.instance.cancelCompression();
    _videoCtrl?.dispose();
    _thumbFile?.deleteSync(recursive: false);
    _videoSessionId++;
    setState(() {
      _video = null; _videoComprimido = null; _thumbBytes = null; _thumbFile = null;
      _videoCtrl = null; _videoDuration = null; _videoPlaying = false;
      _videoTamanhoOriginal = null; _videoTamanhoComprimido = null;
      _compressProgress = 0.0; _capaPersonalizada = false;
    });
  }

  // ── SELETOR DE CAPA ───────────────────────────────────────────────────────
  void _abrirSeletorCapa() {
    if (_video == null || _videoCtrl == null || !_videoCtrl!.value.isInitialized) return;
    _videoCtrl!.pause();
    HapticFeedback.selectionClick();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (_) => _FramePickerSheet(
        videoCtrl:     _videoCtrl!,
        totalDuration: _videoDuration!,
        currentThumb:  _thumbBytes,
        onConfirm: (Uint8List bytes) async {
          _capaPersonalizada = true;
          final int sess = _videoSessionId;
          await _aplicarThumbBytes(bytes, mySession: sess);
          if (mounted && _videoSessionId == sess) {
            setState(() => _capaPersonalizada = true);
            HapticFeedback.mediumImpact();
            _snack('Capa definida! 🎬', success: true);
          }
        },
      ),
    );
  }

  // ── SHEETS ────────────────────────────────────────────────────────────────
  void _showFotoSheet() {
    showModalBottomSheet(
      context: context, backgroundColor: TabuColors.bgAlt, shape: const RoundedRectangleBorder(),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _sheetHandle(),
        const Text('SELECIONAR FOTO', style: TextStyle(fontFamily: TabuTypography.displayFont, fontSize: 16, letterSpacing: 5, color: TabuColors.branco)),
        const SizedBox(height: 16),
        Container(height: 0.5, color: TabuColors.border),
        _SheetTile(icon: Icons.photo_camera_outlined, label: 'CÂMERA', sublabel: 'Tirar foto agora', onTap: () => _pickFoto(ImageSource.camera)),
        Container(height: 0.5, color: TabuColors.border),
        _SheetTile(icon: Icons.photo_library_outlined, label: 'GALERIA', sublabel: 'Escolher da galeria', onTap: () => _pickFoto(ImageSource.gallery)),
        if (_foto != null) ...[
          Container(height: 0.5, color: TabuColors.border),
          _SheetTile(icon: Icons.delete_outline, label: 'REMOVER FOTO', sublabel: 'Continuar sem imagem', danger: true,
              onTap: () { Navigator.pop(context); setState(() => _foto = null); }),
        ],
        const SizedBox(height: 20),
      ])),
    );
  }

  void _showVideoSheet() {
    showModalBottomSheet(
      context: context, backgroundColor: TabuColors.bgAlt, shape: const RoundedRectangleBorder(),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _sheetHandle(),
        const Text('SELECIONAR VÍDEO', style: TextStyle(fontFamily: TabuTypography.displayFont, fontSize: 16, letterSpacing: 5, color: TabuColors.branco)),
        const SizedBox(height: 4),
        Text('máximo $_maxVideoSeconds segundos • vídeo comprimido automaticamente',
            style: const TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 9, letterSpacing: 1.5, color: TabuColors.subtle)),
        const SizedBox(height: 16),
        Container(height: 0.5, color: TabuColors.border),
        _SheetTile(icon: Icons.videocam_outlined, label: 'CÂMERA', sublabel: 'Gravar vídeo agora', onTap: () => _pickVideo(ImageSource.camera)),
        Container(height: 0.5, color: TabuColors.border),
        _SheetTile(icon: Icons.video_library_outlined, label: 'GALERIA', sublabel: 'Escolher da galeria', onTap: () => _pickVideo(ImageSource.gallery)),
        if (_video != null) ...[
          Container(height: 0.5, color: TabuColors.border),
          _SheetTile(icon: Icons.delete_outline, label: 'REMOVER VÍDEO', sublabel: 'Continuar sem vídeo', danger: true,
              onTap: () { Navigator.pop(context); _removerVideo(); }),
        ],
        const SizedBox(height: 20),
      ])),
    );
  }

  Widget _sheetHandle() => Container(width: 36, height: 3,
      margin: const EdgeInsets.only(top: 12, bottom: 20),
      decoration: BoxDecoration(color: TabuColors.border, borderRadius: BorderRadius.circular(2)));

  // ── PUBLICAR ──────────────────────────────────────────────────────────────
  Future<void> _publicar() async {
    if (!_podePublicar) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
 
    final uid = FirebaseAuth.instance.currentUser?.uid
        ?? (widget.userData['uid'] as String?)
        ?? (widget.userData['id'] as String?) ?? '';
    if (uid.isEmpty) { _snack('Erro: usuário não autenticado.'); return; }
 
    final userName   = (widget.userData['name'] as String? ?? 'Anônimo').toUpperCase();
    final userAvatar =  widget.userData['avatar'] as String?;
 
    setState(() { _publishStep = _PublishStep.uploadingMedia; _uploadProgress = 0.0; });
 
    try {
      String? mediaUrl;
      String? thumbUrl;
      int?    videoDurationSec;
 
      // ── FOTO ──────────────────────────────────────────────────────────────
      if (_tipoAtual == 'foto' && _foto != null) {
 
        setState(() => _publishStep = _PublishStep.aplicandoMarca);
 
        final originalBytes = await _foto!.readAsBytes();
        final watermarkedBytes = await WatermarkService.apply(
          imageBytes: originalBytes,
          userName:   userName,
        );
 
        final tmp   = await getTemporaryDirectory();
        final wPath = '${tmp.path}/wm_${DateTime.now().millisecondsSinceEpoch}.png';
        final wFile = await File(wPath).writeAsBytes(watermarkedBytes);
 
        setState(() { _publishStep = _PublishStep.uploadingMedia; _uploadProgress = 0.0; });
 
        final ref  = FirebaseStorage.instance.ref('posts/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg');
        final task = ref.putFile(wFile, SettableMetadata(contentType: 'image/jpeg'));
        task.snapshotEvents.listen((s) {
          if (mounted) setState(() => _uploadProgress = s.bytesTransferred / (s.totalBytes == 0 ? 1 : s.totalBytes));
        });
        await task;
        mediaUrl = await ref.getDownloadURL();
 
        wFile.deleteSync(recursive: false);
 
      // ── VÍDEO ─────────────────────────────────────────────────────────────
      } else if (_tipoAtual == 'video' && _video != null) {
        videoDurationSec = _videoDuration?.inSeconds;
 
        // Captura sessão e lê bytes da thumb AGORA, antes de qualquer await
        final int sessionAtUpload = _videoSessionId;
        final Uint8List? thumbBytesSnapshot = _thumbFile != null && await _thumbFile!.exists()
            ? await _thumbFile!.readAsBytes()
            : _thumbBytes;
 
        if (_videoComprimido == null && _compressProgress < 1.0) {
          setState(() => _publishStep = _PublishStep.comprimindoVideo);
          while (_videoComprimido == null && _compressProgress < 1.0 && mounted) {
            await Future.delayed(const Duration(milliseconds: 300));
          }
          if (!mounted) return;
          setState(() { _publishStep = _PublishStep.uploadingMedia; _uploadProgress = 0.0; });
        }
 
        // Aborta se o usuário trocou/cancelou o vídeo durante a espera
        if (_videoSessionId != sessionAtUpload) {
          debugPrint('[CreatePost] Sessão de vídeo mudou durante compressão — abortando upload.');
          setState(() => _publishStep = _PublishStep.idle);
          return;
        }

        // PATCH 3 — bloco do vídeo com watermark permanente via VideoWatermarkService
        final File videoComprimido = _videoComprimido ?? _video!;
        final ts = DateTime.now().millisecondsSinceEpoch;

        // ── Dimensões reais do vídeo (necessário para o overlay) ──────────────
        final videoSize = _videoCtrl?.value.size;
        final vw = videoSize?.width.toInt()  ?? 1280;
        final vh = videoSize?.height.toInt() ?? 720;

        // ── Aplica marca d'água permanente no vídeo ────────────────────────────
        setState(() { _publishStep = _PublishStep.marcandoVideo; _uploadProgress = 0.0; });

        final watermarkedVideo = await VideoWatermarkService.apply(
          videoFile:   videoComprimido,
          userName:    userName,
          videoWidth:  vw,
          videoHeight: vh,
          onProgress: (p) {
            if (mounted) setState(() => _uploadProgress = p);
          },
        );

        // Se falhar, faz upload do vídeo sem marca (fallback gracioso)
        final File videoParaUpload = watermarkedVideo ?? videoComprimido;
        if (watermarkedVideo == null) {
          debugPrint('[CreatePost] Watermark de vídeo falhou — fazendo upload sem marca.');
        }

        setState(() { _publishStep = _PublishStep.uploadingMedia; _uploadProgress = 0.0; });

        final videoRef  = FirebaseStorage.instance.ref('posts/$uid/videos/$ts.mp4');
        final videoTask = videoRef.putFile(videoParaUpload, SettableMetadata(contentType: 'video/mp4'));
        videoTask.snapshotEvents.listen((s) {
          if (mounted) setState(() => _uploadProgress = s.bytesTransferred / (s.totalBytes == 0 ? 1 : s.totalBytes));
        });
        await videoTask;
        mediaUrl = await videoRef.getDownloadURL();

        // Limpa o arquivo de vídeo com marca d'água (temporário)
        if (watermarkedVideo != null) {
          try { watermarkedVideo.deleteSync(); } catch (_) {}
        }

        // ── Thumbnail com marca d'água (imagem) ─────────────────────────────────
        if (thumbBytesSnapshot != null && thumbBytesSnapshot.isNotEmpty) {
          setState(() { _publishStep = _PublishStep.aplicandoMarca; _uploadProgress = 0.0; });

          final thumbWatermarked = await WatermarkService.apply(
            imageBytes: thumbBytesSnapshot,
            userName:   userName,
          );

          setState(() { _publishStep = _PublishStep.uploadingThumb; _uploadProgress = 0.0; });

          final thumbRef  = FirebaseStorage.instance.ref('posts/$uid/thumbs/$ts.jpg');
          final thumbTask = thumbRef.putFile(
            await _bytesToTempFile(thumbWatermarked, 'wm_thumb_$ts.png'),
            SettableMetadata(contentType: 'image/jpeg'),
          );
          thumbTask.snapshotEvents.listen((s) {
            if (mounted) setState(() => _uploadProgress = s.bytesTransferred / (s.totalBytes == 0 ? 1 : s.totalBytes));
          });
          await thumbTask;
          thumbUrl = await thumbRef.getDownloadURL();
        }
      }
 
      if (!mounted) return;
      setState(() => _publishStep = _PublishStep.salvando);
 
      await PostService.instance.createPost(
        userId: uid, userName: userName, userAvatar: userAvatar,
        titulo: _tituloCtrl.text.trim(),
        descricao: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        tipo: _tipoAtual, visibilidade: _visibilidade.name,
        mediaUrl: mediaUrl, thumbUrl: thumbUrl,
        emoji: _tipoAtual == 'emoji' ? _emojiSelecionado : null,
        videoDuration: videoDurationSec,
      );
 
      if (!mounted) return;
      setState(() => _publishStep = _PublishStep.concluido);
      HapticFeedback.mediumImpact();
      _snack('Post publicado! 🔥', success: true);
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('[CreatePost] $e');
      if (!mounted) return;
      setState(() => _publishStep = _PublishStep.erro);
      _snack('Erro ao publicar. Tente novamente.');
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _publishStep = _PublishStep.idle);
    }
  }

  Future<File> _bytesToTempFile(Uint8List bytes, String name) async {
    final tmp  = await getTemporaryDirectory();
    return File('${tmp.path}/$name').writeAsBytes(bytes);
  }

  void _snack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: success ? TabuColors.rosaDeep : const Color(0xFF3D0A0A),
      behavior: SnackBarBehavior.floating, shape: const RoundedRectangleBorder(),
      margin: const EdgeInsets.all(16), duration: const Duration(seconds: 3),
      content: Text(msg, style: const TextStyle(fontFamily: TabuTypography.bodyFont,
          fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: TabuColors.branco))));
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final avatarUrl = widget.userData['avatar'] as String? ?? '';
    final name      = (widget.userData['name']  as String? ?? 'Você').toUpperCase();

    return Scaffold(
      backgroundColor: TabuColors.bg,
      body: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _PostBg())),
        Positioned(top: 0, left: 0, right: 0, child: Container(height: 3,
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [
              TabuColors.rosaDeep, TabuColors.rosaPrincipal, TabuColors.rosaClaro,
              TabuColors.rosaPrincipal, TabuColors.rosaDeep])))),
        SafeArea(child: Column(children: [
          _buildTopBar(),
          Container(height: 0.5, color: TabuColors.border),
          Expanded(child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.translucent,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _buildAutor(name, avatarUrl),
                _buildCampoTitulo(),
                _buildTabs(),
                _buildTabContent(),
                Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: _buildVisibilidade()),
                const SizedBox(height: 80),
              ])))),
          _buildPublicarBtn(),
        ])),
        if (_publicando) _buildProgressOverlay(),
      ]),
    );
  }

  // PATCH 4 — _buildProgressOverlay com label do novo step marcandoVideo
  Widget _buildProgressOverlay() {
    final isCompress = _publishStep == _PublishStep.comprimindoVideo;
    final isMarca    = _publishStep == _PublishStep.aplicandoMarca;
    final isMarcaVideo = _publishStep == _PublishStep.marcandoVideo;
    final progress   = isCompress ? _compressProgress : ((isMarca || isMarcaVideo) ? null : _uploadProgress);
    final label = switch (_publishStep) {
      _PublishStep.aplicandoMarca   => 'APLICANDO MARCA D\'ÁGUA...',
      _PublishStep.comprimindoVideo => 'COMPRIMINDO VÍDEO...',
      _PublishStep.marcandoVideo    => 'GRAVANDO MARCA NO VÍDEO...',   // novo
      _PublishStep.uploadingMedia   => _tipoAtual == 'video' ? 'ENVIANDO VÍDEO...' : 'ENVIANDO FOTO...',
      _PublishStep.uploadingThumb   => 'ENVIANDO CAPA...',
      _PublishStep.salvando         => 'PUBLICANDO...',
      _                             => 'AGUARDE...',
    };
    return Positioned.fill(child: Container(color: Colors.black.withOpacity(0.55),
      child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 72, height: 72, child: Stack(alignment: Alignment.center, children: [
          CircularProgressIndicator(value: progress,
              color: TabuColors.rosaPrincipal, backgroundColor: Colors.white.withOpacity(0.1), strokeWidth: 3),
          if (progress != null && progress > 0) Text('${(progress * 100).toInt()}%', style: const TextStyle(
              fontFamily: TabuTypography.bodyFont, fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
        ])),
        const SizedBox(height: 20),
        Text(label, style: const TextStyle(fontFamily: TabuTypography.bodyFont,
            fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2.5, color: Colors.white)),
        if (_publishStep == _PublishStep.uploadingMedia && _tipoAtual == 'video' && _videoTamanhoComprimido != null) ...[
          const SizedBox(height: 10),
          Text('${_videoTamanhoOriginal ?? '?'} → $_videoTamanhoComprimido',
              style: const TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 10, color: TabuColors.subtle, letterSpacing: 1)),
        ],
      ]))));
  }

  Widget _buildTopBar() => Padding(
    padding: const EdgeInsets.fromLTRB(4, 10, 16, 10),
    child: Row(children: [
      IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: TabuColors.dim, size: 18),
          onPressed: _publicando ? null : () => Navigator.pop(context)),
      const Expanded(child: Text('NOVO POST', textAlign: TextAlign.center,
          style: TextStyle(fontFamily: TabuTypography.displayFont, fontSize: 18, letterSpacing: 5, color: TabuColors.branco))),
      GestureDetector(onTap: () => _snack('Preview — em breve!'),
          child: const Text('VER', style: TextStyle(fontFamily: TabuTypography.bodyFont,
              fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2.5, color: TabuColors.rosaPrincipal))),
    ]));

  Widget _buildAutor(String name, String avatarUrl) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
    child: Row(children: [
      Container(width: 42, height: 42,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
            border: Border.all(color: TabuColors.borderMid, width: 1),
            gradient: const LinearGradient(colors: [TabuColors.rosaDeep, TabuColors.rosaPrincipal],
                begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: ClipRRect(borderRadius: BorderRadius.circular(9),
            child: avatarUrl.isNotEmpty ? Image.network(avatarUrl, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.person_outline, color: TabuColors.rosaPrincipal, size: 20))
                : const Icon(Icons.person_outline, color: TabuColors.rosaPrincipal, size: 20))),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: const TextStyle(fontFamily: TabuTypography.bodyFont,
            fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: TabuColors.branco)),
        const SizedBox(height: 3),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: TabuColors.rosaPrincipal.withOpacity(0.12),
                border: Border.all(color: TabuColors.rosaPrincipal.withOpacity(0.3), width: 0.8)),
            child: const Text('PUBLICAR AGORA', style: TextStyle(fontFamily: TabuTypography.bodyFont,
                fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 2, color: TabuColors.rosaPrincipal))),
      ]),
    ]));

  Widget _buildCampoTitulo() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Label('TÍTULO'), const SizedBox(height: 8),
      TextField(controller: _tituloCtrl, focusNode: _tituloFocus, maxLength: 80,
        textCapitalization: TextCapitalization.sentences, textInputAction: TextInputAction.next,
        onEditingComplete: () => FocusScope.of(context).requestFocus(_descFocus),
        onChanged: (_) => setState(() {}),
        style: const TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 18,
            fontWeight: FontWeight.w700, color: TabuColors.branco, letterSpacing: 0.3),
        decoration: InputDecoration(hintText: 'Dá um nome incrível pro post...',
          hintStyle: TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 17,
              color: TabuColors.subtle.withOpacity(0.5), letterSpacing: 0.2),
          counterText: '', border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero)),
      const SizedBox(height: 6),
      Container(height: 1, decoration: BoxDecoration(gradient: LinearGradient(colors: [
        TabuColors.rosaPrincipal.withOpacity(_tituloFocus.hasFocus ? 0.7 : 0.2), Colors.transparent]))),
    ]));

  Widget _buildTabs() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Label('TIPO DE CONTEÚDO'), const SizedBox(height: 10),
      Container(decoration: BoxDecoration(color: TabuColors.bgCard,
          border: Border.all(color: TabuColors.border, width: 0.8)),
        child: TabBar(controller: _tabController,
          indicatorColor: TabuColors.rosaPrincipal, indicatorWeight: 2,
          indicatorSize: TabBarIndicatorSize.tab, labelColor: TabuColors.rosaPrincipal,
          unselectedLabelColor: TabuColors.subtle, dividerColor: Colors.transparent,
          labelStyle: const TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2),
          unselectedLabelStyle: const TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 2),
          tabs: const [
            Tab(icon: Icon(Icons.photo_outlined,          size: 15), text: 'FOTO'),
            Tab(icon: Icon(Icons.text_fields_rounded,     size: 15), text: 'TEXTO'),
            Tab(icon: Icon(Icons.emoji_emotions_outlined, size: 15), text: 'EMOJI'),
            Tab(icon: Icon(Icons.videocam_outlined,       size: 15), text: 'VÍDEO'),
          ])),
    ]));

  Widget _buildTabContent() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic, switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) => FadeTransition(opacity: anim,
          child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(anim), child: child)),
      child: switch (_tabController.index) {
        0 => KeyedSubtree(key: const ValueKey('foto'),  child: _buildTabFoto()),
        1 => KeyedSubtree(key: const ValueKey('texto'), child: _buildTabTexto()),
        2 => KeyedSubtree(key: const ValueKey('emoji'), child: _buildTabEmoji()),
        3 => KeyedSubtree(key: const ValueKey('video'), child: _buildTabVideo()),
        _ => const SizedBox.shrink(),
      }));

  Widget _buildTabFoto() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    GestureDetector(onTap: _showFotoSheet,
      child: AnimatedContainer(duration: const Duration(milliseconds: 300),
        width: double.infinity, height: _foto != null ? 280 : 180,
        decoration: BoxDecoration(color: TabuColors.bgCard, border: Border.all(
            color: _foto != null ? TabuColors.rosaPrincipal.withOpacity(0.4) : TabuColors.border,
            width: _foto != null ? 1 : 0.8)),
        child: _foto != null
            ? Stack(fit: StackFit.expand, children: [
                Image.file(_foto!, fit: BoxFit.cover),
                Positioned(left: 0, right: 0, bottom: 0,
                  child: _WatermarkPreviewBar(userName: _userName)),
                Positioned.fill(child: Container(decoration: BoxDecoration(border: Border.all(
                    color: TabuColors.rosaPrincipal.withOpacity(0.25), width: 1)))),
                Positioned(top: 8, right: 8, child: Row(children: [
                  _MiniBtn(icon: Icons.edit_outlined, onTap: _showFotoSheet), const SizedBox(width: 6),
                  _MiniBtn(icon: Icons.close, onTap: () => setState(() => _foto = null)),
                ])),
              ])
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(width: 56, height: 56, decoration: BoxDecoration(shape: BoxShape.circle,
                    color: TabuColors.rosaPrincipal.withOpacity(0.1),
                    border: Border.all(color: TabuColors.rosaPrincipal.withOpacity(0.3), width: 1)),
                    child: const Icon(Icons.add_photo_alternate_outlined, color: TabuColors.rosaPrincipal, size: 26)),
                const SizedBox(height: 12),
                const Text('TOQUE PARA ADICIONAR FOTO', style: TextStyle(fontFamily: TabuTypography.bodyFont,
                    fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2.5, color: TabuColors.subtle)),
                const SizedBox(height: 4),
                const Text('câmera ou galeria', style: TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 11, color: TabuColors.subtle)),
              ]))),
    if (_foto != null) Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(children: [
        const Icon(Icons.verified_outlined, size: 11, color: TabuColors.rosaPrincipal),
        const SizedBox(width: 5),
        Text('marca d\'água TABU será aplicada no upload',
            style: TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 9,
                letterSpacing: 1, color: TabuColors.rosaPrincipal.withOpacity(0.7))),
      ])),
    const SizedBox(height: 16),
    _buildCampoDescricao(hint: 'Adicione uma legenda...', opcional: true),
  ]);

  Widget _buildTabTexto() => _buildCampoDescricao(hint: 'Escreva o que está rolando...', opcional: false);

  Widget _buildTabEmoji() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    AnimatedContainer(duration: const Duration(milliseconds: 300), width: double.infinity, height: 160,
      decoration: BoxDecoration(color: TabuColors.bgCard, border: Border.all(
          color: _emojiSelecionado != null ? TabuColors.rosaPrincipal.withOpacity(0.4) : TabuColors.border, width: 0.8)),
      child: Center(child: _emojiSelecionado != null
          ? Text(_emojiSelecionado!, style: const TextStyle(fontSize: 96))
          : Column(mainAxisSize: MainAxisSize.min, children: const [
              Icon(Icons.emoji_emotions_outlined, color: TabuColors.border, size: 36), SizedBox(height: 8),
              Text('ESCOLHA UM EMOJI ABAIXO', style: TextStyle(fontFamily: TabuTypography.bodyFont,
                  fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2.5, color: TabuColors.subtle)),
            ]))),
    const SizedBox(height: 16),
    ..._emojiGroups.entries.map((group) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(bottom: 8, top: 4), child: Text(group.key,
          style: const TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 9,
              fontWeight: FontWeight.w700, letterSpacing: 2.5, color: TabuColors.rosaPrincipal))),
      GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1),
        itemCount: group.value.length,
        itemBuilder: (_, i) {
          final emoji = group.value[i]; final sel = _emojiSelecionado == emoji;
          return GestureDetector(
            onTap: () { setState(() => _emojiSelecionado = sel ? null : emoji); HapticFeedback.selectionClick(); },
            child: AnimatedContainer(duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                  color: sel ? TabuColors.rosaPrincipal.withOpacity(0.15) : TabuColors.bgCard,
                  border: Border.all(color: sel ? TabuColors.rosaPrincipal : TabuColors.border, width: sel ? 1.5 : 0.8)),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 26)))));
        }),
      const SizedBox(height: 12),
    ])),
    _buildCampoDescricao(hint: 'Adicione uma legenda ao emoji...', opcional: true),
  ]);

  Widget _buildTabVideo() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    GestureDetector(onTap: _video == null ? _showVideoSheet : _toggleVideoPlay,
      child: AnimatedContainer(duration: const Duration(milliseconds: 300),
        width: double.infinity, height: _video != null ? 300 : 180,
        decoration: BoxDecoration(color: TabuColors.bgCard, border: Border.all(
            color: _video != null ? TabuColors.rosaPrincipal.withOpacity(0.4) : TabuColors.border,
            width: _video != null ? 1 : 0.8)),
        child: _video != null && _videoCtrl != null && _videoCtrl!.value.isInitialized
            ? Stack(fit: StackFit.expand, children: [
                ClipRect(child: FittedBox(fit: BoxFit.cover, child: SizedBox(
                    width: _videoCtrl!.value.size.width, height: _videoCtrl!.value.size.height,
                    child: VideoPlayer(_videoCtrl!)))),
                if (!_videoPlaying && _thumbBytes != null)
                  Positioned.fill(child: Image.memory(_thumbBytes!, fit: BoxFit.cover)),
                Positioned.fill(child: Container(decoration: BoxDecoration(border: Border.all(
                    color: TabuColors.rosaPrincipal.withOpacity(0.25), width: 1)))),
                Positioned(left: 0, right: 0, bottom: 0,
                  child: _WatermarkPreviewBar(userName: _userName)),
                Center(child: AnimatedOpacity(opacity: _videoPlaying ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(width: 56, height: 56, decoration: BoxDecoration(shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.55),
                      border: Border.all(color: TabuColors.rosaPrincipal, width: 1.5)),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30)))),
                Positioned(bottom: 36, left: 10, child: _buildDuracaoBadge()),
                Positioned(top: 8, right: 8, child: Row(children: [
                  _MiniBtn(icon: Icons.edit_outlined, onTap: _showVideoSheet), const SizedBox(width: 6),
                  _MiniBtn(icon: Icons.close, onTap: _removerVideo),
                ])),
                Positioned(bottom: 0, left: 0, right: 0, child: _VideoProgressBar(controller: _videoCtrl!)),
              ])
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(width: 56, height: 56, decoration: BoxDecoration(shape: BoxShape.circle,
                    color: TabuColors.rosaPrincipal.withOpacity(0.1),
                    border: Border.all(color: TabuColors.rosaPrincipal.withOpacity(0.3), width: 1)),
                    child: const Icon(Icons.video_call_outlined, color: TabuColors.rosaPrincipal, size: 28)),
                const SizedBox(height: 12),
                const Text('TOQUE PARA ADICIONAR VÍDEO', style: TextStyle(fontFamily: TabuTypography.bodyFont,
                    fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2.5, color: TabuColors.subtle)),
                const SizedBox(height: 4),
                Text('câmera ou galeria · máx $_maxVideoSeconds seg',
                    style: const TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 11, color: TabuColors.subtle)),
              ]))),
    if (_video != null && _videoCtrl != null && _videoCtrl!.value.isInitialized)
      Padding(padding: const EdgeInsets.only(top: 8), child: _buildEscolherCapaBtn()),
    if (_video != null && _compressProgress < 1.0)
      Padding(padding: const EdgeInsets.only(top: 8), child: _buildCompressProgressBar()),
    if (_video != null && _compressProgress >= 1.0 && _videoTamanhoOriginal != null)
      Padding(padding: const EdgeInsets.only(top: 8), child: _buildSizeChip()),
    if (_video != null && _videoDuration != null && !_videoDuracaoValida)
      Padding(padding: const EdgeInsets.only(top: 8), child: _buildAvisoDuracao()),
    if (_video != null) Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(children: [
        const Icon(Icons.verified_outlined, size: 11, color: TabuColors.rosaPrincipal),
        const SizedBox(width: 5),
        Text('marca d\'água TABU aplicada na thumbnail do vídeo',
            style: TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 9,
                letterSpacing: 1, color: TabuColors.rosaPrincipal.withOpacity(0.7))),
      ])),
    const SizedBox(height: 16),
    _buildCampoDescricao(hint: 'Adicione uma legenda ao vídeo...', opcional: true),
  ]);

  Widget _buildEscolherCapaBtn() => GestureDetector(onTap: _abrirSeletorCapa,
    child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
          color: _capaPersonalizada ? TabuColors.rosaPrincipal.withOpacity(0.12) : TabuColors.bgCard,
          border: Border.all(color: _capaPersonalizada ? TabuColors.rosaPrincipal.withOpacity(0.6)
              : TabuColors.border, width: _capaPersonalizada ? 1.2 : 0.8)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (_thumbBytes != null)
          Container(width: 36, height: 36, margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(border: Border.all(color: TabuColors.rosaPrincipal.withOpacity(0.5), width: 1)),
              child: Image.memory(_thumbBytes!, fit: BoxFit.cover)),
        Icon(_capaPersonalizada ? Icons.check_circle_rounded : Icons.photo_camera_outlined,
            color: _capaPersonalizada ? TabuColors.rosaPrincipal : TabuColors.subtle, size: 15),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_capaPersonalizada ? 'CAPA PERSONALIZADA' : 'ESCOLHER CAPA',
              style: TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 10,
                  fontWeight: FontWeight.w700, letterSpacing: 2,
                  color: _capaPersonalizada ? TabuColors.rosaPrincipal : TabuColors.subtle)),
          Text(_capaPersonalizada ? 'toque para trocar o frame' : 'selecione um frame do vídeo',
              style: const TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 9, letterSpacing: 0.5, color: TabuColors.subtle)),
        ]),
      ])));

  Widget _buildCompressProgressBar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: TabuColors.bgCard,
        border: Border.all(color: TabuColors.rosaPrincipal.withOpacity(0.3), width: 0.8)),
    child: Row(children: [
      const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: TabuColors.rosaPrincipal, strokeWidth: 1.5)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('COMPRIMINDO... ${(_compressProgress * 100).toInt()}%', style: const TextStyle(fontFamily: TabuTypography.bodyFont,
            fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2, color: TabuColors.rosaPrincipal)),
        const SizedBox(height: 5),
        ClipRRect(borderRadius: BorderRadius.circular(1),
            child: LinearProgressIndicator(value: _compressProgress,
                backgroundColor: TabuColors.border, color: TabuColors.rosaPrincipal, minHeight: 2)),
      ])),
    ]));

  Widget _buildSizeChip() {
    final original = _videoTamanhoOriginal ?? '?'; final comprimido = _videoTamanhoComprimido;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: TabuColors.bgCard,
          border: Border.all(color: TabuColors.rosaPrincipal.withOpacity(0.25), width: 0.8)),
      child: Row(children: [
        const Icon(Icons.compress_rounded, color: TabuColors.rosaPrincipal, size: 14), const SizedBox(width: 8),
        if (comprimido != null) ...[
          Text('$original → $comprimido', style: const TextStyle(fontFamily: TabuTypography.bodyFont,
              fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1, color: TabuColors.branco)),
          const SizedBox(width: 6),
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: TabuColors.rosaPrincipal.withOpacity(0.15),
                  border: Border.all(color: TabuColors.rosaPrincipal.withOpacity(0.4), width: 0.8)),
              child: const Text('COMPRIMIDO', style: TextStyle(fontFamily: TabuTypography.bodyFont,
                  fontSize: 7, fontWeight: FontWeight.w700, letterSpacing: 2, color: TabuColors.rosaPrincipal))),
        ] else Text('Original: $original', style: const TextStyle(fontFamily: TabuTypography.bodyFont,
            fontSize: 10, letterSpacing: 1, color: TabuColors.subtle)),
      ]));
  }

  Widget _buildDuracaoBadge() {
    if (_videoDuration == null) return const SizedBox.shrink();
    final secs = _videoDuration!.inSeconds; final ok = secs <= _maxVideoSeconds;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.65), border: Border.all(
          color: ok ? TabuColors.rosaPrincipal.withOpacity(0.5) : const Color(0xFFE85D5D), width: 0.8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.timer_outlined, size: 11, color: ok ? TabuColors.rosaPrincipal : const Color(0xFFE85D5D)),
        const SizedBox(width: 4),
        Text('${secs}s / ${_maxVideoSeconds}s', style: TextStyle(fontFamily: TabuTypography.bodyFont,
            fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1,
            color: ok ? TabuColors.branco : const Color(0xFFE85D5D))),
      ]));
  }

  Widget _buildAvisoDuracao() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: const Color(0xFF3D0A0A),
        border: Border.all(color: const Color(0xFFE85D5D).withOpacity(0.5), width: 0.8)),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded, color: Color(0xFFE85D5D), size: 16), const SizedBox(width: 10),
      Expanded(child: Text('Vídeo muito longo (${_videoDuration!.inSeconds}s). Máximo: $_maxVideoSeconds segundos.',
          style: const TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 11, letterSpacing: 0.5, color: Color(0xFFE85D5D)))),
    ]));

  Widget _buildCampoDescricao({required String hint, required bool opcional}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _Label('DESCRIÇÃO'),
          if (opcional) ...[const SizedBox(width: 8), const Text('opcional',
              style: TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 9, color: TabuColors.subtle, letterSpacing: 1))],
        ]),
        const SizedBox(height: 8),
        Container(decoration: BoxDecoration(color: TabuColors.bgCard,
            border: Border.all(color: TabuColors.border, width: 0.8)),
          child: TextField(controller: _descCtrl, focusNode: _descFocus, maxLines: 5, maxLength: 500,
            keyboardType: TextInputType.multiline, textInputAction: TextInputAction.newline,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 14,
                color: TabuColors.branco, letterSpacing: 0.2, height: 1.55),
            decoration: InputDecoration(hintText: hint,
              hintStyle: TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 14,
                  color: TabuColors.subtle.withOpacity(0.5), letterSpacing: 0.2),
              border: InputBorder.none, contentPadding: const EdgeInsets.all(14),
              counterStyle: const TextStyle(fontFamily: TabuTypography.bodyFont,
                  fontSize: 9, color: TabuColors.subtle, letterSpacing: 1)))),
      ]);

  Widget _buildVisibilidade() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const SizedBox(height: 8), Container(height: 0.5, color: TabuColors.border),
    const SizedBox(height: 16), _Label('VISIBILIDADE'), const SizedBox(height: 10),
    Row(children: _Visibilidade.values.map((v) {
      final sel = _visibilidade == v; final isLast = v == _Visibilidade.values.last;
      return Expanded(child: GestureDetector(onTap: () => setState(() => _visibilidade = v),
        child: AnimatedContainer(duration: const Duration(milliseconds: 180),
          margin: EdgeInsets.only(right: isLast ? 0 : 10), padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: sel ? TabuColors.rosaPrincipal.withOpacity(0.1) : TabuColors.bgCard,
              border: Border.all(color: sel ? TabuColors.rosaPrincipal.withOpacity(0.6)
                  : TabuColors.border, width: sel ? 1.2 : 0.8)),
          child: Column(children: [
            Icon(v.icon, size: 16, color: sel ? TabuColors.rosaPrincipal : TabuColors.subtle),
            const SizedBox(height: 5),
            Text(v.label, style: TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 8,
                fontWeight: FontWeight.w700, letterSpacing: 2,
                color: sel ? TabuColors.rosaPrincipal : TabuColors.subtle)),
          ]))));
    }).toList()),
  ]);

  Widget _buildPublicarBtn() {
    final can = _podePublicar;
    return Container(
      decoration: const BoxDecoration(color: TabuColors.bgAlt,
          border: Border(top: BorderSide(color: TabuColors.border, width: 0.5))),
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      child: GestureDetector(onTap: can ? _publicar : null,
        child: AnimatedContainer(duration: const Duration(milliseconds: 200),
          width: double.infinity, height: 52,
          decoration: BoxDecoration(
              color: _publishStep == _PublishStep.erro ? const Color(0xFFE85D5D)
                  : can ? TabuColors.rosaPrincipal : TabuColors.bgCard,
              border: Border.all(color: can ? TabuColors.rosaPrincipal : TabuColors.border, width: 0.8),
              boxShadow: can ? [BoxShadow(color: TabuColors.glow.withOpacity(0.35), blurRadius: 16, spreadRadius: 1)] : null),
          child: Center(child: _publicando
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: TabuColors.branco, strokeWidth: 2))
              : _publishStep == _PublishStep.erro
                ? Row(mainAxisSize: MainAxisSize.min, children: const [
                    Icon(Icons.error_outline_rounded, color: Colors.white, size: 16), SizedBox(width: 8),
                    Text('TENTAR NOVAMENTE', style: TextStyle(fontFamily: TabuTypography.bodyFont,
                        fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 2, color: Colors.white)),
                  ])
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.send_rounded, color: can ? TabuColors.branco : TabuColors.subtle, size: 16),
                    const SizedBox(width: 10),
                    Text('PUBLICAR', style: TextStyle(fontFamily: TabuTypography.bodyFont,
                        fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 3,
                        color: can ? TabuColors.branco : TabuColors.subtle)),
                  ])))));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  WATERMARK PREVIEW BAR  —  preview visual na UI (não entra no upload)
// ══════════════════════════════════════════════════════════════════════════════
class _WatermarkPreviewBar extends StatelessWidget {
  final String userName;
  const _WatermarkPreviewBar({required this.userName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withOpacity(0.55)]),
      ),
      child: Row(children: [
        Container(width: 1.5, height: 16, color: Colors.white.withOpacity(0.9)),
        const SizedBox(width: 7),
        const Text('TABU', style: TextStyle(
            fontFamily: TabuTypography.displayFont, fontSize: 13,
            fontWeight: FontWeight.w900, letterSpacing: 3, color: Colors.white)),
        Container(
          width: 5, height: 5, margin: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: TabuColors.rosaClaro.withOpacity(0.85)),
        ),
        Text('@${userName.toLowerCase()}',
            style: TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 11,
                fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.85))),
        const Spacer(),
        Text('EXCLUSIVO', style: TextStyle(
            fontFamily: TabuTypography.bodyFont, fontSize: 8,
            fontWeight: FontWeight.w700, letterSpacing: 2,
            color: TabuColors.rosaClaro.withOpacity(0.9))),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  FRAME PICKER SHEET
// ══════════════════════════════════════════════════════════════════════════════
class _FramePickerSheet extends StatefulWidget {
  final VideoPlayerController videoCtrl;
  final Duration totalDuration;
  final Uint8List? currentThumb;
  final void Function(Uint8List bytes) onConfirm;

  const _FramePickerSheet({
    required this.videoCtrl,
    required this.totalDuration,
    required this.onConfirm,
    this.currentThumb,
  });

  @override
  State<_FramePickerSheet> createState() => _FramePickerSheetState();
}

class _FramePickerSheetState extends State<_FramePickerSheet> {
  late double _sliderValue;
  bool _capturando = false;
  bool _seekando   = false;

  final _repaintKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final total = widget.totalDuration.inMilliseconds;
    final pos   = widget.videoCtrl.value.position.inMilliseconds;
    _sliderValue = total > 0 ? (pos / total).clamp(0.0, 1.0) : 0.0;
    widget.videoCtrl.pause();
  }

  int get _positionMs =>
      (_sliderValue * widget.totalDuration.inMilliseconds).round();

  Future<void> _onSliderChanged(double v) async {
    if (_seekando) return;
    _seekando = true;
    setState(() => _sliderValue = v);
    await widget.videoCtrl.seekTo(
        Duration(milliseconds: (v * widget.totalDuration.inMilliseconds).round()));
    widget.videoCtrl.pause();
    if (mounted) setState(() => _seekando = false);
  }

  Future<void> _confirmar() async {
    if (_capturando) return;
    setState(() => _capturando = true);

    try {
      await widget.videoCtrl.seekTo(Duration(milliseconds: _positionMs));
      widget.videoCtrl.pause();
      await Future.delayed(const Duration(milliseconds: 150));
      await _aguardarProximoFrame();
      await _aguardarProximoFrame();

      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('RepaintBoundary não encontrado');

      final dpr = ui.PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 2.0;
      final image = await boundary.toImage(pixelRatio: dpr);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      if (byteData == null) throw Exception('toByteData retornou null');

      if (!mounted) return;
      Navigator.pop(context);
      widget.onConfirm(byteData.buffer.asUint8List());
    } catch (e) {
      debugPrint('[FramePicker] $e');
      if (mounted) {
        setState(() => _capturando = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: Color(0xFF3D0A0A), behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16), shape: RoundedRectangleBorder(),
          content: Text('Não foi possível capturar o frame. Tente novamente.',
              style: TextStyle(fontFamily: TabuTypography.bodyFont,
                  fontSize: 11, color: TabuColors.branco, letterSpacing: 1))));
      }
    }
  }

  Future<void> _aguardarProximoFrame() {
    final c = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) => c.complete());
    return c.future;
  }

  String _formatDuration(int ms) {
    final d = Duration(milliseconds: ms);
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = widget.totalDuration.inMilliseconds;
    final posMs   = _positionMs;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(color: TabuColors.bgAlt,
          border: Border(top: BorderSide(color: TabuColors.rosaPrincipal, width: 1.5))),
      child: Column(children: [
        Container(width: 36, height: 3, margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(color: TabuColors.border, borderRadius: BorderRadius.circular(2))),

        Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Row(children: [
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ESCOLHER CAPA', style: TextStyle(fontFamily: TabuTypography.displayFont,
                  fontSize: 16, letterSpacing: 4, color: TabuColors.branco)),
              SizedBox(height: 3),
              Text('arraste o slider para selecionar o frame', style: TextStyle(
                  fontFamily: TabuTypography.bodyFont, fontSize: 10, letterSpacing: 1, color: TabuColors.subtle)),
            ])),
            GestureDetector(onTap: () => Navigator.pop(context),
              child: Container(width: 32, height: 32,
                  decoration: BoxDecoration(color: TabuColors.bgCard, border: Border.all(color: TabuColors.border, width: 0.8)),
                  child: const Icon(Icons.close, color: TabuColors.subtle, size: 16))),
          ])),

        Container(height: 0.5, color: TabuColors.border),

        Expanded(child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(children: [
            Container(width: double.infinity, height: 280, color: Colors.black,
              child: Stack(children: [
                Positioned.fill(child: RepaintBoundary(
                  key: _repaintKey,
                  child: ClipRect(child: FittedBox(fit: BoxFit.contain,
                    child: SizedBox(
                      width:  widget.videoCtrl.value.size.width,
                      height: widget.videoCtrl.value.size.height,
                      child:  VideoPlayer(widget.videoCtrl)))))),
                if (_seekando)
                  Positioned.fill(child: Container(color: Colors.black.withOpacity(0.35),
                    child: const Center(child: SizedBox(width: 24, height: 24,
                        child: CircularProgressIndicator(color: TabuColors.rosaPrincipal, strokeWidth: 2))))),
                Positioned(bottom: 10, right: 10,
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.75),
                        border: Border.all(color: TabuColors.rosaPrincipal.withOpacity(0.6), width: 0.8)),
                    child: Text(_formatDuration(posMs), style: const TextStyle(
                        fontFamily: TabuTypography.bodyFont, fontSize: 13,
                        fontWeight: FontWeight.w700, letterSpacing: 1, color: Colors.white)))),
                Positioned(top: 10, left: 10,
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    color: TabuColors.rosaPrincipal.withOpacity(0.9),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.image_outlined, color: Colors.white, size: 10), SizedBox(width: 4),
                      Text('CAPA', style: TextStyle(fontFamily: TabuTypography.bodyFont,
                          fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 2, color: Colors.white)),
                    ]))),
              ])),

            Padding(padding: const EdgeInsets.fromLTRB(20, 24, 20, 0), child: Column(children: [
              Row(children: [
                Text(_formatDuration(posMs), style: const TextStyle(fontFamily: TabuTypography.bodyFont,
                    fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: TabuColors.rosaPrincipal)),
                const Spacer(),
                Text(_formatDuration(totalMs), style: const TextStyle(fontFamily: TabuTypography.bodyFont,
                    fontSize: 11, letterSpacing: 1, color: TabuColors.subtle)),
              ]),
              const SizedBox(height: 10),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: TabuColors.rosaPrincipal, inactiveTrackColor: TabuColors.border,
                  thumbColor: TabuColors.rosaPrincipal,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8, elevation: 0),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                  overlayColor: TabuColors.rosaPrincipal.withOpacity(0.15), trackHeight: 3),
                child: Slider(
                  value: _sliderValue, min: 0.0, max: 1.0,
                  onChanged: (v) => _onSliderChanged(v),
                  onChangeEnd: (v) async {
                    setState(() => _sliderValue = v);
                    await widget.videoCtrl.seekTo(Duration(milliseconds: (v * totalMs).round()));
                    widget.videoCtrl.pause();
                  })),
              const SizedBox(height: 8),
              const Text('← arraste para navegar pelo vídeo →', style: TextStyle(
                  fontFamily: TabuTypography.bodyFont, fontSize: 9, letterSpacing: 1.5, color: TabuColors.subtle)),
            ])),

            Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: TabuColors.bgCard,
                    border: Border.all(color: TabuColors.rosaPrincipal.withOpacity(0.2), width: 0.8)),
                child: const Row(children: [
                  Icon(Icons.info_outline_rounded, color: TabuColors.rosaPrincipal, size: 14), SizedBox(width: 10),
                  Expanded(child: Text('A capa aparece no feed antes do vídeo ser reproduzido.',
                      style: TextStyle(fontFamily: TabuTypography.bodyFont,
                          fontSize: 11, letterSpacing: 0.3, color: TabuColors.subtle, height: 1.5))),
                ]))),
            const SizedBox(height: 100),
          ]),
        )),

        Container(
          decoration: const BoxDecoration(color: TabuColors.bgAlt,
              border: Border(top: BorderSide(color: TabuColors.border, width: 0.5))),
          padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
          child: GestureDetector(onTap: _capturando ? null : _confirmar,
            child: AnimatedContainer(duration: const Duration(milliseconds: 200),
              width: double.infinity, height: 52,
              decoration: BoxDecoration(color: TabuColors.rosaPrincipal,
                  boxShadow: [BoxShadow(color: TabuColors.glow.withOpacity(0.35), blurRadius: 16, spreadRadius: 1)]),
              child: Center(child: _capturando
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.check_rounded, color: Colors.white, size: 18), SizedBox(width: 10),
                      Text('USAR ESTE FRAME COMO CAPA', style: TextStyle(fontFamily: TabuTypography.bodyFont,
                          fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 2, color: Colors.white)),
                    ])))),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  WIDGET — BARRA DE PROGRESSO DO VÍDEO
// ══════════════════════════════════════════════════════════════════════════════
class _VideoProgressBar extends StatefulWidget {
  final VideoPlayerController controller;
  const _VideoProgressBar({required this.controller});
  @override State<_VideoProgressBar> createState() => _VideoProgressBarState();
}
class _VideoProgressBarState extends State<_VideoProgressBar> {
  @override void initState() { super.initState(); widget.controller.addListener(_update); }
  @override void dispose() { widget.controller.removeListener(_update); super.dispose(); }
  void _update() { if (mounted) setState(() {}); }
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
//  ENUMS E WIDGETS AUXILIARES
// ══════════════════════════════════════════════════════════════════════════════
enum _Visibilidade {
  publico    (Icons.public_rounded,         'PÚBLICO'),
  seguidores (Icons.people_outline_rounded, 'SEGUIDORES'),
  vip        (Icons.star_border_rounded,    'VIP');
  final IconData icon; final String label;
  const _Visibilidade(this.icon, this.label);
}

class _Label extends StatelessWidget {
  final String text; const _Label(this.text);
  @override Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontFamily: TabuTypography.bodyFont,
          fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 3, color: TabuColors.rosaPrincipal));
}

class _MiniBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap; const _MiniBtn({required this.icon, required this.onTap});
  @override Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Container(width: 30, height: 30, decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65), border: Border.all(color: TabuColors.borderMid, width: 0.8)),
        child: Icon(icon, color: TabuColors.branco, size: 15)));
}

class _SheetTile extends StatelessWidget {
  final IconData icon; final String label; final String sublabel; final bool danger; final VoidCallback onTap;
  const _SheetTile({required this.icon, required this.label, required this.sublabel, required this.onTap, this.danger = false});
  @override Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFE85D5D) : TabuColors.branco;
    return InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withOpacity(0.1),
            border: Border.all(color: color.withOpacity(0.3), width: 0.8)), child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 13,
              fontWeight: FontWeight.w700, letterSpacing: 2, color: color)),
          Text(sublabel, style: const TextStyle(fontFamily: TabuTypography.bodyFont,
              fontSize: 10, letterSpacing: 0.5, color: TabuColors.subtle)),
        ]),
      ])));
  }
}

class _PostBg extends CustomPainter {
  @override void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = TabuColors.bg);
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.04), size.width * 0.6,
      Paint()..shader = RadialGradient(colors: [TabuColors.rosaPrincipal.withOpacity(0.06), Colors.transparent])
          .createShader(Rect.fromCircle(center: Offset(size.width * 0.9, size.height * 0.04), radius: size.width * 0.6)));
  }
  @override bool shouldRepaint(_PostBg old) => false;
}