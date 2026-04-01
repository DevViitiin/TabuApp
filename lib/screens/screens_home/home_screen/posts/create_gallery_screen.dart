// lib/screens/screens_home/perfil_screen/galeria/create_gallery_item_screen.dart

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tabuapp/screens/screens_home/perfil_screen/perfil/perfil_screen.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/services/services_app/gallery_service.dart';
import 'package:tabuapp/services/services_app/video_compress_service.dart';
import 'package:tabuapp/services/services_app/watermark_service.dart';
import 'package:tabuapp/services/services_app/video_watermark_service.dart';

class CreateGalleryItemScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const CreateGalleryItemScreen({super.key, required this.userData});

  @override
  State<CreateGalleryItemScreen> createState() =>
      _CreateGalleryItemScreenState();
}

enum _PublishStep {
  idle,
  aplicandoMarca,
  comprimindoVideo,
  marcandoVideo,
  uploadingMedia,
  uploadingThumb,
  salvando,
  concluido,
  erro,
}

class _CreateGalleryItemScreenState extends State<CreateGalleryItemScreen> {
  final _picker = ImagePicker();

  File? _foto;

  int _videoSessionId = 0;
  File? _video;
  File? _videoComprimido;
  Uint8List? _thumbBytes;
  File? _thumbFile;
  VideoPlayerController? _videoCtrl;
  Duration? _videoDuration;
  bool _videoPlaying = false;

  String? _videoTamanhoOriginal;
  String? _videoTamanhoComprimido;

  _PublishStep _publishStep = _PublishStep.idle;
  double _uploadProgress = 0.0;
  double _compressProgress = 0.0;

  static const int _maxVideoSeconds = 25;

  bool get _publicando =>
      _publishStep != _PublishStep.idle &&
      _publishStep != _PublishStep.concluido &&
      _publishStep != _PublishStep.erro;

  bool get _podePublicar {
    if (_publicando) return false;
    if (_foto != null) return true;
    if (_video != null && _videoDuracaoValida) return true;
    return false;
  }

  bool get _videoDuracaoValida {
    if (_videoDuration == null) return false;
    return _videoDuration!.inSeconds <= _maxVideoSeconds &&
        _videoDuration!.inSeconds > 0;
  }

  String get _userName =>
      (widget.userData['name'] as String? ?? 'usuário').toUpperCase();

  @override
  void dispose() {
    _videoCtrl?.dispose();
    super.dispose();
  }

  // ── FOTO ──────────────────────────────────────────────────────────────────
  Future<void> _pickFoto(ImageSource src) async {
    Navigator.pop(context);
    final p = await _picker.pickImage(
        source: src, maxWidth: 1920, maxHeight: 1920, imageQuality: 90);
    if (p == null) return;
    setState(() => _foto = File(p.path));
  }

  // ── VÍDEO ─────────────────────────────────────────────────────────────────
  Future<void> _pickVideo(ImageSource src) async {
    Navigator.pop(context);
    final p = await _picker.pickVideo(
        source: src, maxDuration: Duration(seconds: _maxVideoSeconds));
    if (p == null) return;
    await _carregarVideo(File(p.path));
  }

  Future<void> _carregarVideo(File file) async {
    await VideoCompressService.instance.cancelCompression();
    await _videoCtrl?.dispose();
    final int mySession = ++_videoSessionId;

    setState(() {
      _video = null;
      _videoComprimido = null;
      _thumbBytes = null;
      _thumbFile = null;
      _videoTamanhoOriginal = null;
      _videoTamanhoComprimido = null;
      _videoPlaying = false;
      _compressProgress = 0.0;
      _videoCtrl = null;
      _foto = null; // Limpa foto se tiver
    });

    final tmpCtrl = VideoPlayerController.file(file);
    await tmpCtrl.initialize();
    final dur = tmpCtrl.value.duration;
    await tmpCtrl.dispose();

    if (dur.inSeconds > _maxVideoSeconds) {
      if (mounted)
        _snack('Vídeo muito longo. Máximo: $_maxVideoSeconds segundos.');
      return;
    }
    if (dur.inSeconds == 0) {
      if (mounted) _snack('Vídeo inválido ou corrompido.');
      return;
    }
    if (_videoSessionId != mySession) return;

    final ctrl = VideoPlayerController.file(file);
    await ctrl.initialize();
    ctrl.addListener(() {
      if (mounted) setState(() => _videoPlaying = ctrl.value.isPlaying);
    });

    if (!mounted || _videoSessionId != mySession) {
      ctrl.dispose();
      return;
    }

    setState(() {
      _video = file;
      _videoCtrl = ctrl;
      _videoDuration = dur;
      _videoTamanhoOriginal = VideoCompressService.fileSizeMB(file);
    });

    final File snap = file;
    _comprimirVideoBackground(snap, mySession);
    _gerarThumbnailPrimeiroFrame(snap, mySession);
  }

