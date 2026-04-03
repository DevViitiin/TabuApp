// lib/screens/screens_administrative/home_screen/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/models/party_model.dart';
import 'package:tabuapp/screens/screens_home/home_screen/posts/create_gallery_screen.dart';
import 'package:tabuapp/services/services_administrative/location_service.dart';
import 'package:tabuapp/services/services_administrative/party_service.dart';
import 'package:tabuapp/services/services_app/cached_avatar.dart';
import 'package:tabuapp/services/services_app/user_data_notifier.dart';
import 'package:tabuapp/screens/screens_administrative/home_screen/create_party_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../screens_home/home_screen/home/edit_party_screen.dart';

class HomeScreenAdministrative extends StatefulWidget {
  final Map<String, dynamic> userData;
  const HomeScreenAdministrative({super.key, required this.userData});

  @override
  State<HomeScreenAdministrative> createState() => _HomeScreenAdministrativeState();
}

class _HomeScreenAdministrativeState extends State<HomeScreenAdministrative> {
  List<PartyModel> _festas  = [];
  bool             _loading = true;

  
  /// Coordenadas de moradia do usuário admin (Users/$uid/latitude + longitude).
  ({double latitude, double longitude})? _homeCoords;

  String get _uid =>
      FirebaseAuth.instance.currentUser?.uid
      ?? widget.userData['uid'] as String? ?? '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final results = await Future.wait([
      LocationService.instance.getUserHomeCoords(_uid),
      PartyService.instance.fetchFestas(),
    ]);

    if (!mounted) return;
    setState(() {
      _homeCoords = results[0] as ({double latitude, double longitude})?;
      _festas     = results[1] as List<PartyModel>;
      _loading    = false;
    });
  }

  Future<void> _carregarFestas() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        LocationService.instance.getUserHomeCoords(_uid),
        PartyService.instance.fetchFestas(),
      ]);
      if (mounted) setState(() {
        _homeCoords = results[0] as ({double latitude, double longitude})?;
        _festas     = results[1] as List<PartyModel>;
        _loading    = false;
      });
    } catch (e) {
      debugPrint('_carregarFestas error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _criarFesta() {
    HapticFeedback.selectionClick();
    Navigator.push(context, PageRouteBuilder(
      pageBuilder: (_, animation, __) => CreatePartyScreen(userData: widget.userData),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child),
      transitionDuration: const Duration(milliseconds: 250),
    )).then((ok) { if (ok == true) _carregarFestas(); });
  }

  void _abrirDetalhe(PartyModel festa) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withOpacity(0.8),
        builder: (_) => _FestaDetalheSheet(
            festa: festa,
            uid: _uid,
            userData: widget.userData,
            homeCoords: _homeCoords,
            onRefresh: _carregarFestas));
  }

  @override
  Widget build(BuildContext context) {
    final name = UserDataNotifier.instance.nameUpper.isNotEmpty
        ? UserDataNotifier.instance.nameUpper
        : (widget.userData['name'] as String? ?? '').toUpperCase();

    return Scaffold(
        backgroundColor: TabuColors.bg,
        body: Stack(children: [

          Positioned.fill(child: CustomPaint(painter: _AdmBg())),

          Positioned(top: 0, left: 0, right: 0,
              child: Container(height: 3,
                  decoration: const BoxDecoration(gradient: LinearGradient(colors: [
                    TabuColors.rosaDeep, TabuColors.rosaPrincipal,
                    TabuColors.rosaClaro, TabuColors.rosaPrincipal, TabuColors.rosaDeep,
                  ])))),

          SafeArea(child: RefreshIndicator(
            color: TabuColors.rosaPrincipal,
            backgroundColor: TabuColors.bgAlt,
            onRefresh: _carregarFestas,
            child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [

                  SliverToBoxAdapter(child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 16, 8),
                      child: Row(children: [
                        ShaderMask(
                            shaderCallback: (b) => const LinearGradient(
                                colors: [TabuColors.rosaPrincipal, TabuColors.rosaClaro])
                                .createShader(b),
                            child: const Text('FESTAS',
                                style: TextStyle(fontFamily: TabuTypography.displayFont,
                                    fontSize: 28, letterSpacing: 6, color: Colors.white))),
                        const SizedBox(width: 10),
                        Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: TabuColors.rosaPrincipal.withOpacity(0.15),
                                border: Border.all(
                                    color: TabuColors.rosaPrincipal.withOpacity(0.4), width: 0.7)),
                            child: const Text('ADMIN',
                                style: TextStyle(fontFamily: TabuTypography.bodyFont,
                                    fontSize: 8, fontWeight: FontWeight.w700,
                                    letterSpacing: 2, color: TabuColors.rosaPrincipal))),
                        const Spacer(),
                        CachedAvatar(uid: _uid, name: name, size: 36, radius: 8, isOwn: true),
                      ]))),

                  SliverToBoxAdapter(child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                      child: Row(children: [
                        Container(width: 5, height: 5,
                            decoration: const BoxDecoration(
                                color: TabuColors.rosaPrincipal, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text(_loading ? 'CARREGANDO...' : '${_festas.length} FESTAS ATIVAS',
                            style: const TextStyle(fontFamily: TabuTypography.bodyFont,
                                fontSize: 9, fontWeight: FontWeight.w700,
                                letterSpacing: 3, color: TabuColors.rosaPrincipal)),
                        const SizedBox(width: 12),
                        Expanded(child: Container(height: 0.5, color: TabuColors.border)),
                      ]))),

                  if (_loading)
                    const SliverToBoxAdapter(child: _FestaSkeleton())
                  else if (_festas.isEmpty)
                    SliverFillRemaining(hasScrollBody: false,
                        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Container(width: 56, height: 56,
                              decoration: BoxDecoration(color: TabuColors.bgCard,
                                  border: Border.all(color: TabuColors.border, width: 0.8)),
                              child: const Icon(Icons.local_fire_department_outlined,
                                  color: TabuColors.border, size: 24)),
                          const SizedBox(height: 16),
                          const Text('NENHUMA FESTA CRIADA',
                              style: TextStyle(fontFamily: TabuTypography.bodyFont,
                                  fontSize: 9, fontWeight: FontWeight.w700,
                                  letterSpacing: 3, color: TabuColors.subtle)),
                          const SizedBox(height: 8),
                          const Text('Toque em CRIAR FESTA para começar',
                              style: TextStyle(fontFamily: TabuTypography.bodyFont,
                                  fontSize: 11, color: TabuColors.subtle)),
                        ])))
                  else
                    SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        sliver: SliverList(delegate: SliverChildBuilderDelegate(
                            (_, i) => _FestaListTile(
                                festa: _festas[i],
                                homeCoords: _homeCoords,
                                onTap: () => _abrirDetalhe(_festas[i])),
                            childCount: _festas.length))),
                ]),
          )),

          // FABs com animação e ícones diferentes
