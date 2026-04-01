// lib/screens/screens_auth/penalty_screens/penalty_screens.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  SHARED — Neon line + helpers
// ══════════════════════════════════════════════════════════════════════════════
Widget _neonLine() => Positioned(
  top: 0, left: 0, right: 0,
  child: Container(height: 2,
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [
      TabuColors.rosaDeep, TabuColors.rosaPrincipal,
      TabuColors.rosaClaro, TabuColors.rosaPrincipal, TabuColors.rosaDeep,
    ]))));

Widget _infoChip(String label, Color color) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  decoration: BoxDecoration(
    color: color.withOpacity(0.12),
    border: Border.all(color: color.withOpacity(0.5), width: 0.8)),
  child: Text(label, style: TextStyle(
    fontFamily: TabuTypography.bodyFont,
    fontSize: 9, fontWeight: FontWeight.w700,
    letterSpacing: 1.5, color: color)));

Widget _divider() => Container(height: 0.5, color: Colors.white.withOpacity(0.07));

// ══════════════════════════════════════════════════════════════════════════════
//  ADVERTÊNCIA / CONTEÚDO REMOVIDO
//  Mostra informações e permite continuar após confirmar leitura
// ══════════════════════════════════════════════════════════════════════════════
class AdvertenciaScreen extends StatefulWidget {
  final Map<String, dynamic> penalidade;
  final String               penalidadeKey;
  final String               uid;
  final VoidCallback         onOk;

  const AdvertenciaScreen({
    super.key,
    required this.penalidade,
    required this.penalidadeKey,
    required this.uid,
    required this.onOk,
  });

  @override
  State<AdvertenciaScreen> createState() => _AdvertenciaScreenState();
}