  Future<void> _comprimirVideoBackground(File original, int mySession) async {
    final comprimido = await VideoCompressService.instance.compress(
      original,
      quality: VideoQuality.MediumQuality,
      onProgress: (p) {
        if (mounted && _videoSessionId == mySession) {
          setState(() => _compressProgress = p);
        }
      },
    );
    if (!mounted || _videoSessionId != mySession) return;
    setState(() {
      _videoComprimido = comprimido;
      _videoTamanhoComprimido = comprimido != null
          ? VideoCompressService.fileSizeMB(comprimido)
          : null;
      _compressProgress = 1.0;
    });
  }

  Future<void> _gerarThumbnailPrimeiroFrame(
      File videoFile, int mySession) async {
    try {
      final bytes = await VideoCompress.getByteThumbnail(videoFile.path,
          quality: 85, position: -1);
      if (!mounted || bytes == null || _videoSessionId != mySession) return;
      await _aplicarThumbBytes(bytes, mySession: mySession);
    } catch (e) {
      debugPrint('[Thumb] $e');
    }
  }

  Future<void> _aplicarThumbBytes(Uint8List bytes, {int? mySession}) async {
    final tmp = await getTemporaryDirectory();
    final path =
        '${tmp.path}/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final file = await File(path).writeAsBytes(bytes);
    if (!mounted) {
      file.deleteSync();
      return;
    }
    if (mySession != null && _videoSessionId != mySession) {
      file.deleteSync();
      return;
    }
    final old = _thumbFile;
    setState(() {
      _thumbBytes = bytes;
      _thumbFile = file;
    });
    if (old != null && old.path != file.path) {
      old.deleteSync(recursive: false);
    }
  }