Positioned(
  bottom: 24,
  right: 20,
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      // GALERIA - ÍCONE GRID
      GestureDetector(
        onTap: () {
          
        },
        child: Hero(
          tag: 'fab_gallery',
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [TabuColors.rosaDeep, TabuColors.rosaPrincipal],
              ),
              boxShadow: [
                BoxShadow(
                  color: TabuColors.glow.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.grid_view_rounded, // ÍCONE MAIS ESPECÍFICO
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      // FESTA - ÍCONE FOGO COM GRADIENTE
      GestureDetector(
        onTap: _criarFesta,
        child: Hero(
          tag: 'fab_party',
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFF6B6B), TabuColors.rosaPrincipal],
              ),
              boxShadow: [
                BoxShadow(
                  color: TabuColors.glow.withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    ],
  ),
),
        ]));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  FESTA LIST TILE — distância da MORADIA até a festa
// ══════════════════════════════════════════════════════════════════════════════
class _FestaListTile extends StatelessWidget {
  final PartyModel festa;
  final ({double latitude, double longitude})? homeCoords;
  final VoidCallback onTap;

  const _FestaListTile({
    required this.festa,
    required this.homeCoords,
    required this.onTap,
  });

  String? get _distLabel {
    if (homeCoords == null || !festa.hasCoords) return null;
    final km = LocationService.distanceKm(
        homeCoords!.latitude, homeCoords!.longitude,
        festa.latitude!, festa.longitude!);
    return LocationService.formatDistance(km);
  }

