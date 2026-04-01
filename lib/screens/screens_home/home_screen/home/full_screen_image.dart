// lib/screens/screens_home/home_screen/home/full_screen_image.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  FULLSCREEN IMAGE SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class FullscreenImageScreen extends StatefulWidget {
  final String imageUrl;
  final String? userName;
  final String? titulo;

  const FullscreenImageScreen._({
    required this.imageUrl,
    this.userName,
    this.titulo,
  });

  static Route<void> route({
    required String imageUrl,
    String? userName,
    String? titulo,
  }) =>
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (_, __, ___) => FullscreenImageScreen._(
          imageUrl: imageUrl,
          userName: userName,
          titulo:   titulo,
        ),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 220),
      );

  @override
  State<FullscreenImageScreen> createState() => _FullscreenImageScreenState();
}

class _FullscreenImageScreenState extends State<FullscreenImageScreen>
    with SingleTickerProviderStateMixin {

  final TransformationController _transformCtrl = TransformationController();
  late AnimationController _resetAnimCtrl;
  Animation<Matrix4>? _resetAnim;

  bool _overlayVisible = true;
  bool _isLoading = true;
  bool _hasError  = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _resetAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..addListener(() {
        if (_resetAnim != null) _transformCtrl.value = _resetAnim!.value;
      });
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _transformCtrl.dispose();
    _resetAnimCtrl.dispose();
    super.dispose();
  }

  void _toggleOverlay() {
    HapticFeedback.selectionClick();
    setState(() => _overlayVisible = !_overlayVisible);
  }

  void _onDoubleTapDown(TapDownDetails details) {
    final isZoomed = _transformCtrl.value.getMaxScaleOnAxis() > 1.01;
    if (isZoomed) {
      _resetAnim = Matrix4Tween(
        begin: _transformCtrl.value,
        end:   Matrix4.identity(),
      ).animate(CurvedAnimation(parent: _resetAnimCtrl, curve: Curves.easeOutCubic));
    } else {
      final pos   = details.localPosition;
      const scale = 2.5;
      final x     = -pos.dx * (scale - 1);
      final y     = -pos.dy * (scale - 1);
      final target = Matrix4.identity()
        ..translate(x, y)
        ..scale(scale);
      _resetAnim = Matrix4Tween(
        begin: _transformCtrl.value,
        end:   target,
      ).animate(CurvedAnimation(parent: _resetAnimCtrl, curve: Curves.easeOutCubic));
    }
    _resetAnimCtrl.forward(from: 0);
  }

  void _close() {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final botPad = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _toggleOverlay,
          onDoubleTapDown: _onDoubleTapDown,
          onDoubleTap: () {},
          child: Stack(
            fit: StackFit.expand,
            children: [

              // ── Imagem com zoom / pan ────────────────────────────────
              InteractiveViewer(
                transformationController: _transformCtrl,
                minScale: 0.8,
                maxScale: 5.0,
                clipBehavior: Clip.none,
                child: Center(
                  child: Image.network(
                    widget.imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && _isLoading) setState(() => _isLoading = false);
                        });
                        return child;
                      }
                      return const SizedBox.shrink();
                    },
                    errorBuilder: (_, __, ___) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() { _isLoading = false; _hasError = true; });
                      });
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),

              // ── Loading ──────────────────────────────────────────────
              if (_isLoading && !_hasError)
                const Center(
                  child: SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(
                        color: TabuColors.rosaPrincipal, strokeWidth: 1.5)),
                ),

              // ── Erro ─────────────────────────────────────────────────
              if (_hasError)
                Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: const [
                    Icon(Icons.broken_image_outlined,
                        color: TabuColors.subtle, size: 48),
                    SizedBox(height: 12),
                    Text('Não foi possível carregar a imagem',
                        style: TextStyle(fontFamily: TabuTypography.bodyFont,
                            fontSize: 13, color: TabuColors.subtle)),
                  ]),
                ),

              // ── Gradiente decorativo atrás do header (IgnorePointer) ─
              Positioned(
                top: 0, left: 0, right: 0,
                height: topPad + 110,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _overlayVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 220),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.black87, Colors.transparent],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Barra de acento rosa ─────────────────────────────────
              Positioned(
                top: 0, left: 0, right: 0,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _overlayVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 220),
                    child: Container(
                      height: 2,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [
                          Colors.transparent,
                          TabuColors.rosaDeep,
                          TabuColors.rosaPrincipal,
                          TabuColors.rosaClaro,
                          TabuColors.rosaPrincipal,
                          TabuColors.rosaDeep,
                          Colors.transparent,
                        ]),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Header: voltar | nome + título | badge FOTO ──────────
              // Posicionado abaixo da status bar com topPad
              Positioned(
                top: topPad + 10,
                left: 16,
                right: 16,
                child: AnimatedOpacity(
                  opacity: _overlayVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 220),
                  child: IgnorePointer(
                    ignoring: !_overlayVisible,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [

                        // Botão voltar
                        GestureDetector(
                          onTap: _close,
                          child: Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.15),
                                  width: 0.8)),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Nome + título
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.userName != null &&
                                  widget.userName!.isNotEmpty)
                                Text(
                                  widget.userName!.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: TabuTypography.bodyFont,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 2,
                                    color: Colors.white,
                                  ),
                                ),
                              if (widget.titulo != null &&
                                  widget.titulo!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  widget.titulo!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: TabuTypography.bodyFont,
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.65),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Badge FOTO
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.12),
                                width: 0.5)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.photo_rounded,
                                  color: Colors.white54, size: 10),
                              SizedBox(width: 4),
                              Text('FOTO', style: TextStyle(
                                  fontFamily: TabuTypography.bodyFont,
                                  fontSize: 8,
                                  letterSpacing: 1.5,
                                  color: Colors.white54)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Hint zoom na parte inferior ──────────────────────────
              if (!_isLoading && !_hasError)
                Positioned(
                  bottom: botPad + 20,
                  left: 0, right: 0,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _overlayVisible ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 220),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                                width: 0.5)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.zoom_in_rounded,
                                  color: Colors.white38, size: 12),
                              SizedBox(width: 6),
                              Text('Toque duplo para zoom',
                                  style: TextStyle(
                                      fontFamily: TabuTypography.bodyFont,
                                      fontSize: 10,
                                      letterSpacing: 1,
                                      color: Colors.white38)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

            ],
          ),
        ),
      ),
    );
  }
}