  void _toggleVideoPlay() {
    if (_videoCtrl == null) return;
    if (_videoCtrl!.value.isPlaying) {
      _videoCtrl!.pause();
    } else {
      if (_videoCtrl!.value.position >= _videoCtrl!.value.duration) {
        _videoCtrl!.seekTo(Duration.zero);
      }
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
      _video = null;
      _videoComprimido = null;
      _thumbBytes = null;
      _thumbFile = null;
      _videoCtrl = null;
      _videoDuration = null;
      _videoPlaying = false;
      _videoTamanhoOriginal = null;
      _videoTamanhoComprimido = null;
      _compressProgress = 0.0;
    });
  }

  // ── SHEETS ────────────────────────────────────────────────────────────────
  void _showMidiaSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: TabuColors.bgAlt,
      shape: const RoundedRectangleBorder(),
      builder: (_) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        _sheetHandle(),
        const Text('ADICIONAR À GALERIA',
            style: TextStyle(
                fontFamily: TabuTypography.displayFont,
                fontSize: 16,
                letterSpacing: 5,
                color: TabuColors.branco)),
        const SizedBox(height: 16),
        Container(height: 0.5, color: TabuColors.border),
        _SheetTile(
            icon: Icons.photo_camera_outlined,
            label: 'TIRAR FOTO',
            sublabel: 'Câmera agora',
            onTap: () => _pickFoto(ImageSource.camera)),
        Container(height: 0.5, color: TabuColors.border),
        _SheetTile(
            icon: Icons.photo_library_outlined,
            label: 'GALERIA - FOTO',
            sublabel: 'Escolher foto',
            onTap: () => _pickFoto(ImageSource.gallery)),
        Container(height: 0.5, color: TabuColors.border),
        _SheetTile(
            icon: Icons.videocam_outlined,
            label: 'GRAVAR VÍDEO',
            sublabel: 'Câmera agora',
            onTap: () => _pickVideo(ImageSource.camera)),
        Container(height: 0.5, color: TabuColors.border),
        _SheetTile(
            icon: Icons.video_library_outlined,
            label: 'GALERIA - VÍDEO',
            sublabel: 'Escolher vídeo',
            onTap: () => _pickVideo(ImageSource.gallery)),
        const SizedBox(height: 20),
      ])),
    );
  }

  Widget _sheetHandle() => Container(
      width: 36,
      height: 3,
      margin: const EdgeInsets.only(top: 12, bottom: 20),
      decoration: BoxDecoration(
          color: TabuColors.border, borderRadius: BorderRadius.circular(2)));

  // ── PUBLICAR ──────────────────────────────────────────────────────────────
  Future<void> _publicar() async {
    if (!_podePublicar) return;
    HapticFeedback.mediumImpact();

    final uid = FirebaseAuth.instance.currentUser?.uid ??
        (widget.userData['uid'] as String?) ??
        (widget.userData['id'] as String?) ??
        '';
    if (uid.isEmpty) {
      _snack('Erro: usuário não autenticado.');
      return;
    }

    final userName =
        (widget.userData['name'] as String? ?? 'Anônimo').toUpperCase();

    setState(() {
      _publishStep = _PublishStep.uploadingMedia;
      _uploadProgress = 0.0;
    });

    try {
      String? mediaUrl;
      String? thumbUrl;
      int? videoDurationSec;
      String type;

      // ── FOTO ──────────────────────────────────────────────────────────────
      if (_foto != null) {
        type = 'foto';
        setState(() => _publishStep = _PublishStep.aplicandoMarca);

        final originalBytes = await _foto!.readAsBytes();
        final watermarkedBytes = await WatermarkService.apply(
          imageBytes: originalBytes,
          userName: userName,
        );

        final tmp = await getTemporaryDirectory();
        final wPath =
            '${tmp.path}/wm_${DateTime.now().millisecondsSinceEpoch}.png';
        final wFile = await File(wPath).writeAsBytes(watermarkedBytes);

        setState(() {
          _publishStep = _PublishStep.uploadingMedia;
          _uploadProgress = 0.0;
        });

        final ref = FirebaseStorage.instance
            .ref('gallery/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg');
        final task =
            ref.putFile(wFile, SettableMetadata(contentType: 'image/jpeg'));
        task.snapshotEvents.listen((s) {
          if (mounted) {
            setState(() => _uploadProgress =
                s.bytesTransferred / (s.totalBytes == 0 ? 1 : s.totalBytes));
          }
        });
        await task;
        mediaUrl = await ref.getDownloadURL();

        wFile.deleteSync(recursive: false);

        // ── VÍDEO ─────────────────────────────────────────────────────────────
      } else if (_video != null) {
        type = 'video';
        videoDurationSec = _videoDuration?.inSeconds;

        final int sessionAtUpload = _videoSessionId;
        final Uint8List? thumbBytesSnapshot =
            _thumbFile != null && await _thumbFile!.exists()
                ? await _thumbFile!.readAsBytes()
                : _thumbBytes;

        if (_videoComprimido == null && _compressProgress < 1.0) {
          setState(() => _publishStep = _PublishStep.comprimindoVideo);
          while (
              _videoComprimido == null && _compressProgress < 1.0 && mounted) {
            await Future.delayed(const Duration(milliseconds: 300));
          }
          if (!mounted) return;
          setState(() {
            _publishStep = _PublishStep.uploadingMedia;
            _uploadProgress = 0.0;
          });
        }

        if (_videoSessionId != sessionAtUpload) {
          debugPrint('[CreateGalleryItem] Sessão mudou — abortando upload.');
          setState(() => _publishStep = _PublishStep.idle);
          return;
        }

        final File videoComprimido = _videoComprimido ?? _video!;
        final ts = DateTime.now().millisecondsSinceEpoch;

        final videoSize = _videoCtrl?.value.size;
        final vw = videoSize?.width.toInt() ?? 1280;
        final vh = videoSize?.height.toInt() ?? 720;

        setState(() {
          _publishStep = _PublishStep.marcandoVideo;
          _uploadProgress = 0.0;
        });

        final watermarkedVideo = await VideoWatermarkService.apply(
          videoFile: videoComprimido,
          userName: userName,
          videoWidth: vw,
          videoHeight: vh,
          onProgress: (p) {
            if (mounted) setState(() => _uploadProgress = p);
          },
        );

        final File videoParaUpload = watermarkedVideo ?? videoComprimido;
        if (watermarkedVideo == null) {
          debugPrint(
              '[CreateGalleryItem] Watermark falhou — upload sem marca.');
        }

        setState(() {
          _publishStep = _PublishStep.uploadingMedia;
          _uploadProgress = 0.0;
        });

        final videoRef =
            FirebaseStorage.instance.ref('gallery/$uid/videos/$ts.mp4');
        final videoTask = videoRef.putFile(
            videoParaUpload, SettableMetadata(contentType: 'video/mp4'));
        videoTask.snapshotEvents.listen((s) {
          if (mounted) {
            setState(() => _uploadProgress =
                s.bytesTransferred / (s.totalBytes == 0 ? 1 : s.totalBytes));
          }
        });
        await videoTask;
        mediaUrl = await videoRef.getDownloadURL();

        if (watermarkedVideo != null) {
          try {
            watermarkedVideo.deleteSync();
          } catch (_) {}
        }

        // Thumbnail
        if (thumbBytesSnapshot != null && thumbBytesSnapshot.isNotEmpty) {
          setState(() {
            _publishStep = _PublishStep.aplicandoMarca;
            _uploadProgress = 0.0;
          });

          final thumbWatermarked = await WatermarkService.apply(
            imageBytes: thumbBytesSnapshot,
            userName: userName,
          );

          setState(() {
            _publishStep = _PublishStep.uploadingThumb;
            _uploadProgress = 0.0;
          });

          final thumbRef =
              FirebaseStorage.instance.ref('gallery/$uid/thumbs/$ts.jpg');
          final thumbTask = thumbRef.putFile(
            await _bytesToTempFile(thumbWatermarked, 'wm_thumb_$ts.png'),
            SettableMetadata(contentType: 'image/jpeg'),
          );
          thumbTask.snapshotEvents.listen((s) {
            if (mounted) {
              setState(() => _uploadProgress =
                  s.bytesTransferred / (s.totalBytes == 0 ? 1 : s.totalBytes));
            }
          });
          await thumbTask;
          thumbUrl = await thumbRef.getDownloadURL();
        }
      } else {
        return;
      }

      if (!mounted) return;
      setState(() => _publishStep = _PublishStep.salvando);

      await GalleryService.instance.addItem(
        userId: uid,
        type: type,
        mediaUrl: mediaUrl!,
        thumbUrl: thumbUrl,
        videoDuration: videoDurationSec,
      );

      if (!mounted) return;
      setState(() => _publishStep = _PublishStep.concluido);
      HapticFeedback.mediumImpact();
      _snack('Adicionado à galeria! ✨', success: true);
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.pop(context, true);
      if (mounted) {
      // ── REDIRECIONA PARA PERFIL + ABA GALERIA ────────────────────────────────
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PerfilScreen(userData: widget.userData),
        ),
      ).then((_) {
        // Força aba GALERIA (index 1)
        // Isso será tratado no initState do PerfilScreen
      });
    }
    } catch (e) {
      debugPrint('[CreateGalleryItem] $e');
      if (!mounted) return;
      setState(() => _publishStep = _PublishStep.erro);
      _snack('Erro ao adicionar. Tente novamente.');
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _publishStep = _PublishStep.idle);
    }
  }

  Future<File> _bytesToTempFile(Uint8List bytes, String name) async {
    final tmp = await getTemporaryDirectory();
    return File('${tmp.path}/$name').writeAsBytes(bytes);
  }

  void _snack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor:
            success ? TabuColors.rosaDeep : const Color(0xFF3D0A0A),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        content: Text(msg,
            style: const TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: TabuColors.branco))));
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final temMidia = _foto != null || _video != null;

    return Scaffold(
      backgroundColor: TabuColors.bg,
      body: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _Bg())),
        Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
                height: 3,
                decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [
                  TabuColors.rosaDeep,
                  TabuColors.rosaPrincipal,
                  TabuColors.rosaClaro,
                  TabuColors.rosaPrincipal,
                  TabuColors.rosaDeep
                ])))),
        SafeArea(
            child: Column(children: [
          _buildTopBar(),
          Container(height: 0.5, color: TabuColors.border),
          Expanded(
              child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(children: [
                        const SizedBox(height: 12),

                        // Preview da mídia
                        if (!temMidia)
                          _buildSelectPrompt()
                        else if (_foto != null)
                          _buildFotoPreview()
                        else
                          _buildVideoPreview(),

                        const SizedBox(height: 24),

                        // Info
                        Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                color: TabuColors.bgCard,
                                border: Border.all(
                                    color: TabuColors.rosaPrincipal
                                        .withOpacity(0.2),
                                    width: 0.8)),
                            child: Row(children: [
                              Icon(Icons.info_outline_rounded,
                                  color: TabuColors.rosaPrincipal, size: 14),
                              const SizedBox(width: 10),
                              const Expanded(
                                  child: Text(
                                      'Fotos e vídeos da galeria aparecem apenas no seu perfil.',
                                      style: TextStyle(
                                          fontFamily: TabuTypography.bodyFont,
                                          fontSize: 11,
                                          letterSpacing: 0.3,
                                          color: TabuColors.subtle,
                                          height: 1.5))),
                            ])),

                        const SizedBox(height: 80),
                      ])))),
          _buildPublicarBtn(),
        ])),
        if (_publicando) _buildProgressOverlay(),
      ]),
    );
  }

  Widget _buildTopBar() => Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 16, 10),
      child: Row(children: [
        IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: TabuColors.dim, size: 18),
            onPressed: _publicando ? null : () => Navigator.pop(context)),
        const Expanded(
            child: Text('ADICIONAR À GALERIA',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: TabuTypography.displayFont,
                    fontSize: 18,
                    letterSpacing: 5,
                    color: TabuColors.branco))),
        const SizedBox(width: 40),
      ]));

  Widget _buildSelectPrompt() => GestureDetector(
      onTap: _showMidiaSheet,
      child: Container(
          height: 320,
          decoration: BoxDecoration(
              color: TabuColors.bgCard,
              border: Border.all(color: TabuColors.border, width: 0.8)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: TabuColors.rosaPrincipal.withOpacity(0.1),
                    border: Border.all(
                        color: TabuColors.rosaPrincipal.withOpacity(0.3),
                        width: 1)),
                child: const Icon(Icons.add_photo_alternate_outlined,
                    color: TabuColors.rosaPrincipal, size: 32)),
            const SizedBox(height: 20),
            const Text('TOQUE PARA SELECIONAR',
                style: TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                    color: TabuColors.subtle)),
            const SizedBox(height: 8),
            const Text('foto ou vídeo',
                style: TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 12,
                    color: TabuColors.subtle)),
          ])));

  Widget _buildFotoPreview() => Container(
      height: 360,
      decoration: BoxDecoration(
          color: TabuColors.bgCard,
          border: Border.all(
              color: TabuColors.rosaPrincipal.withOpacity(0.4), width: 1)),
      child: Stack(fit: StackFit.expand, children: [
        Image.file(_foto!, fit: BoxFit.cover),
        Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _WatermarkPreviewBar(userName: _userName)),
        Positioned(
            top: 8,
            right: 8,
            child: Row(children: [
              _MiniBtn(icon: Icons.edit_outlined, onTap: _showMidiaSheet),
              const SizedBox(width: 6),
              _MiniBtn(
                  icon: Icons.close, onTap: () => setState(() => _foto = null)),
            ])),
      ]));

  Widget _buildVideoPreview() {
    if (_videoCtrl == null || !_videoCtrl!.value.isInitialized) {
      return Container(
          height: 360,
          color: Colors.black,
          child: const Center(
              child: CircularProgressIndicator(
                  color: TabuColors.rosaPrincipal, strokeWidth: 2)));
    }

    return GestureDetector(
        onTap: _toggleVideoPlay,
        child: Container(
            height: 360,
            decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(
                    color: TabuColors.rosaPrincipal.withOpacity(0.4),
                    width: 1)),
            child: Stack(fit: StackFit.expand, children: [
              ClipRect(
                  child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                          width: _videoCtrl!.value.size.width,
                          height: _videoCtrl!.value.size.height,
                          child: VideoPlayer(_videoCtrl!)))),

              Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _WatermarkPreviewBar(userName: _userName)),

              // Play overlay
              AnimatedOpacity(
                  opacity: _videoPlaying ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.5),
                          border: Border.all(
                              color: TabuColors.rosaPrincipal, width: 1.5)),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 32))),

              // Progress bar
              Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _VideoProgressBar(controller: _videoCtrl!)),

              // Duration badge
              if (_videoDuration != null)
                Positioned(
                    bottom: 8,
                    left: 10,
                    child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
                            border: Border.all(
                                color:
                                    TabuColors.rosaPrincipal.withOpacity(0.5),
                                width: 0.8)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.videocam_outlined,
                              color: TabuColors.rosaPrincipal, size: 11),
                          const SizedBox(width: 4),
                          Text('${_videoDuration!.inSeconds}s',
                              style: const TextStyle(
                                  fontFamily: TabuTypography.bodyFont,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                  color: TabuColors.branco)),
                        ]))),

              // Botões
              Positioned(
                  top: 8,
                  right: 8,
                  child: Row(children: [
                    _MiniBtn(icon: Icons.edit_outlined, onTap: _showMidiaSheet),
                    const SizedBox(width: 6),
                    _MiniBtn(icon: Icons.close, onTap: _removerVideo),
                  ])),
            ])));
  }

  Widget _buildPublicarBtn() {
    final can = _podePublicar;
    return Container(
        decoration: const BoxDecoration(
            color: TabuColors.bgAlt,
            border:
                Border(top: BorderSide(color: TabuColors.border, width: 0.5))),
        padding: EdgeInsets.fromLTRB(
            20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
        child: GestureDetector(
            onTap: can ? _publicar : null,
            child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                    color: _publishStep == _PublishStep.erro
                        ? const Color(0xFFE85D5D)
                        : can
                            ? TabuColors.rosaPrincipal
                            : TabuColors.bgCard,
                    border: Border.all(
                        color:
                            can ? TabuColors.rosaPrincipal : TabuColors.border,
                        width: 0.8),
                    boxShadow: can
                        ? [
                            BoxShadow(
                                color: TabuColors.glow.withOpacity(0.35),
                                blurRadius: 16,
                                spreadRadius: 1)
                          ]
                        : null),
                child: Center(
                    child: _publicando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: TabuColors.branco, strokeWidth: 2))
                        : _publishStep == _PublishStep.erro
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                    Icon(Icons.error_outline_rounded,
                                        color: Colors.white, size: 16),
                                    SizedBox(width: 8),
                                    Text('TENTAR NOVAMENTE',
                                        style: TextStyle(
                                            fontFamily: TabuTypography.bodyFont,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 2,
                                            color: Colors.white)),
                                  ])
                            : Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.add_photo_alternate_rounded,
                                    color: can
                                        ? TabuColors.branco
                                        : TabuColors.subtle,
                                    size: 16),
                                const SizedBox(width: 10),
                                Text('ADICIONAR À GALERIA',
                                    style: TextStyle(
                                        fontFamily: TabuTypography.bodyFont,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 2.5,
                                        color: can
                                            ? TabuColors.branco
                                            : TabuColors.subtle)),
                              ])))));
  }

  Widget _buildProgressOverlay() {
    final isCompress = _publishStep == _PublishStep.comprimindoVideo;
    final isMarca = _publishStep == _PublishStep.aplicandoMarca;
    final isMarcaVideo = _publishStep == _PublishStep.marcandoVideo;
    final progress = isCompress
        ? _compressProgress
        : ((isMarca || isMarcaVideo) ? null : _uploadProgress);

    final label = switch (_publishStep) {
      _PublishStep.aplicandoMarca => 'APLICANDO MARCA D\'ÁGUA...',
      _PublishStep.comprimindoVideo => 'COMPRIMINDO VÍDEO...',
      _PublishStep.marcandoVideo => 'GRAVANDO MARCA NO VÍDEO...',
      _PublishStep.uploadingMedia =>
        _video != null ? 'ENVIANDO VÍDEO...' : 'ENVIANDO FOTO...',
      _PublishStep.uploadingThumb => 'ENVIANDO CAPA...',
      _PublishStep.salvando => 'ADICIONANDO...',
      _ => 'AGUARDE...',
    };

    return Positioned.fill(
        child: Container(
            color: Colors.black.withOpacity(0.55),
            child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(alignment: Alignment.center, children: [
                    CircularProgressIndicator(
                        value: progress,
                        color: TabuColors.rosaPrincipal,
                        backgroundColor: Colors.white.withOpacity(0.1),
                        strokeWidth: 3),
                    if (progress != null && progress > 0)
                      Text('${(progress * 100).toInt()}%',
                          style: const TextStyle(
                              fontFamily: TabuTypography.bodyFont,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                  ])),
              const SizedBox(height: 20),
              Text(label,
                  style: const TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.5,
                      color: Colors.white)),
              if (_publishStep == _PublishStep.uploadingMedia &&
                  _video != null &&
                  _videoTamanhoComprimido != null) ...[
                const SizedBox(height: 10),
                Text(
                    '${_videoTamanhoOriginal ?? '?'} → $_videoTamanhoComprimido',
                    style: const TextStyle(
                        fontFamily: TabuTypography.bodyFont,
                        fontSize: 10,
                        color: TabuColors.subtle,
                        letterSpacing: 1)),
              ],
            ]))));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  WIDGETS AUXILIARES
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
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.55)])),
        child: Row(children: [
          Container(
              width: 1.5, height: 16, color: Colors.white.withOpacity(0.9)),
          const SizedBox(width: 7),
          const Text('TABU',
              style: TextStyle(
                  fontFamily: TabuTypography.displayFont,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                  color: Colors.white)),
          Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.symmetric(horizontal: 7),
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: TabuColors.rosaClaro.withOpacity(0.85))),
          Text('@${userName.toLowerCase()}',
              style: TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.85))),
          const Spacer(),
          Text('GALERIA',
              style: TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: TabuColors.rosaClaro.withOpacity(0.9))),
        ]));
  }
}