  @override
  Widget build(BuildContext context) {
    final temBanner = festa.bannerUrl != null && festa.bannerUrl!.isNotEmpty;
    final dist      = _distLabel;

    return GestureDetector(
        onTap: onTap,
        child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 120,
            decoration: BoxDecoration(
                color: TabuColors.bgCard,
                border: Border.all(color: TabuColors.borderMid, width: 0.8)),
            child: Row(children: [
              SizedBox(width: 100, height: 120,
                  child: temBanner
                      ? Image.network(festa.bannerUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _bg())
                      : _bg()),

              Expanded(child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                color: TabuColors.rosaPrincipal,
                                child: Text(_fd(festa.dataInicio),
                                    style: const TextStyle(fontFamily: TabuTypography.bodyFont,
                                        fontSize: 7, fontWeight: FontWeight.w700,
                                        letterSpacing: 1.5, color: Colors.white))),

                            if (dist != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: TabuColors.rosaPrincipal.withOpacity(0.12),
                                      border: Border.all(
                                          color: TabuColors.rosaPrincipal.withOpacity(0.4),
                                          width: 0.7)),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    const Icon(Icons.near_me_rounded,
                                        color: TabuColors.rosaPrincipal, size: 8),
                                    const SizedBox(width: 3),
                                    Text(dist,
                                        style: const TextStyle(fontFamily: TabuTypography.bodyFont,
                                            fontSize: 7, fontWeight: FontWeight.w700,
                                            letterSpacing: 1, color: TabuColors.rosaPrincipal)),
                                  ])),
                            ],
                          ]),

                          const SizedBox(height: 5),
                          Text(festa.nome.toUpperCase(),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontFamily: TabuTypography.displayFont,
                                  fontSize: 15, letterSpacing: 1.5, color: TabuColors.branco)),
                          const SizedBox(height: 3),
                          Row(children: [
                            const Icon(Icons.location_on_outlined,
                                color: TabuColors.subtle, size: 10),
                            const SizedBox(width: 3),
                            Expanded(child: Text(festa.hasLocal
                                    ? festa.local!
                                    : 'Local não confirmado',
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontFamily: TabuTypography.bodyFont,
                                    fontSize: 10, color: TabuColors.subtle))),
                          ]),
                        ]),

                        Row(children: [
                          _Chip(Icons.star_outline_rounded, festa.interessados),
                          const SizedBox(width: 10),
                          _Chip(Icons.check_circle_outline_rounded, festa.confirmados),
                          const SizedBox(width: 10),
                          _Chip(Icons.chat_bubble_outline_rounded, festa.commentCount),
                          const Spacer(),
                          const Icon(Icons.chevron_right_rounded,
                              color: TabuColors.subtle, size: 16),
                        ]),
                      ])),
              ),
            ])));
  }

  Widget _bg() => Container(decoration: const BoxDecoration(gradient: LinearGradient(
      colors: [Color(0xFF3D0018), Color(0xFF6B0030)],
      begin: Alignment.topLeft, end: Alignment.bottomRight)));

  String _fd(DateTime dt) {
    const m = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    return '${dt.day.toString().padLeft(2, '0')} ${m[dt.month - 1]}';
  }
}

class _Chip extends StatelessWidget {
  final IconData icon; final int count;
  const _Chip(this.icon, this.count);
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: TabuColors.subtle, size: 11),
        const SizedBox(width: 3),
        Text('$count', style: const TextStyle(fontFamily: TabuTypography.bodyFont,
            fontSize: 9, color: TabuColors.subtle)),
      ]);
}

// ══════════════════════════════════════════════════════════════════════════════
//  DETALHE SHEET — com botões EDITAR + EXCLUIR
// ══════════════════════════════════════════════════════════════════════════════
class _FestaDetalheSheet extends StatelessWidget {
  final PartyModel festa;
  final String     uid;
  final Map<String, dynamic> userData;
  final ({double latitude, double longitude})? homeCoords;
  final VoidCallback onRefresh;

  const _FestaDetalheSheet({
    required this.festa,
    required this.uid,
    required this.userData,
    required this.homeCoords,
    required this.onRefresh,
  });

  String? get _distLabel {
    if (homeCoords == null || !festa.hasCoords) return null;
    final km = LocationService.distanceKm(
        homeCoords!.latitude, homeCoords!.longitude,
        festa.latitude!, festa.longitude!);
    return LocationService.formatDistance(km);
  }

