// lib/screens/screens_auth/location_permission_screen/location_permission_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';

// ── Etapas do fluxo ──────────────────────────────────────────────────────────
enum _Step { location, camera, notifications, gallery }

// ── Estado de cada permissão ─────────────────────────────────────────────────
enum _PermState { initial, requesting, granted, denied, deniedForever }

class LocationPermissionScreen extends StatefulWidget {
  final VoidCallback onContinue;
  const LocationPermissionScreen({super.key, required this.onContinue});

  @override
  State<LocationPermissionScreen> createState() =>
      _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends State<LocationPermissionScreen>
    with SingleTickerProviderStateMixin {

  _Step      _step  = _Step.location;
  _PermState _state = _PermState.initial;

  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.88, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _checkExisting();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Verifica permissões já concedidas ────────────────────────────────────
  Future<void> _checkExisting() async {
    // Localização
    final locPerm = await Geolocator.checkPermission();
    final locOk   = locPerm == LocationPermission.always ||
                    locPerm == LocationPermission.whileInUse;

    if (!locOk) return; // mostra tela de localização

    // Câmera + microfone
    final camOk = await Permission.camera.isGranted;
    final micOk = await Permission.microphone.isGranted;

    if (!camOk || !micOk) {
      if (mounted) setState(() { _step = _Step.camera; _state = _PermState.initial; });
      return;
    }

    // Notificações
    final notifOk = await Permission.notification.isGranted;
    if (!notifOk) {
      if (mounted) setState(() { _step = _Step.notifications; _state = _PermState.initial; });
      return;
    }

    // Galeria (fotos e vídeos)
    final galleryOk = await _isGalleryGranted();
    if (!galleryOk) {
      if (mounted) setState(() { _step = _Step.gallery; _state = _PermState.initial; });
      return;
    }

    widget.onContinue();
  }

  /// Retorna true se as permissões de galeria estiverem concedidas.
  /// No Android 13+ usa [Permission.photos] e [Permission.videos];
  /// em versões anteriores usa [Permission.storage].
  Future<bool> _isGalleryGranted() async {
    // Android 13+ (API 33+) expõe permissões granulares
    final photosStatus = await Permission.photos.status;
    if (photosStatus != PermissionStatus.permanentlyDenied &&
        photosStatus != PermissionStatus.denied) {
      // API granular disponível — checa vídeos também
      final videosStatus = await Permission.videos.status;
      return photosStatus.isGranted && videosStatus.isGranted;
    }
    // Fallback: Android < 13 usa READ_EXTERNAL_STORAGE
    return (await Permission.storage.status).isGranted;
  }

  // ── Pede permissão conforme etapa atual ──────────────────────────────────
  Future<void> _pedirPermissao() async {
    HapticFeedback.mediumImpact();
    setState(() => _state = _PermState.requesting);

    switch (_step) {
      case _Step.location:       await _pedirLocalizacao();      break;
      case _Step.camera:         await _pedirCamera();           break;
      case _Step.notifications:  await _pedirNotificacoes();     break;
      case _Step.gallery:        await _pedirGaleria();          break;
    }
  }

  Future<void> _pedirLocalizacao() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _state = _PermState.denied);
        return;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (!mounted) return;