class _AdvertenciaScreenState extends State<AdvertenciaScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;
  bool _marcando = false;

  bool get _isConteudo =>
      (widget.penalidade['tipo'] as String? ?? '') == 'remover_conteudo';

  Color   get _cor   => _isConteudo ? const Color(0xFFE85D5D) : const Color(0xFFD4AF37);
  IconData get _icon => _isConteudo ? Icons.delete_outline_rounded : Icons.warning_amber_rounded;
  String   get _titulo => _isConteudo ? 'CONTEÚDO REMOVIDO' : 'ADVERTÊNCIA FORMAL';
  String   get _subtitulo => _isConteudo
      ? 'UM CONTEÚDO SEU FOI EXCLUÍDO DA PLATAFORMA'
      : 'NOTIFICAÇÃO OFICIAL DE CONDUTA';

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() { _animCtrl.dispose(); super.dispose(); }

  Future<void> _marcarVisto() async {
    if (_marcando) return;
    setState(() => _marcando = true);
    HapticFeedback.mediumImpact();
    try {
      await FirebaseDatabase.instance
          .ref('Users/${widget.uid}/penalidades/${widget.penalidadeKey}/vista')
          .set(true);
    } catch (_) {}
    widget.onOk();
  }

  @override
  Widget build(BuildContext context) {
    final pen    = widget.penalidade;
    final artigo = pen['artigo_violado']  as String? ?? '—';
    final motivo = pen['motivo_admin']    as String? ?? '';
    final proto  = pen['protocolo']       as String? ?? '—';
    final em     = pen['aplicada_em']     as int?;
    final fmt    = DateFormat("dd/MM/yyyy 'às' HH:mm");

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF07000F),
        body: Stack(children: [
          _neonLine(),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  child: Column(children: [

                    // ── Cabeçalho ──────────────────────────────────────────
                    const SizedBox(height: 24),
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        color: _cor.withOpacity(0.08),
                        border: Border.all(color: _cor.withOpacity(0.5), width: 1.2),
                        boxShadow: [BoxShadow(
                          color: _cor.withOpacity(0.2), blurRadius: 24, spreadRadius: 2)]),
                      child: Icon(_icon, color: _cor, size: 32)),
                    const SizedBox(height: 18),
                    Text(_titulo, style: TextStyle(
                      fontFamily: TabuTypography.displayFont,
                      fontSize: 18, letterSpacing: 5, color: _cor)),
                    const SizedBox(height: 4),
                    Text(_subtitulo, style: TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 8, letterSpacing: 2.5,
                      color: Colors.white.withOpacity(0.3))),
                    const SizedBox(height: 28),

                    // ── Artigo + data ──────────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _cor.withOpacity(0.05),
                        border: Border.all(color: _cor.withOpacity(0.25), width: 0.8)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          _infoChip(artigo, _cor),
                          const Spacer(),
                          if (em != null) Text(
                            fmt.format(DateTime.fromMillisecondsSinceEpoch(em)),
                            style: TextStyle(
                              fontFamily: TabuTypography.bodyFont,
                              fontSize: 9, color: Colors.white38)),
                        ]),
                        if (motivo.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _divider(),
                          const SizedBox(height: 14),
                          Text(motivo, style: const TextStyle(
                            fontFamily: TabuTypography.bodyFont,
                            fontSize: 13, height: 1.75, color: Colors.white70)),
                        ],
                      ]),
                    ),
                    const SizedBox(height: 12),

                    // ── Protocolo ──────────────────────────────────────────
                    _ProtoCard(protocolo: proto, color: _cor),
                    const SizedBox(height: 12),

                    // ── Aviso reincidência (só advertência) ────────────────
                    if (!_isConteudo)
                      _AvisoBox(
                        icon: Icons.info_outline_rounded,
                        color: Colors.white24,
                        texto: 'Reincidências resultarão em penalidades progressivas, '
                            'incluindo suspensão temporária e banimento permanente da plataforma.',
                      ),
                    if (_isConteudo)
                      _AvisoBox(
                        icon: Icons.info_outline_rounded,
                        color: Colors.white24,
                        texto: 'O conteúdo foi permanentemente removido e não está mais '
                            'acessível para nenhum usuário. Evite publicar conteúdos semelhantes.',
                      ),

                    const SizedBox(height: 28),

                    // ── Botão OK ───────────────────────────────────────────
                    GestureDetector(
                      onTap: _marcando ? null : _marcarVisto,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: double.infinity, height: 54,
                        decoration: BoxDecoration(
                          color: _marcando ? _cor.withOpacity(0.5) : _cor,
                          boxShadow: _marcando ? null : [
                            BoxShadow(color: _cor.withOpacity(0.35), blurRadius: 20, spreadRadius: 1)]),
                        child: Center(child: _marcando
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                              const SizedBox(width: 10),
                              const Text('LI E ESTOU CIENTE', style: TextStyle(
                                fontFamily: TabuTypography.bodyFont,
                                fontSize: 12, fontWeight: FontWeight.w700,
                                letterSpacing: 3.5, color: Colors.white)),
                            ]))),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Ao confirmar, você declara estar ciente desta notificação oficial.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: TabuTypography.bodyFont,
                        fontSize: 9, color: Colors.white.withOpacity(0.22))),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SUSPENSÃO — Bloqueia acesso durante o período, opção de solicitar reativação
// ══════════════════════════════════════════════════════════════════════════════
class SuspensaoScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String               uid;

  const SuspensaoScreen({
    super.key,
    required this.userData,
    required this.uid,
  });

  @override
  State<SuspensaoScreen> createState() => _SuspensaoScreenState();
}