  @override
  Widget build(BuildContext context) {
    final temBanner = festa.bannerUrl != null && festa.bannerUrl!.isNotEmpty;
    final dist      = _distLabel;

    return DraggableScrollableSheet(
        initialChildSize: 0.75, maxChildSize: 0.95, minChildSize: 0.4,
        builder: (_, ctrl) => Container(
            decoration: const BoxDecoration(
                color: TabuColors.bgAlt,
                border: Border(top: BorderSide(color: TabuColors.rosaPrincipal, width: 1.5))),
            child: ListView(controller: ctrl, children: [
              Container(width: 36, height: 3,
                  margin: const EdgeInsets.only(top: 12),
                  alignment: Alignment.center,
                  child: Container(width: 36, height: 3,
                      decoration: BoxDecoration(color: TabuColors.border,
                          borderRadius: BorderRadius.circular(2)))),

              if (temBanner)
                SizedBox(height: 180,
                    child: Image.network(festa.bannerUrl!, fit: BoxFit.cover)),

              Padding(padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(festa.nome.toUpperCase(),
                        style: const TextStyle(fontFamily: TabuTypography.displayFont,
                            fontSize: 24, letterSpacing: 3, color: TabuColors.branco)),

                    const SizedBox(height: 10),

                    // Localização + badge de distância
                    Row(children: [
                      const Icon(Icons.location_on_outlined,
                          color: TabuColors.rosaPrincipal, size: 13),
                      const SizedBox(width: 5),
                      Expanded(child: Text(festa.hasLocal
                                  ? festa.local!
                                  : 'Local não confirmado',
                          style: const TextStyle(fontFamily: TabuTypography.bodyFont,
                              fontSize: 13, color: TabuColors.rosaClaro))),
                      if (dist != null) ...[
                        const SizedBox(width: 8),
                        Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                color: TabuColors.rosaPrincipal.withOpacity(0.12),
                                border: Border.all(
                                    color: TabuColors.rosaPrincipal.withOpacity(0.5), width: 0.8)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.near_me_rounded,
                                  color: TabuColors.rosaPrincipal, size: 11),
                              const SizedBox(width: 4),
                              Text(dist,
                                  style: const TextStyle(fontFamily: TabuTypography.bodyFont,
                                      fontSize: 10, fontWeight: FontWeight.w700,
                                      letterSpacing: 1, color: TabuColors.rosaPrincipal)),
                            ])),
                      ],
                    ]),

                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.schedule_outlined, color: TabuColors.subtle, size: 13),
                      const SizedBox(width: 5),
                      Text('${_fh(festa.dataInicio)} – ${_fh(festa.dataFim)}',
                          style: const TextStyle(fontFamily: TabuTypography.bodyFont,
                              fontSize: 12, color: TabuColors.dim)),
                    ]),

                    if (festa.descricao.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(festa.descricao,
                          style: const TextStyle(fontFamily: TabuTypography.bodyFont,
                              fontSize: 14, color: TabuColors.dim, height: 1.6)),
                    ],

                    const SizedBox(height: 24),
                    Row(children: [
                      _StatBox('INTERESSADOS', festa.interessados,
                          Icons.star_rounded, TabuColors.rosaClaro),
                      const SizedBox(width: 10),
                      _StatBox('CONFIRMADOS', festa.confirmados,
                          Icons.check_circle_rounded, const Color(0xFF4ECDC4)),
                      const SizedBox(width: 10),
                      _StatBox('COMENTÁRIOS', festa.commentCount,
                          Icons.chat_bubble_rounded, TabuColors.rosaPrincipal),
                    ]),

                    const SizedBox(height: 24),

                    // ── Botões EDITAR + EXCLUIR ────────────────────────────
                    Row(children: [

                      // EDITAR
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            Navigator.pop(context);
                            final ok = await Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (_, animation, __) => EditPartyScreen(
                                  festa:    festa,
                                  userData: userData,
                                ),
                                transitionsBuilder: (_, animation, __, child) =>
                                    FadeTransition(
                                      opacity: CurvedAnimation(
                                          parent: animation, curve: Curves.easeOut),
                                      child: child,
                                    ),
                                transitionDuration: const Duration(milliseconds: 250),
                              ),
                            );
                            if (ok == true) onRefresh();
                          },
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                                color: TabuColors.bgCard,
                                border: Border.all(
                                    color: TabuColors.rosaPrincipal.withOpacity(0.5),
                                    width: 0.8)),
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              const Icon(Icons.edit_rounded,
                                  color: TabuColors.rosaPrincipal, size: 15),
                              const SizedBox(width: 8),
                              const Text('EDITAR',
                                  style: TextStyle(fontFamily: TabuTypography.bodyFont,
                                      fontSize: 11, fontWeight: FontWeight.w700,
                                      letterSpacing: 2.5, color: TabuColors.rosaPrincipal)),
                            ]),
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      // EXCLUIR
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            Navigator.pop(context);
                            await PartyService.instance.deleteFesta(festa.id);
                            onRefresh();
                          },
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                                color: const Color(0xFF3D0A0A),
                                border: Border.all(
                                    color: const Color(0xFFE85D5D).withOpacity(0.5),
                                    width: 0.8)),
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              const Icon(Icons.delete_outline_rounded,
                                  color: Color(0xFFE85D5D), size: 15),
                              const SizedBox(width: 8),
                              const Text('EXCLUIR',
                                  style: TextStyle(fontFamily: TabuTypography.bodyFont,
                                      fontSize: 11, fontWeight: FontWeight.w700,
                                      letterSpacing: 2.5, color: Color(0xFFE85D5D))),
                            ]),
                          ),
                        ),
                      ),

                    ]),
                  ])),
            ])));
  }

  String _fh(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _StatBox extends StatelessWidget {
  final String label; final int value; final IconData icon; final Color color;
  const _StatBox(this.label, this.value, this.icon, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          border: Border.all(color: color.withOpacity(0.3), width: 0.8)),
      child: Column(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 6),
        Text('$value', style: TextStyle(fontFamily: TabuTypography.displayFont,
            fontSize: 18, color: color)),
        Text(label, style: const TextStyle(fontFamily: TabuTypography.bodyFont,
            fontSize: 7, letterSpacing: 1.5, color: TabuColors.subtle)),
      ])));
}