      if (perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse) {
        setState(() => _state = _PermState.granted);
        await Future.delayed(const Duration(milliseconds: 700));
        if (mounted) setState(() { _step = _Step.camera; _state = _PermState.initial; });
      } else if (perm == LocationPermission.deniedForever) {
        setState(() => _state = _PermState.deniedForever);
      } else {
        setState(() => _state = _PermState.denied);
      }
    } catch (_) {
      if (mounted) setState(() => _state = _PermState.denied);
    }
  }

  Future<void> _pedirCamera() async {
    try {
      final results = await [
        Permission.camera,
        Permission.microphone,
      ].request();

      if (!mounted) return;

      final camStatus = results[Permission.camera]!;
      final micStatus = results[Permission.microphone]!;

      final granted = camStatus.isGranted && micStatus.isGranted;
      final forever = camStatus.isPermanentlyDenied || micStatus.isPermanentlyDenied;

      if (granted) {
        setState(() => _state = _PermState.granted);
        await Future.delayed(const Duration(milliseconds: 700));
        if (mounted) setState(() { _step = _Step.notifications; _state = _PermState.initial; });
      } else if (forever) {
        setState(() => _state = _PermState.deniedForever);
      } else {
        setState(() => _state = _PermState.denied);
      }
    } catch (_) {
      if (mounted) setState(() => _state = _PermState.denied);
    }
  }

  Future<void> _pedirNotificacoes() async {
    try {
      final status = await Permission.notification.request();
      if (!mounted) return;

      if (status.isGranted) {
        setState(() => _state = _PermState.granted);
        await Future.delayed(const Duration(milliseconds: 700));
        if (mounted) setState(() { _step = _Step.gallery; _state = _PermState.initial; });
      } else if (status.isPermanentlyDenied) {
        setState(() => _state = _PermState.deniedForever);
      } else {
        setState(() => _state = _PermState.denied);
      }
    } catch (_) {
      if (mounted) setState(() => _state = _PermState.denied);
    }
  }

  Future<void> _pedirGaleria() async {
    try {
      // Tenta primeiro as permissões granulares do Android 13+
      final results = await [
        Permission.photos,
        Permission.videos,
      ].request();

      if (!mounted) return;

      final photosStatus = results[Permission.photos]!;
      final videosStatus = results[Permission.videos]!;

      // Se ambas as permissões granulares forem concedidas
      if (photosStatus.isGranted && videosStatus.isGranted) {
        _onGalleryGranted();
        return;
      }

      // Se a API granular não está disponível (Android < 13), 
      // o sistema retorna permanentlyDenied — tenta READ_EXTERNAL_STORAGE
      if (photosStatus.isPermanentlyDenied || videosStatus.isPermanentlyDenied) {
        // Verifica se é porque o sistema usa a permissão legada
        final storageStatus = await Permission.storage.request();
        if (!mounted) return;
        if (storageStatus.isGranted) {
          _onGalleryGranted();
          return;
        } else if (storageStatus.isPermanentlyDenied) {
          setState(() => _state = _PermState.deniedForever);
          return;
        }
      }

      // Denied em alguma das granulares mas não permanente
      final anythingForever = photosStatus.isPermanentlyDenied ||
          videosStatus.isPermanentlyDenied;
      setState(() =>
          _state = anythingForever ? _PermState.deniedForever : _PermState.denied);
    } catch (_) {
      if (mounted) setState(() => _state = _PermState.denied);
    }
  }

  void _onGalleryGranted() {
    setState(() => _state = _PermState.granted);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) widget.onContinue();
    });
  }

  Future<void> _abrirConfiguracoes() async {
    HapticFeedback.selectionClick();
    if (_step == _Step.location) {
      await Geolocator.openAppSettings();
    } else {
      await openAppSettings();
    }
    if (mounted) {
      setState(() => _state = _PermState.initial);
      await _checkExisting();
    }
  }

  // ── Pular etapa ──────────────────────────────────────────────────────────
  void _pularEtapa() {
    setState(() {
      _state = _PermState.initial;
      switch (_step) {
        case _Step.location:
          _step = _Step.camera;
          break;
        case _Step.camera:
          _step = _Step.notifications;
          break;
        case _Step.notifications:
          _step = _Step.gallery;
          break;
        case _Step.gallery:
          widget.onContinue();
          break;
      }
    });
    // Se pular a última etapa, o setState acima já chamou onContinue
  }

  // ── Indicador de progresso ───────────────────────────────────────────────
  Widget _buildStepIndicator() {
    final steps = _Step.values;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) return const SizedBox(width: 8);
        final stepIndex = i ~/ 2;
        final s = steps[stepIndex];
        return _StepDot(
          active: _step == s,
          done: _step.index > s.index,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: TabuColors.bg,
        body: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: _LocBg())),
          Positioned(top: 0, left: 0, right: 0,
            child: Container(height: 2,
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [
                Colors.transparent,
                TabuColors.rosaDeep, TabuColors.rosaPrincipal,
                TabuColors.rosaClaro,
                TabuColors.rosaPrincipal, TabuColors.rosaDeep,
                Colors.transparent,
              ])))),
          SafeArea(child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
            child: Column(children: [
              const SizedBox(height: 24),
              _buildStepIndicator(),
              const Spacer(flex: 2),

              // Ícone pulsante
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) => Transform.scale(
                  scale: _state == _PermState.requesting ? 1.0 : _pulseAnim.value,
                  child: _buildIcon())),

              const SizedBox(height: 44),

              // Título
              ShaderMask(
                shaderCallback: (b) => LinearGradient(colors: [
                  _titleColor, _titleColor.withOpacity(0.8),
                ]).createShader(b),
                child: Text(_titulo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: TabuTypography.displayFont,
                    fontSize: 28, letterSpacing: 5,
                    color: Colors.white))),

              const SizedBox(height: 16),

              Text(_descricao,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 14, letterSpacing: 0.3,
                  color: TabuColors.dim.withOpacity(0.85),
                  height: 1.65)),

              const SizedBox(height: 36),

              // Benefícios — só no estado inicial
              if (_state == _PermState.initial) ..._buildBeneficios(),

              const Spacer(),

              _buildBotaoPrincipal(),
              const SizedBox(height: 12),
              _buildBotaoSecundario(),
            ]))),
        ])));
  }

  // ── Benefícios conforme etapa ────────────────────────────────────────────
  List<Widget> _buildBeneficios() {
    switch (_step) {
      case _Step.location:
        return [
          _Beneficio(
            icon: Icons.local_fire_department_rounded,
            titulo: 'Festas próximas primeiro',
            subtitulo: 'Os eventos mais perto de você aparecem no topo do feed'),
          const SizedBox(height: 14),
          _Beneficio(
            icon: Icons.people_rounded,
            titulo: 'Conecte com quem está perto',
            subtitulo: 'Descubra pessoas da mesma cena e cidade que você'),
          const SizedBox(height: 14),
          _Beneficio(
            icon: Icons.lock_outline_rounded,
            titulo: 'Localização privada',
            subtitulo: 'Nunca compartilhamos sua posição com outros usuários'),
        ];
      case _Step.camera:
        return [
          _Beneficio(
            icon: Icons.videocam_rounded,
            titulo: 'Grave e publique vídeos',
            subtitulo: 'Compartilhe momentos das festas direto pelo app'),
          const SizedBox(height: 14),
          _Beneficio(
            icon: Icons.mic_rounded,
            titulo: 'Áudio nítido',
            subtitulo: 'Microfone para captar o som ambiente nos seus vídeos'),
          const SizedBox(height: 14),
          _Beneficio(
            icon: Icons.no_photography_rounded,
            titulo: 'Você tem o controle',
            subtitulo: 'A câmera só é usada quando você escolhe gravar'),
        ];
      case _Step.notifications:
        return [
          _Beneficio(
            icon: Icons.campaign_rounded,
            titulo: 'Festas em tempo real',
            subtitulo: 'Saiba na hora quando uma festa próxima começar'),
          const SizedBox(height: 14),
          _Beneficio(
            icon: Icons.favorite_rounded,
            titulo: 'Fique por dentro',
            subtitulo: 'Receba curtidas, comentários e novos seguidores'),
          const SizedBox(height: 14),
          _Beneficio(
            icon: Icons.notifications_off_rounded,
            titulo: 'Sem spam',
            subtitulo: 'Você controla o que quer receber nas configurações'),
        ];
      case _Step.gallery:
        return [
          _Beneficio(
            icon: Icons.photo_library_rounded,
            titulo: 'Publique da galeria',
            subtitulo: 'Escolha fotos e vídeos salvos para postar no TABU'),
          const SizedBox(height: 14),
          _Beneficio(
            icon: Icons.video_library_rounded,
            titulo: 'Vídeos em alta qualidade',
            subtitulo: 'Envie diretamente do seu rolo sem perder qualidade'),
          const SizedBox(height: 14),
          _Beneficio(
            icon: Icons.security_rounded,
            titulo: 'Acesso somente quando você pede',
            subtitulo: 'Não lemos nem armazenamos nada da sua galeria'),
        ];
    }
  }

  // ── Icon ─────────────────────────────────────────────────────────────────
  Widget _buildIcon() {
    return Container(
      width: 96, height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _iconColor.withOpacity(0.1),
        border: Border.all(color: _iconColor.withOpacity(0.3), width: 1.5),
        boxShadow: [BoxShadow(
            color: _iconColor.withOpacity(0.28), blurRadius: 36, spreadRadius: 4)]),
      child: _state == _PermState.requesting
          ? Center(child: SizedBox(width: 26, height: 26,
              child: CircularProgressIndicator(color: _iconColor, strokeWidth: 2)))
          : Icon(_iconData, color: _iconColor, size: 42));
  }

  Widget _buildBotaoPrincipal() {
    switch (_state) {
      case _PermState.deniedForever:
        return _Btn(label: 'ABRIR CONFIGURAÇÕES',
            icon: Icons.settings_rounded,
            onTap: _abrirConfiguracoes, accent: true);
      case _PermState.denied:
        return _Btn(label: 'TENTAR NOVAMENTE',
            icon: Icons.refresh_rounded,
            onTap: _pedirPermissao, accent: true);
      case _PermState.granted:
      case _PermState.requesting:
        return const SizedBox.shrink();
      default:
        return _Btn(
            label: _labelBotaoPrincipal,
            icon: _iconBotaoPrincipal,
            onTap: _pedirPermissao, accent: true);
    }
  }

  Widget _buildBotaoSecundario() {
    switch (_state) {
      case _PermState.granted:
      case _PermState.requesting:
        return const SizedBox.shrink();
      case _PermState.deniedForever:
        return _Btn(
            label: _labelPular,
            icon: null, onTap: _pularEtapa, accent: false);
      default:
        return _Btn(label: 'AGORA NÃO',
            icon: null, onTap: _pularEtapa, accent: false);
    }
  }

  // ── Labels dinâmicos ─────────────────────────────────────────────────────
  String get _labelBotaoPrincipal {
    switch (_step) {
      case _Step.location:      return 'PERMITIR LOCALIZAÇÃO';
      case _Step.camera:        return 'PERMITIR CÂMERA E MIC';
      case _Step.notifications: return 'PERMITIR NOTIFICAÇÕES';
      case _Step.gallery:       return 'PERMITIR GALERIA';
    }
  }

  IconData get _iconBotaoPrincipal {
    switch (_step) {
      case _Step.location:      return Icons.location_on_rounded;
      case _Step.camera:        return Icons.videocam_rounded;
      case _Step.notifications: return Icons.notifications_rounded;
      case _Step.gallery:       return Icons.photo_library_rounded;
    }
  }

  String get _labelPular {
    switch (_step) {
      case _Step.location:      return 'CONTINUAR SEM LOCALIZAÇÃO';
      case _Step.camera:        return 'CONTINUAR SEM CÂMERA';
      case _Step.notifications: return 'CONTINUAR SEM NOTIFICAÇÕES';
      case _Step.gallery:       return 'CONTINUAR SEM GALERIA';
    }
  }

  // ── Cores / ícones / textos ──────────────────────────────────────────────
  Color get _iconColor {
    switch (_state) {
      case _PermState.granted:        return const Color(0xFF4ECDC4);
      case _PermState.denied:
      case _PermState.deniedForever:  return const Color(0xFFE85D5D);
      default:                        return TabuColors.rosaPrincipal;
    }
  }

  Color get _titleColor => _iconColor;

  IconData get _iconData {
    switch (_state) {
      case _PermState.granted: return Icons.check_circle_rounded;
      case _PermState.denied:
      case _PermState.deniedForever:
        switch (_step) {
          case _Step.location:      return Icons.location_off_rounded;
          case _Step.camera:        return Icons.videocam_off_rounded;
          case _Step.notifications: return Icons.notifications_off_rounded;
          case _Step.gallery:       return Icons.no_photography_rounded;
        }
      default:
        switch (_step) {
          case _Step.location:      return Icons.location_on_rounded;
          case _Step.camera:        return Icons.videocam_rounded;
          case _Step.notifications: return Icons.notifications_rounded;
          case _Step.gallery:       return Icons.photo_library_rounded;
        }
    }
  }

  String get _titulo {
    switch (_state) {
      case _PermState.granted:        return 'PRONTO!';
      case _PermState.denied:         return 'NEGADO';
      case _PermState.deniedForever:  return 'BLOQUEADO';
      case _PermState.requesting:     return 'AGUARDE';
      default:
        switch (_step) {
          case _Step.location:      return 'LOCALIZAÇÃO';
          case _Step.camera:        return 'CÂMERA & MIC';
          case _Step.notifications: return 'NOTIFICAÇÕES';
          case _Step.gallery:       return 'GALERIA';
        }
    }
  }

  String get _descricao {
    switch (_state) {
      case _PermState.granted:
        switch (_step) {
          case _Step.location:
            return 'Localização ativada!\nAgora vamos ao vídeo...';
          case _Step.camera:
            return 'Câmera ativada.\nAgora as notificações...';
          case _Step.notifications:
            return 'Notificações ativadas!\nQuase lá...';
          case _Step.gallery:
            return 'Galeria liberada.\nEntrando no TABU...';
        }
      case _PermState.denied:
        switch (_step) {
          case _Step.location:
            return 'Sem localização você ainda\npode usar o app, mas não verá\nconteúdo próximo de você.';
          case _Step.camera:
            return 'Sem câmera você ainda pode\nusar o app, mas não poderá\ngravar vídeos.';
          case _Step.notifications:
            return 'Sem notificações você pode\nperder festas e interações\nem tempo real.';
          case _Step.gallery:
            return 'Sem acesso à galeria você\nnão poderá publicar fotos\ne vídeos salvos.';
        }
      case _PermState.deniedForever:
        return 'A permissão foi bloqueada.\nAbra as configurações para\nreativar e aproveitar tudo.';
      case _PermState.requesting:
        return 'Solicitando permissão...';
      default:
        switch (_step) {
          case _Step.location:
            return 'Usamos sua localização para\nmostrar festas e pessoas\npertinho de você.';
          case _Step.camera:
            return 'Usamos a câmera e microfone\npara você gravar e publicar\nvídeos no TABU.';
          case _Step.notifications:
            return 'Fique sabendo de festas,\ncurtidas e novidades assim\nque acontecerem.';
          case _Step.gallery:
            return 'Escolha fotos e vídeos da\nsua galeria para publicar\ndireto no TABU.';
        }
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Indicador de etapa
class _StepDot extends StatelessWidget {
  final bool active;
  final bool done;
  const _StepDot({required this.active, required this.done});

  @override
  Widget build(BuildContext context) {
    final color = (active || done)
        ? TabuColors.rosaPrincipal
        : TabuColors.border;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: active ? 24 : 8, height: 8,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
class _Beneficio extends StatelessWidget {
  final IconData icon;
  final String   titulo;
  final String   subtitulo;
  const _Beneficio({required this.icon, required this.titulo, required this.subtitulo});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: TabuColors.rosaPrincipal.withOpacity(0.1),
          border: Border.all(
              color: TabuColors.rosaPrincipal.withOpacity(0.25), width: 0.8)),
        child: Icon(icon, color: TabuColors.rosaPrincipal, size: 17)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titulo, style: const TextStyle(
            fontFamily: TabuTypography.bodyFont,
            fontSize: 13, fontWeight: FontWeight.w700,
            letterSpacing: 0.3, color: TabuColors.branco)),
        const SizedBox(height: 2),
        Text(subtitulo, style: TextStyle(
            fontFamily: TabuTypography.bodyFont,
            fontSize: 11, letterSpacing: 0.2,
            color: TabuColors.subtle.withOpacity(0.75))),
      ])),
    ]);
}