class _VideoProgressBar extends StatefulWidget {
  final VideoPlayerController controller;
  const _VideoProgressBar({required this.controller});
  @override
  State<_VideoProgressBar> createState() => _VideoProgressBarState();
}

class _VideoProgressBarState extends State<_VideoProgressBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_u);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_u);
    super.dispose();
  }

  void _u() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pos = widget.controller.value.position.inMilliseconds.toDouble();
    final total = widget.controller.value.duration.inMilliseconds.toDouble();
    final pct = total > 0 ? (pos / total).clamp(0.0, 1.0) : 0.0;
    return Container(
        height: 3,
        color: Colors.white.withOpacity(0.15),
        child: FractionallySizedBox(
            widthFactor: pct,
            alignment: Alignment.centerLeft,
            child: Container(
                decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [
              TabuColors.rosaDeep,
              TabuColors.rosaPrincipal
            ])))));
  }
}

class _MiniBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MiniBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.65),
              border: Border.all(color: TabuColors.borderMid, width: 0.8)),
          child: Icon(icon, color: TabuColors.branco, size: 15)));
}

class _SheetTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final VoidCallback onTap;

  const _SheetTile({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
        onTap: onTap,
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Row(children: [
              Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                      color: TabuColors.branco.withOpacity(0.1),
                      border: Border.all(
                          color: TabuColors.branco.withOpacity(0.3),
                          width: 0.8)),
                  child: Icon(icon, color: TabuColors.branco, size: 18)),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label,
                    style: const TextStyle(
                        fontFamily: TabuTypography.bodyFont,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: TabuColors.branco)),
                Text(sublabel,
                    style: const TextStyle(
                        fontFamily: TabuTypography.bodyFont,
                        fontSize: 10,
                        letterSpacing: 0.5,
                        color: TabuColors.subtle)),
              ]),
            ])));
  }
}

class _Bg extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = TabuColors.bg);
    canvas.drawCircle(
        Offset(size.width * 0.9, size.height * 0.04),
        size.width * 0.6,
        Paint()
          ..shader = RadialGradient(colors: [
            TabuColors.rosaPrincipal.withOpacity(0.06),
            Colors.transparent
          ]).createShader(Rect.fromCircle(
              center: Offset(size.width * 0.9, size.height * 0.04),
              radius: size.width * 0.6)));
  }

  @override
  bool shouldRepaint(_Bg old) => false;
}