class _FestaSkeleton extends StatelessWidget {
  const _FestaSkeleton();
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: List.generate(3, (i) => Container(
          margin: const EdgeInsets.only(bottom: 12), height: 120,
          decoration: BoxDecoration(color: TabuColors.bgCard,
              border: Border.all(color: TabuColors.border, width: 0.8))))));
}

class _AdmBg extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = TabuColors.bg);
    canvas.drawCircle(
        Offset(size.width * 0.85, size.height * 0.08), size.width * 0.7,
        Paint()..shader = RadialGradient(colors: [
          TabuColors.rosaPrincipal.withOpacity(0.07), Colors.transparent,
        ]).createShader(Rect.fromCircle(
            center: Offset(size.width * 0.85, size.height * 0.08),
            radius: size.width * 0.7)));
  }
  @override
  bool shouldRepaint(_AdmBg _) => false;
}

// ══════════════════════════════════════════════════════════════════════════════
//  CONVITE TILE
// ══════════════════════════════════════════════════════════════════════════════
class _ConviteTile extends StatelessWidget {
  final Map<String, dynamic> pedido;
  final VoidCallback?        onAprovar;
  final VoidCallback?        onRejeitar;

  const _ConviteTile({
    required this.pedido,
    required this.onAprovar,
    required this.onRejeitar,
  });

  Color get _statusColor {
    switch (pedido['status'] as String? ?? 'pending') {
      case 'pending':  return const Color(0xFFD4AF37);
      case 'approved': return const Color(0xFF4CAF50);
      case 'rejected': return const Color(0xFFE85D5D);
      default:         return Colors.white24;
    }
  }

  String get _statusLabel {
    switch (pedido['status'] as String? ?? 'pending') {
      case 'pending':  return 'PENDENTE';
      case 'approved': return 'APROVADO';
      case 'rejected': return 'RECUSADO';
      default:         return '—';
    }
  }