// ══════════════════════════════════════════════════════════════════════════════
class _Btn extends StatelessWidget {
  final String    label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool      accent;
  const _Btn({required this.label, required this.icon,
      required this.onTap, required this.accent});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity, height: 52,
      decoration: BoxDecoration(
        gradient: accent ? const LinearGradient(
            colors: [TabuColors.rosaDeep, TabuColors.rosaPrincipal],
            begin: Alignment.centerLeft, end: Alignment.centerRight)
            : null,
        border: Border.all(
          color: accent ? Colors.transparent : TabuColors.border, width: 0.8),
        boxShadow: accent ? [BoxShadow(
            color: TabuColors.glow.withOpacity(0.35),
            blurRadius: 20, offset: const Offset(0, 4))] : null),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (icon != null) ...[
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 10),
        ],
        Text(label, style: TextStyle(
            fontFamily: TabuTypography.bodyFont,
            fontSize: 11, fontWeight: FontWeight.w700,
            letterSpacing: 2.5,
            color: accent ? Colors.white : TabuColors.subtle)),
      ])));
}

// ══════════════════════════════════════════════════════════════════════════════
class _LocBg extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = TabuColors.bg);
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.38), size.width * 0.95,
      Paint()..shader = RadialGradient(colors: [
        TabuColors.rosaPrincipal.withOpacity(0.07), Colors.transparent,
      ]).createShader(Rect.fromCircle(
          center: Offset(size.width / 2, size.height * 0.38),
          radius: size.width * 0.95)));
  }
  @override
  bool shouldRepaint(_LocBg _) => false;
}