class _SuspensaoScreenState extends State<SuspensaoScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;

  bool _solicitando = false;
  bool _solicitado  = false;

  Map<String, dynamic>? _pen;

  static const Color _cor = Color(0xFFFF8C00);

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
    _carregarPen();
    // Check if already requested
    final jaReq = widget.userData['reativacao_solicitada'] as bool? ?? false;
    if (jaReq) _solicitado = true;
  }

  @override
  void dispose() { _animCtrl.dispose(); super.dispose(); }

  void _carregarPen() {
    final pens = widget.userData['penalidades'];
    if (pens == null || pens is! Map) return;
    final lista = (pens as Map).entries
        .map((e) { final v = Map<String, dynamic>.from(e.value as Map); v['_key'] = e.key; return v; })
        .where((p) => p['tipo'] == 'suspensao')
        .toList()
      ..sort((a, b) => (b['aplicada_em'] as int? ?? 0).compareTo(a['aplicada_em'] as int? ?? 0));
    if (lista.isNotEmpty) setState(() => _pen = lista.first);
  }

  Future<void> _solicitarReativacao() async {
    if (_solicitando || _solicitado) return;
    setState(() => _solicitando = true);
    HapticFeedback.mediumImpact();
    try {
      await FirebaseDatabase.instance.ref('Users/${widget.uid}').update({
        'reativacao_solicitada':    true,
        'reativacao_solicitada_em': DateTime.now().millisecondsSinceEpoch,
      });
      if (mounted) setState(() { _solicitado = true; _solicitando = false; });
      HapticFeedback.mediumImpact();
    } catch (_) {
      if (mounted) setState(() => _solicitando = false);
    }
  }

  Future<void> _sair() async {
    HapticFeedback.selectionClick();
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final suspensaoFim = widget.userData['suspensao_fim'] as int?;
    final artigo = _pen?['artigo_violado']    as String? ?? '—';
    final motivo = _pen?['motivo_admin']      as String? ?? '';
    final proto  = _pen?['protocolo']         as String? ?? '—';
    final inicio = _pen?['suspensao_inicio']  as int?;
    final fmt    = DateFormat("dd/MM/yyyy 'às' HH:mm");
    final fmtShort = DateFormat('dd/MM/yyyy');

    // Tempo restante
    String tempoRestante = '';
    if (suspensaoFim != null) {
      final diff = DateTime.fromMillisecondsSinceEpoch(suspensaoFim)
          .difference(DateTime.now());
      if (diff.inDays > 0)        tempoRestante = '${diff.inDays} dia(s)';
      else if (diff.inHours > 0)  tempoRestante = '${diff.inHours} hora(s)';
      else if (diff.inMinutes > 0) tempoRestante = '${diff.inMinutes} minuto(s)';
      else tempoRestante = 'encerrando...';
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF07000F),
        body: Stack(children: [
          Positioned(top: 0, left: 0, right: 0,
            child: Container(height: 2,
              decoration: const BoxDecoration(gradient: LinearGradient(
                colors: [Color(0xFF7A3A00), Color(0xFFFF8C00), Color(0xFFFFB347),
                         Color(0xFFFF8C00), Color(0xFF7A3A00)])))),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                child: Column(children: [

                  const SizedBox(height: 24),

                  // Ícone
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: _cor.withOpacity(0.08),
                      border: Border.all(color: _cor.withOpacity(0.5), width: 1.2),
                      boxShadow: [BoxShadow(color: _cor.withOpacity(0.2), blurRadius: 24)]),
                    child: const Icon(Icons.pause_circle_outline_rounded, color: _cor, size: 32)),
                  const SizedBox(height: 18),
                  const Text('CONTA SUSPENSA', style: TextStyle(
                    fontFamily: TabuTypography.displayFont,
                    fontSize: 18, letterSpacing: 5, color: _cor)),
                  const SizedBox(height: 4),
                  Text('ACESSO TEMPORARIAMENTE BLOQUEADO', style: TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 8, letterSpacing: 2.5, color: Colors.white.withOpacity(0.3))),
                  const SizedBox(height: 28),

                  // Período
                  if (suspensaoFim != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: _cor.withOpacity(0.06),
                        border: Border.all(color: _cor.withOpacity(0.35), width: 0.8)),
                      child: Column(children: [
                        Text('PERÍODO DE SUSPENSÃO', style: TextStyle(
                          fontFamily: TabuTypography.bodyFont,
                          fontSize: 8, fontWeight: FontWeight.w700,
                          letterSpacing: 2.5, color: _cor.withOpacity(0.7))),
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(child: _dateBlock('INÍCIO',
                            inicio != null ? fmtShort.format(DateTime.fromMillisecondsSinceEpoch(inicio)) : '—',
                            Colors.white54)),
                          Container(width: 1, height: 48, color: _cor.withOpacity(0.2)),
                          Expanded(child: _dateBlock('TÉRMINO',
                            fmtShort.format(DateTime.fromMillisecondsSinceEpoch(suspensaoFim)),
                            _cor)),
                        ]),
                        if (tempoRestante.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _divider(),
                          const SizedBox(height: 12),
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.timer_outlined, color: Color(0xFFFF8C00), size: 13),
                            const SizedBox(width: 6),
                            Text('Tempo restante: ', style: TextStyle(
                              fontFamily: TabuTypography.bodyFont,
                              fontSize: 10, color: Colors.white38)),
                            Text(tempoRestante, style: const TextStyle(
                              fontFamily: TabuTypography.bodyFont,
                              fontSize: 10, fontWeight: FontWeight.w700,
                              color: _cor)),
                          ]),
                        ],
                      ]),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Motivo
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      border: Border.all(color: Colors.white.withOpacity(0.07))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _infoChip(artigo, _cor),
                      if (motivo.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _divider(),
                        const SizedBox(height: 14),
                        Text(motivo, style: const TextStyle(
                          fontFamily: TabuTypography.bodyFont,
                          fontSize: 13, height: 1.75, color: Colors.white70)),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 12),

                  _ProtoCard(protocolo: proto, color: _cor),
                  const SizedBox(height: 12),

                  _AvisoBox(
                    icon: Icons.info_outline_rounded,
                    color: Colors.white24,
                    texto: 'Seu acesso será restaurado automaticamente ao término do período de '
                        'suspensão. Nenhuma ação adicional é necessária.',
                  ),
                  const SizedBox(height: 28),

                  // Botão solicitar reativação
                  if (!_solicitado) ...[
                    GestureDetector(
                      onTap: _solicitando ? null : _solicitarReativacao,
                      child: Container(
                        width: double.infinity, height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          border: Border.all(color: _cor.withOpacity(0.6), width: 0.8)),
                        child: Center(child: _solicitando
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(color: _cor, strokeWidth: 2))
                          : Row(mainAxisSize: MainAxisSize.min, children: const [
                              Icon(Icons.mark_email_unread_outlined, color: _cor, size: 16),
                              SizedBox(width: 10),
                              Text('SOLICITAR REATIVAÇÃO ANTECIPADA', style: TextStyle(
                                fontFamily: TabuTypography.bodyFont,
                                fontSize: 10, fontWeight: FontWeight.w700,
                                letterSpacing: 1.5, color: _cor)),
                            ]))),
                    ),
                    const SizedBox(height: 8),
                    Text('A solicitação será analisada pela equipe do Tabu.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: TabuTypography.bodyFont,
                        fontSize: 9, color: Colors.white.withOpacity(0.25))),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withOpacity(0.06),
                        border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.35))),
                      child: Row(children: const [
                        Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 16),
                        SizedBox(width: 10),
                        Expanded(child: Text(
                          'Solicitação enviada. A equipe do Tabu irá analisá-la em breve '
                          'e você será notificado por e-mail.',
                          style: TextStyle(fontFamily: TabuTypography.bodyFont,
                            fontSize: 11, height: 1.5, color: Colors.white60))),
                      ])),
                  ],

                  const SizedBox(height: 14),

                  // Sair
                  GestureDetector(
                    onTap: _sair,
                    child: Container(
                      width: double.infinity, height: 48,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.6)),
                      child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.logout_rounded, color: Colors.white.withOpacity(0.3), size: 14),
                        const SizedBox(width: 8),
                        Text('SAIR DA CONTA', style: TextStyle(
                          fontFamily: TabuTypography.bodyFont,
                          fontSize: 10, fontWeight: FontWeight.w600,
                          letterSpacing: 2, color: Colors.white.withOpacity(0.3))),
                      ]))),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _dateBlock(String label, String value, Color color) => Column(children: [
    Text(label, style: TextStyle(
      fontFamily: TabuTypography.bodyFont,
      fontSize: 7, fontWeight: FontWeight.w700,
      letterSpacing: 2, color: color.withOpacity(0.7))),
    const SizedBox(height: 6),
    Text(value, textAlign: TextAlign.center, style: TextStyle(
      fontFamily: TabuTypography.bodyFont,
      fontSize: 11, fontWeight: FontWeight.w700, color: color, height: 1.4)),
  ]);
}