  String _formatTs(int? ms) {
    if (ms == null) return '—';
    final dt   = DateTime.fromMillisecondsSinceEpoch(ms);
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}min atrás';
    if (diff.inHours   < 24) return '${diff.inHours}h atrás';
    return '${diff.inDays}d atrás';
  }

  @override
  Widget build(BuildContext context) {
    final isPending   = pedido['status'] == 'pending';
    final processing  = pedido['_processing'] as bool? ?? false;
    final name        = pedido['name']    as String? ?? '—';
    final email       = pedido['email']   as String? ?? '—';
    final message     = pedido['message'] as String? ?? '';
    final protocolo   = pedido['protocolo'] as String?;
    final ts          = pedido['created_at'] as int?;
    final motivoRej   = pedido['motivo_rejeicao'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: isPending
            ? const Color(0xFFD4AF37).withOpacity(0.03)
            : Colors.transparent,
        border: Border(bottom: BorderSide(
          color: Colors.white.withOpacity(0.06), width: 0.5))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Cabeçalho ──────────────────────────────────────────────────
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _statusColor.withOpacity(0.4), width: 0.7)),
              child: Text(_statusLabel, style: TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 8, fontWeight: FontWeight.w700,
                letterSpacing: 2, color: _statusColor))),
            const Spacer(),
            Text(_formatTs(ts), style: const TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 9, color: Colors.white24, letterSpacing: 0.3)),
          ]),

          const SizedBox(height: 10),

          // ── Dados do solicitante ────────────────────────────────────────
          Text(name.toUpperCase(), style: const TextStyle(
            fontFamily: TabuTypography.bodyFont,
            fontSize: 14, fontWeight: FontWeight.w700,
            color: Colors.white, letterSpacing: 1)),
          const SizedBox(height: 3),
          Row(children: [
            const Icon(Icons.email_outlined, color: Colors.white24, size: 11),
            const SizedBox(width: 5),
            Text(email, style: const TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 10, color: Colors.white38, letterSpacing: 0.3)),
          ]),

          // ── Mensagem do solicitante ─────────────────────────────────────
          if (message.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                border: Border(left: BorderSide(
                  color: Colors.white.withOpacity(0.12), width: 2))),
              child: Text(message, maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 11, height: 1.5,
                  color: Colors.white54, letterSpacing: 0.2))),
          ],

          // ── Motivo rejeição (se aplicável) ─────────────────────────────
          if (!isPending && motivoRej != null && motivoRej.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.block_rounded,
                color: Color(0xFFE85D5D), size: 10),
              const SizedBox(width: 5),
              Expanded(child: Text(motivoRej, style: const TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 10, color: Color(0xFFE85D5D),
                height: 1.5, letterSpacing: 0.2))),
            ]),
          ],

          // ── Protocolo ──────────────────────────────────────────────────
          if (protocolo != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.tag_rounded, color: Colors.white12, size: 10),
              const SizedBox(width: 4),
              Text(protocolo, style: const TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 8, color: Colors.white24, letterSpacing: 1)),
            ]),
          ],

          // ── Ações (só pendentes) ────────────────────────────────────────
          if (isPending) ...[
            const SizedBox(height: 14),
            if (processing)
              const Center(child: SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation(TabuColors.rosaPrincipal))))
            else
              Row(children: [
                // APROVAR
                Expanded(child: GestureDetector(
                  onTap: onAprovar,
                  child: Container(height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withOpacity(0.12),
                      border: Border.all(
                        color: const Color(0xFF4CAF50).withOpacity(0.5),
                        width: 0.8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.check_rounded,
                          color: Color(0xFF4CAF50), size: 13),
                        SizedBox(width: 6),
                        Text('APROVAR', style: TextStyle(
                          fontFamily: TabuTypography.bodyFont,
                          fontSize: 9, fontWeight: FontWeight.w700,
                          letterSpacing: 2, color: Color(0xFF4CAF50))),
                      ]),
                  ))),
                const SizedBox(width: 8),
                // RECUSAR
                Expanded(child: GestureDetector(
                  onTap: onRejeitar,
                  child: Container(height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE85D5D).withOpacity(0.08),
                      border: Border.all(
                        color: const Color(0xFFE85D5D).withOpacity(0.4),
                        width: 0.8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.block_rounded,
                          color: Color(0xFFE85D5D), size: 13),
                        SizedBox(width: 6),
                        Text('RECUSAR', style: TextStyle(
                          fontFamily: TabuTypography.bodyFont,
                          fontSize: 9, fontWeight: FontWeight.w700,
                          letterSpacing: 2, color: Color(0xFFE85D5D))),
                      ]),
                  ))),
              ]),
          ],
        ]),
      ),
    );
  }
}