// ══════════════════════════════════════════════════════════════════════════════
//  BANIMENTO — Bloqueia permanentemente
// ══════════════════════════════════════════════════════════════════════════════
class BanimentoScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String               uid;

  const BanimentoScreen({
    super.key,
    required this.userData,
    required this.uid,
  });

  @override
  State<BanimentoScreen> createState() => _BanimentoScreenState();
}

class _BanimentoScreenState extends State<BanimentoScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;

  Map<String, dynamic>? _pen;

  static const Color _cor = Color(0xFFE85D5D);

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
    _carregarPen();
  }

  @override
  void dispose() { _animCtrl.dispose(); super.dispose(); }

  void _carregarPen() {
    final pens = widget.userData['penalidades'];
    if (pens == null || pens is! Map) return;
    final lista = (pens as Map).entries
        .map((e) { final v = Map<String, dynamic>.from(e.value as Map); v['_key'] = e.key; return v; })
        .where((p) => p['tipo'] == 'banimento')
        .toList()
      ..sort((a, b) => (b['aplicada_em'] as int? ?? 0).compareTo(a['aplicada_em'] as int? ?? 0));
    if (lista.isNotEmpty) setState(() => _pen = lista.first);
  }

  Future<void> _sair() async {
    HapticFeedback.selectionClick();
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final artigo = _pen?['artigo_violado'] as String? ?? '—';
    final motivo = _pen?['motivo_admin']   as String? ?? '';
    final proto  = _pen?['protocolo']      as String? ?? '—';
    final em     = _pen?['aplicada_em']    as int? ?? widget.userData['banido_em'] as int?;
    final fmt    = DateFormat("dd/MM/yyyy 'às' HH:mm");

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF07000F),
        body: Stack(children: [
          Positioned(top: 0, left: 0, right: 0,
            child: Container(height: 2,
              decoration: const BoxDecoration(gradient: LinearGradient(
                colors: [Color(0xFF5A0000), Color(0xFFE85D5D), Color(0xFFFF8080),
                         Color(0xFFE85D5D), Color(0xFF5A0000)])))),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                child: Column(children: [

                  const SizedBox(height: 24),

                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: _cor.withOpacity(0.08),
                      border: Border.all(color: _cor.withOpacity(0.5), width: 1.2),
                      boxShadow: [BoxShadow(color: _cor.withOpacity(0.2), blurRadius: 24)]),
                    child: const Icon(Icons.block_rounded, color: _cor, size: 32)),
                  const SizedBox(height: 18),
                  const Text('CONTA BANIDA', style: TextStyle(
                    fontFamily: TabuTypography.displayFont,
                    fontSize: 18, letterSpacing: 5, color: _cor)),
                  const SizedBox(height: 4),
                  Text('ACESSO PERMANENTEMENTE REVOGADO', style: TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 8, letterSpacing: 2.5, color: Colors.white.withOpacity(0.3))),
                  const SizedBox(height: 28),

                  // Motivo + data
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _cor.withOpacity(0.04),
                      border: Border.all(color: _cor.withOpacity(0.25), width: 0.8)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        _infoChip(artigo, _cor),
                        const Spacer(),
                        if (em != null) Text(
                          fmt.format(DateTime.fromMillisecondsSinceEpoch(em)),
                          style: const TextStyle(fontFamily: TabuTypography.bodyFont,
                            fontSize: 9, color: Colors.white38)),
                      ]),
                      if (motivo.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _divider(),
                        const SizedBox(height: 14),
                        Text(motivo, style: const TextStyle(
                          fontFamily: TabuTypography.bodyFont,
                          fontSize: 13, height: 1.75, color: Colors.white70)),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 12),

                  _ProtoCard(protocolo: proto, color: _cor),
                  const SizedBox(height: 12),

                  // Aviso permanente
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      border: Border.all(color: Colors.white.withOpacity(0.06))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.mail_outline_rounded, color: Colors.white38, size: 14),
                        const SizedBox(width: 8),
                        Text('CONTESTAÇÃO FORMAL', style: TextStyle(
                          fontFamily: TabuTypography.bodyFont,
                          fontSize: 8, fontWeight: FontWeight.w700,
                          letterSpacing: 2, color: Colors.white38)),
                      ]),
                      const SizedBox(height: 10),
                      Text(
                        'Esta decisão é definitiva. Para contestar formalmente, envie um '
                        'e-mail com o número de protocolo no assunto:',
                        style: TextStyle(fontFamily: TabuTypography.bodyFont,
                          fontSize: 11, height: 1.6, color: Colors.white.withOpacity(0.4))),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        color: Colors.white.withOpacity(0.03),
                        child: Text('tabuadministrative@gmail.com',
                          style: TextStyle(fontFamily: TabuTypography.displayFont,
                            fontSize: 11, letterSpacing: 1, color: _cor.withOpacity(0.8)))),
                    ]),
                  ),
                  const SizedBox(height: 32),

                  GestureDetector(
                    onTap: _sair,
                    child: Container(
                      width: double.infinity, height: 54,
                      decoration: BoxDecoration(
                        color: _cor.withOpacity(0.12),
                        border: Border.all(color: _cor.withOpacity(0.4), width: 0.8)),
                      child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: const [
                        Icon(Icons.logout_rounded, color: _cor, size: 16),
                        SizedBox(width: 10),
                        Text('SAIR DA CONTA', style: TextStyle(
                          fontFamily: TabuTypography.bodyFont,
                          fontSize: 11, fontWeight: FontWeight.w700,
                          letterSpacing: 3, color: _cor)),
                      ]))),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SHARED WIDGETS
// ══════════════════════════════════════════════════════════════════════════════
class _ProtoCard extends StatelessWidget {
  final String protocolo;
  final Color  color;
  const _ProtoCard({required this.protocolo, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.04),
        border: Border.all(color: color.withOpacity(0.2), width: 0.6)),
      child: Row(children: [
        const Icon(Icons.tag_rounded, color: Colors.white24, size: 13),
        const SizedBox(width: 8),
        Text('PROTOCOLO', style: const TextStyle(
          fontFamily: TabuTypography.bodyFont,
          fontSize: 8, fontWeight: FontWeight.w700,
          letterSpacing: 2, color: Colors.white24)),
        const Spacer(),
        Text(protocolo, style: TextStyle(
          fontFamily: TabuTypography.displayFont,
          fontSize: 11, letterSpacing: 1.5, color: color.withOpacity(0.8))),
      ]),
    );
  }
}

class _AvisoBox extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   texto;
  const _AvisoBox({required this.icon, required this.color, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.04),
        border: Border.all(color: color.withOpacity(0.15))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 10),
        Expanded(child: Text(texto, style: TextStyle(
          fontFamily: TabuTypography.bodyFont,
          fontSize: 11, height: 1.6, color: Colors.white.withOpacity(0.4)))),
      ]),
    );
  }
}