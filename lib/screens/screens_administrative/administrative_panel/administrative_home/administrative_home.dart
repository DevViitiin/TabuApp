// lib/screens/screens_home/perfil_screen/admin/admin_panel_screen.dart
//
//  ▸ Cada _ReportTile agora abre a ReportDetailScreen completa
//  ▸ Ações rápidas (Ignorar / Remover) mantidas no card
//  ▸ Toque no card inteiro abre detalhes + formulário disciplinar
//
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/screens/screens_administrative/administrative_panel/administrative_home/invitate_code_screen.dart';
import 'package:tabuapp/screens/screens_administrative/administrative_panel/administrative_reports/report_detail_screen.dart';


class AdminPanelScreen extends StatefulWidget {
  final String adminUid;
  const AdminPanelScreen({super.key, required this.adminUid});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {

  late TabController _tabCtrl;
  final _db = FirebaseDatabase.instance.ref();

  int  _totalUsers     = 0;
  int  _totalPosts     = 0;
  int  _totalStories   = 0;
  int  _totalFestas    = 0;
  int  _pendingReports = 0;
  bool _loadingStats   = true;

  List<Map<String, dynamic>> _reportsPosts   = [];
  List<Map<String, dynamic>> _reportsStories = [];
  List<Map<String, dynamic>> _reportsUsers   = [];
  List<Map<String, dynamic>> _reportsChats   = [];
  bool _loadingReports = true;

  // Adicione junto aos outros campos de estado:
  List<Map<String, dynamic>> _pedidosConvite = [];
  bool _loadingConvites = true;
  int  _pendingConvites = 0;

  List<Map<String, dynamic>> _users = [];
  bool _loadingUsers = true;

@override
void initState() {
  super.initState();
  _tabCtrl = TabController(length: 4, vsync: this); // ← era 3
  _carregarTudo();
}

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // Substitua _carregarTudo:
  Future<void> _carregarTudo() async {
  await Future.wait([
    _carregarStats(),
    _carregarReports(),     // 1º - Denúncias
    _carregarUsuarios(),    // 2º - Usuários  
    _carregarPedidosConvite(), // 3º - Convites
  ]);
}

  Future<void> _carregarStats() async {
    setState(() => _loadingStats = true);
    try {
      final results = await Future.wait([
        _db.child('Users').get(),
        _db.child('Posts/post').get(),
        _db.child('Posts/story').get(),
        _db.child('Festas').get(),
        _db.child('Reports/posts').get(),
        _db.child('Reports/stories').get(),
        _db.child('Reports/users').get(),
        _db.child('Reports/chats').get(),
      ]);

      int countMap(DataSnapshot s) {
        if (!s.exists || s.value == null) return 0;
        final v = s.value;
        if (v is Map) return v.keys.where((k) => k != 'rs').length;
        return 0;
      }

      int pendingInMap(DataSnapshot s) {
        if (!s.exists || s.value == null) return 0;
        final v = s.value;
        if (v is! Map) return 0;
        return v.values.whereType<Map>()
            .where((r) => r['status'] == 'pending').length;
      }

      if (mounted) setState(() {
        _totalUsers     = countMap(results[0]);
        _totalPosts     = countMap(results[1]);
        _totalStories   = countMap(results[2]);
        _totalFestas    = countMap(results[3]);
        _pendingReports = pendingInMap(results[4]) +
            pendingInMap(results[5]) +
            pendingInMap(results[6]) +
            pendingInMap(results[7]);
        _loadingStats   = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  Future<void> _carregarReports() async {
    setState(() => _loadingReports = true);
    try {
      final snaps = await Future.wait([
        _db.child('Reports/posts').get(),
        _db.child('Reports/stories').get(),
        _db.child('Reports/users').get(),
        _db.child('Reports/chats').get(),
      ]);

      List<Map<String, dynamic>> parse(DataSnapshot snap) {
        if (!snap.exists || snap.value == null) return [];
        final m = snap.value as Map;
        return m.entries.map((e) {
          final v = Map<String, dynamic>.from(e.value as Map);
          v['_key'] = e.key;
          return v;
        }).toList()
          ..sort((a, b) => (b['created_at'] as int? ?? 0)
              .compareTo(a['created_at'] as int? ?? 0));
      }

      if (mounted) setState(() {
        _reportsPosts   = parse(snaps[0]);
        _reportsStories = parse(snaps[1]);
        _reportsUsers   = parse(snaps[2]);
        _reportsChats   = parse(snaps[3]);
        _loadingReports = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingReports = false);
    }
  }

  Future<void> _carregarUsuarios() async {
    setState(() => _loadingUsers = true);
    try {
      final snap = await _db.child('Users').get();
      if (!snap.exists || snap.value == null) {
        if (mounted) setState(() => _loadingUsers = false);
        return;
      }
      final m = snap.value as Map;
      final list = m.entries.map((e) {
        final v = Map<String, dynamic>.from(e.value as Map);
        v['uid'] = e.key;
        return v;
      }).toList()
        ..sort((a, b) =>
            (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? ''));
      if (mounted) setState(() { _users = list; _loadingUsers = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  // ── Abrir detalhe da denúncia ──────────────────────────────────────────────
  void _abrirDetalhe(Map<String, dynamic> report, String tipo) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => ReportDetailScreen(
          report:    report,
          tipo:      tipo,
          reportKey: report['_key'] as String,
        ),
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(
                parent: animation, curve: Curves.easeOutCubic)),
          child: child),
        transitionDuration: const Duration(milliseconds: 280),
      ),
    ).then((_) {
      // Recarrega ao voltar
      _carregarReports();
      _carregarStats();
    });
  }

  Future<void> _resolverReport({
    required String path,
    required String key,
    required String status,
  }) async {
    HapticFeedback.mediumImpact();
    await _db.child('Reports/$path/$key/status').set(status);
    await _carregarReports();
    await _carregarStats();
  }

  Future<void> _deletarConteudo({
    required String reportPath,
    required String reportKey,
    required String contentPath,
  }) async {
    HapticFeedback.mediumImpact();
    await _db.child(contentPath).remove();
    await _db.child('Reports/$reportPath/$reportKey/status').set('actioned');
    await _carregarReports();
    await _carregarStats();
  }

  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF07000F),
        body: Column(children: [
          _buildHeader(),
          _buildStats(),
          _buildTabBar(),
          Expanded(child: TabBarView(
          controller: _tabCtrl,
          children: [
            _buildDenuncias(),    // Tab 0: DENÚNCIAS
            _buildUsuarios(),     // Tab 1: USUÁRIOS  
            _buildConvites(),     // Tab 2: CONVITES
            _buildSistema(),      // Tab 3: SISTEMA
          ]),
                  
        ),
        ]

      ),
    ));
  }

  // Novo método:
Widget _buildConvites() {
  if (_loadingConvites) return _loadingWidget();

  final pendentes  = _pedidosConvite.where((p) => p['status'] == 'pending').toList();
  final resolvidos = _pedidosConvite.where((p) => p['status'] != 'pending').toList();

  if (_pedidosConvite.isEmpty) {
    return _emptyState(
      icon:  Icons.mail_outline_rounded,
      label: 'SEM PEDIDOS DE CONVITE',
    );
  }

  return RefreshIndicator(
    color:           TabuColors.rosaPrincipal,
    backgroundColor: const Color(0xFF0D0020),
    onRefresh:       _carregarPedidosConvite,
    child: ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [

        // ── Pendentes ─────────────────────────────────────────────────────
        if (pendentes.isNotEmpty) ...[
          _SectionLabel(label: 'AGUARDANDO ANÁLISE (${pendentes.length})'),
          const SizedBox(height: 8),
          ...pendentes.map((p) => _ConviteTile(
            pedido:    p,
            onAprovar: () => _processarPedidoConvite(
              pedidoId: p['_key'] as String, acao: 'aprovar'),
            onRejeitar: () => _confirmarRejeicao(
              p['_key'] as String, p['name'] as String? ?? '?'),
          )),
        ],

        // ── Resolvidos ────────────────────────────────────────────────────
        if (resolvidos.isNotEmpty) ...[
          Container(
            height: 0.5, color: Colors.white.withOpacity(0.06),
            margin: const EdgeInsets.symmetric(vertical: 16)),
          _SectionLabel(label: 'HISTÓRICO (${resolvidos.length})'),
          const SizedBox(height: 8),
          ...resolvidos.map((p) => _ConviteTile(
            pedido:    p,
            onAprovar: null,
            onRejeitar: null,
          )),
        ],

        const SizedBox(height: 80),
      ],
    ),
  );
}

  Future<void> _carregarPedidosConvite() async {
  setState(() => _loadingConvites = true);
  try {
    final snap = await _db.child('InviteRequests').get();
    if (!snap.exists || snap.value == null) {
      if (mounted) setState(() { _pedidosConvite = []; _loadingConvites = false; });
      return;
    }
    final m = snap.value as Map;
    final list = m.entries.map((e) {
      final v = Map<String, dynamic>.from(e.value as Map);
      v['_key'] = e.key;
      return v;
    }).toList()
      ..sort((a, b) => (b['created_at'] as int? ?? 0)
          .compareTo(a['created_at'] as int? ?? 0));

    if (mounted) setState(() {
      _pedidosConvite  = list;
      _pendingConvites = list.where((p) => p['status'] == 'pending').length;
      _loadingConvites = false;
    });
  } catch (e) {
    debugPrint('_carregarPedidosConvite error: $e');
    if (mounted) setState(() => _loadingConvites = false);
  }
}

Future<void> _processarPedidoConvite({
  required String pedidoId,
  required String acao,          // 'aprovar' | 'rejeitar'
  String? motivoRejeicao,
}) async {
  HapticFeedback.mediumImpact();
  try {
    // Marcar como "processando" na UI imediatamente
    setState(() {
      final idx = _pedidosConvite.indexWhere((p) => p['_key'] == pedidoId);
      if (idx != -1) _pedidosConvite[idx]['_processing'] = true;
    });

    await FirebaseFunctions.instance
        .httpsCallable('processarPedidoConvite')
        .call({'pedidoId': pedidoId, 'acao': acao, if (motivoRejeicao != null) 'motivoRejeicao': motivoRejeicao});

    await _carregarPedidosConvite();
    await _carregarStats();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: acao == 'aprovar'
            ? const Color(0xFF1A4A2A)
            : const Color(0xFF4A1010),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(),
        content: Text(
          acao == 'aprovar'
              ? 'Convite aprovado — e-mail enviado com sucesso.'
              : 'Pedido recusado — e-mail enviado ao solicitante.',
          style: const TextStyle(
            fontFamily: 'SpaceMono',
            fontSize: 11, letterSpacing: 0.5, color: Colors.white70),
        ),
      ));
    }
  } catch (e) {
    debugPrint('_processarPedidoConvite error: $e');
    if (mounted) {
      setState(() {
        final idx = _pedidosConvite.indexWhere((p) => p['_key'] == pedidoId);
        if (idx != -1) _pedidosConvite[idx].remove('_processing');
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: Color(0xFF4A1010),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(),
        content: Text('Erro ao processar pedido. Tente novamente.',
          style: TextStyle(fontFamily: 'SpaceMono', fontSize: 11, color: Colors.white70)),
      ));
    }
  }
}

void _confirmarRejeicao(String pedidoId, String nome) {
  final ctrl = TextEditingController();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF0D0020),
    shape: const RoundedRectangleBorder(),
    builder: (_) => Padding(
      padding: EdgeInsets.fromLTRB(
        24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 3,
          decoration: BoxDecoration(color: Colors.white12,
            borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        Container(width: 52, height: 52,
          color: const Color(0xFFE85D5D).withOpacity(0.12),
          child: const Icon(Icons.block_rounded,
            color: Color(0xFFE85D5D), size: 24)),
        const SizedBox(height: 14),
        Text('RECUSAR PEDIDO DE ${nome.toUpperCase()}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: TabuTypography.displayFont,
            fontSize: 13, letterSpacing: 3, color: Colors.white)),
        const SizedBox(height: 8),
        Text('Informe o motivo (opcional). Será incluído no e-mail enviado ao solicitante.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: TabuTypography.bodyFont,
            fontSize: 10, height: 1.6,
            color: Colors.white.withOpacity(0.35))),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            border: Border.all(color: Colors.white12)),
          child: TextField(
            controller: ctrl,
            style: const TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 12, color: Colors.white70),
            cursorColor: TabuColors.rosaPrincipal,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Ex: Perfil não elegível para acesso neste momento...',
              hintStyle: TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 11, color: Colors.white24),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(12)),
          ),
        ),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                border: Border.all(color: Colors.white12)),
              child: const Center(child: Text('CANCELAR',
                style: TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 10, fontWeight: FontWeight.w700,
                  letterSpacing: 2.5, color: Colors.white38)))))),
          const SizedBox(width: 12),
          Expanded(child: GestureDetector(
            onTap: () {
              Navigator.pop(context);
              _processarPedidoConvite(
                pedidoId: pedidoId,
                acao: 'rejeitar',
                motivoRejeicao: ctrl.text.trim(),
              );
            },
            child: Container(height: 46,
              color: const Color(0xFFE85D5D),
              child: const Center(child: Text('RECUSAR',
                style: TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 10, fontWeight: FontWeight.w700,
                  letterSpacing: 2.5, color: Colors.white)))))),
        ]),
      ]),
    ),
  );
}

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x33FF2D7A), width: 0.8)),
      ),
      child: SafeArea(bottom: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Row(children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(width: 35, height: 35,
              color: Colors.transparent,
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white54, size: 18)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: TabuColors.rosaDeep,
                child: const Text('ADMIN',
                  style: TextStyle(
                    fontFamily:    TabuTypography.bodyFont,
                    fontSize:      7, fontWeight: FontWeight.w700,
                    letterSpacing: 1, color: Colors.white))),
              const SizedBox(width: 10),
              const Text('PAINEL PROFISSIONAL',
                style: TextStyle(
                  fontFamily:    TabuTypography.displayFont,
                  fontSize:      12, letterSpacing: 1, color: Colors.white)),
            ]),
            const SizedBox(height: 3),
            Text('Tabu · Acesso Restrito',
              style: TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 10, letterSpacing: 1,
                color: Colors.white.withOpacity(0.3))),
          ])),
          if (_pendingReports > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color:  TabuColors.rosaDeep.withOpacity(0.25),
                border: Border.all(
                  color: TabuColors.rosaPrincipal.withOpacity(0.5))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.flag_rounded,
                  color: TabuColors.rosaPrincipal, size: 12),
                const SizedBox(width: 5),
                Text('$_pendingReports',
                  style: const TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: TabuColors.rosaPrincipal)),
              ])),
        ]),
      )),
    );
  }

  Widget _buildStats() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color:  Colors.white.withOpacity(0.02),
        border: const Border(bottom: BorderSide(
          color: Color(0x1AFFFFFF), width: 0.5))),
      child: _loadingStats
          ? const Center(child: SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation(TabuColors.rosaPrincipal))))
          : Row(children: [
              _StatChip(label: 'USERS',   value: '$_totalUsers',
                icon: Icons.people_outline_rounded),
              _Divider(),
              _StatChip(label: 'POSTS',   value: '$_totalPosts',
                icon: Icons.grid_view_rounded),
              _Divider(),
              _StatChip(label: 'STORIES', value: '$_totalStories',
                icon: Icons.auto_stories_rounded),
              _Divider(),
              _StatChip(label: 'FESTAS',  value: '$_totalFestas',
                icon: Icons.celebration_outlined),
              _Divider(),
              _StatChip(label: 'REPORTS', value: '$_pendingReports',
                icon: Icons.flag_rounded,
                highlight: _pendingReports > 0),
            ]),
    );
  }

  // No build(), atualize o TabBar (eram 3 tabs, agora 4):
Widget _buildTabBar() {
  return Container(
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0x1AFFFFFF), width: 0.5))),
    child: TabBar(
      controller:           _tabCtrl,
      indicatorColor:       TabuColors.rosaPrincipal,
      indicatorWeight:      1.5,
      labelColor:           Colors.white,
      unselectedLabelColor: Colors.white38,
      isScrollable:         true,
      tabAlignment:         TabAlignment.start,
      labelStyle: const TextStyle(
        fontFamily: TabuTypography.bodyFont,
        fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2),
      unselectedLabelStyle: const TextStyle(
        fontFamily: TabuTypography.bodyFont,
        fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2),
      tabs: [
        Tab(text: 'DENÚNCIAS${_pendingReports > 0 ? " ($_pendingReports)" : ""}'),     // Tab 0
        const Tab(text: 'USUÁRIOS'),                                                    // Tab 1
        Tab(text: 'CONVITES${_pendingConvites > 0 ? " ($_pendingConvites)" : ""}'),    // Tab 2
        const Tab(text: 'SISTEMA'),                                                     // Tab 3
      ],
    ),
  );
}

  // ══════════════════════════════════════════════════════════════════════════
  //  TAB: DENÚNCIAS
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildDenuncias() {
    if (_loadingReports) return _loadingWidget();

    final todos = [
      ..._reportsPosts.map((r)   => {...r, '_tipo': 'posts'}),
      ..._reportsStories.map((r) => {...r, '_tipo': 'stories'}),
      ..._reportsUsers.map((r)   => {...r, '_tipo': 'users'}),
      ..._reportsChats.map((r)   => {...r, '_tipo': 'chats'}),
    ]..sort((a, b) => (b['created_at'] as int? ?? 0)
        .compareTo(a['created_at'] as int? ?? 0));

    if (todos.isEmpty) {
      return _emptyState(
        icon:  Icons.check_circle_outline_rounded,
        label: 'SEM DENÚNCIAS PENDENTES',
      );
    }

    return RefreshIndicator(
      color:           TabuColors.rosaPrincipal,
      backgroundColor: const Color(0xFF0D0020),
      onRefresh:       _carregarReports,
      child: ListView.separated(
        padding:     const EdgeInsets.symmetric(vertical: 12),
        itemCount:   todos.length,
        separatorBuilder: (_, __) => Container(
          height: 0.5, color: Colors.white.withOpacity(0.06)),
        itemBuilder: (_, i) {
          final r    = Map<String, dynamic>.from(todos[i]);
          final tipo = r['_tipo'] as String;
          final key  = r['_key']  as String;
          return _ReportTile(
            report:    r,
            tipo:      tipo,
            onTap:     () => _abrirDetalhe(r, tipo),
            onDismiss: () => _resolverReport(
              path:   tipo,
              key:    key,
              status: 'dismissed',
            ),
            onDelete: () {
              String contentPath = '';
              if (tipo == 'posts')
                contentPath = 'Posts/post/${r['post_id'] ?? ''}';
              else if (tipo == 'stories')
                contentPath = 'Posts/story/${r['story_id'] ?? ''}';
              else if (tipo == 'chats')
                contentPath = 'Chats/${r['chat_id'] ?? ''}';

              if (contentPath.isNotEmpty) {
                _confirmarDelete(
                  context:  context,
                  tipo:     tipo,
                  onConfirm: () => _deletarConteudo(
                    reportPath:  tipo,
                    reportKey:   key,
                    contentPath: contentPath,
                  ),
                );
              } else {
                // Para usuário, abre detalhe direto
                _abrirDetalhe(r, tipo);
              }
            },
          );
        },
      ),
    );
  }

  void _confirmarDelete({
    required BuildContext context,
    required String tipo,
    required VoidCallback onConfirm,
  }) {
    showModalBottomSheet(
      context:         context,
      backgroundColor: const Color(0xFF0D0020),
      shape:           const RoundedRectangleBorder(),
      builder: (_) => SafeArea(top: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 3,
            decoration: BoxDecoration(color: Colors.white12,
              borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Container(width: 52, height: 52,
            color: const Color(0xFFE85D5D).withOpacity(0.12),
            child: const Icon(Icons.delete_outline_rounded,
              color: Color(0xFFE85D5D), size: 24)),
          const SizedBox(height: 14),
          Text('REMOVER ${tipo.toUpperCase().replaceAll('_', ' ')}?',
            style: const TextStyle(
              fontFamily: TabuTypography.displayFont,
              fontSize: 14, letterSpacing: 4, color: Colors.white)),
          const SizedBox(height: 8),
          Text('O conteúdo será excluído permanentemente. Esta ação não pode ser desfeita.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 11, height: 1.6,
              color: Colors.white.withOpacity(0.4))),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(height: 46,
                decoration: BoxDecoration(
                  color:  Colors.white.withOpacity(0.05),
                  border: Border.all(color: Colors.white12)),
                child: const Center(child: Text('CANCELAR',
                  style: TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 10, fontWeight: FontWeight.w700,
                    letterSpacing: 2.5, color: Colors.white38)))))),
            const SizedBox(width: 12),
            Expanded(child: GestureDetector(
              onTap: () { Navigator.pop(context); onConfirm(); },
              child: Container(height: 46,
                color: const Color(0xFFE85D5D),
                child: const Center(child: Text('REMOVER',
                  style: TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 10, fontWeight: FontWeight.w700,
                    letterSpacing: 2.5, color: Colors.white)))))),
          ]),
        ]),
      )),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  TAB: USUÁRIOS
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildUsuarios() {
    if (_loadingUsers) return _loadingWidget();
    if (_users.isEmpty) return _emptyState(
      icon: Icons.people_outline_rounded, label: 'SEM USUÁRIOS');

    return RefreshIndicator(
      color: TabuColors.rosaPrincipal,
      backgroundColor: const Color(0xFF0D0020),
      onRefresh: _carregarUsuarios,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: _users.length,
        separatorBuilder: (_, __) => Container(
          height: 0.5, color: Colors.white.withOpacity(0.06)),
        itemBuilder: (_, i) => _UserAdminTile(user: _users[i]),
      ),
    );
  }

  
  // ══════════════════════════════════════════════════════════════════════════
  //  TAB: SISTEMA
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildSistema() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SectionLabel(label: 'TERMOS E POLÍTICAS'),
        const SizedBox(height: 10),
        _SistemaCard(
          icon:      Icons.gavel_rounded,
          titulo:    'Código de Conduta',
          subtitulo: 'Título VII – Art. 18º ao 20º',
          descricao: 'Usuários podem denunciar conteúdos. '
              'A equipe analisa e pode advertir, suspender ou excluir. '
              'Medidas legais podem ser tomadas em casos graves.',
        ),
        const SizedBox(height: 10),
        _SistemaCard(
          icon:      Icons.shield_outlined,
          titulo:    'Política de Privacidade',
          subtitulo: 'LGPD – Art. 3º e 4º',
          descricao: 'Dados não são compartilhados para fins comerciais. '
              'Apenas prestadores essenciais têm acesso limitado.',
        ),
        const SizedBox(height: 10),
        _SistemaCard(
          icon:      Icons.remove_moderator_outlined,
          titulo:    'Remoção de Conteúdo',
          subtitulo: 'Termos de Uso – Art. 10º',
          descricao: 'O Tabu pode remover conteúdo que: '
              '(I) viole a lei; (II) seja ofensivo ou discriminatório; '
              '(III) comprometa a segurança do app.',
        ),
        const SizedBox(height: 24),
        const SizedBox(height: 24),
          _SectionLabel(label: 'ACESSO'),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (_, animation, __) =>
                    InviteCodeScreen(adminUid: widget.adminUid),
                transitionsBuilder: (_, animation, __, child) => SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(1, 0), end: Offset.zero)
                      .animate(CurvedAnimation(
                        parent: animation, curve: Curves.easeOutCubic)),
                  child: child),
                transitionDuration: const Duration(milliseconds: 280),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:  TabuColors.rosaDeep.withOpacity(0.1),
                border: Border.all(
                  color: TabuColors.rosaPrincipal.withOpacity(0.3), width: 0.8)),
              child: Row(children: [
                const Icon(Icons.vpn_key_rounded,
                  color: TabuColors.rosaPrincipal, size: 18),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: const [
                  Text('Código de Convite',
                    style: TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: Colors.white, letterSpacing: 0.5)),
                  SizedBox(height: 2),
                  Text('Gerenciar e trocar o código de acesso',
                    style: TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 9, color: Colors.white38, letterSpacing: 0.3)),
                ])),
                const Icon(Icons.chevron_right_rounded,
                  color: TabuColors.rosaPrincipal, size: 16),
              ]),
            ),
          ),
        _SectionLabel(label: 'CONTATO'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:  Colors.white.withOpacity(0.03),
            border: Border.all(
              color: Colors.white.withOpacity(0.08), width: 0.8)),
          child: const Row(children: [
            Icon(Icons.email_outlined, color: TabuColors.rosaPrincipal, size: 18),
            SizedBox(width: 12),
            Expanded(child: Text('tabuadministrative@gmail.com',
              style: TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 12, color: Colors.white70, letterSpacing: 0.3))),
          ])),
        const SizedBox(height: 80),
      ]),
    );
  }

  Widget _loadingWidget() => const Center(
    child: SizedBox(width: 22, height: 22,
      child: CircularProgressIndicator(strokeWidth: 1.5,
        valueColor: AlwaysStoppedAnimation(TabuColors.rosaPrincipal))));

  Widget _emptyState({required IconData icon, required String label}) =>
    Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: Colors.white12, size: 36),
      const SizedBox(height: 12),
      Text(label, style: const TextStyle(
        fontFamily: TabuTypography.bodyFont,
        fontSize: 9, fontWeight: FontWeight.w700,
        letterSpacing: 2.5, color: Colors.white24)),
    ]));
}

// ══════════════════════════════════════════════════════════════════════════════
//  REPORT TILE (atualizado com onTap para abrir detalhes)
// ══════════════════════════════════════════════════════════════════════════════
class _ReportTile extends StatelessWidget {
  final Map<String, dynamic> report;
  final String               tipo;
  final VoidCallback         onTap;      // ← novo: abre detalhe
  final VoidCallback         onDismiss;
  final VoidCallback         onDelete;

  const _ReportTile({
    required this.report,
    required this.tipo,
    required this.onTap,
    required this.onDismiss,
    required this.onDelete,
  });

  Color get _statusColor {
    switch (report['status'] as String? ?? 'pending') {
      case 'pending':   return const Color(0xFFD4AF37);
      case 'actioned':  return const Color(0xFF4CAF50);
      case 'dismissed': return Colors.white24;
      default:          return Colors.white24;
    }
  }

  String get _statusLabel {
    switch (report['status'] as String? ?? 'pending') {
      case 'pending':   return 'PENDENTE';
      case 'actioned':  return 'RESOLVIDO';
      case 'dismissed': return 'IGNORADO';
      default:          return '—';
    }
  }

  String get _tipoDisplay {
    switch (tipo) {
      case 'posts':   return 'POST';
      case 'stories': return 'STORY';
      case 'users':   return 'USUÁRIO';
      case 'chats':   return 'CHAT';
      default:        return tipo.toUpperCase();
    }
  }

  Color get _tipoColor {
    switch (tipo) {
      case 'posts':   return Colors.white54;
      case 'stories': return TabuColors.rosaPrincipal;
      case 'users':   return const Color(0xFFD4AF37);
      case 'chats':   return const Color(0xFF4FC3F7);
      default:        return Colors.white38;
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
    final isPending = (report['status'] as String? ?? 'pending') == 'pending';
    final artigo    = report['artigo']       as String? ?? '—';
    final motivo    = report['motivo_label'] as String?
        ?? report['motivo'] as String? ?? '—';
    final descricao = report['descricao']    as String? ?? '';
    final reporter  = report['reporter_uid'] as String? ?? '—';
    final ts        = report['created_at']   as int?;
    final protocolo = report['protocolo']    as String?;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: TabuColors.rosaPrincipal.withOpacity(0.05),
        highlightColor: TabuColors.rosaPrincipal.withOpacity(0.03),
        child: Container(
          color: isPending
              ? TabuColors.rosaDeep.withOpacity(0.04)
              : Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Row superior
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  color: _tipoColor.withOpacity(0.12),
                  child: Text(_tipoDisplay,
                    style: TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 8, fontWeight: FontWeight.w700,
                      letterSpacing: 2, color: _tipoColor))),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _statusColor.withOpacity(0.4), width: 0.7)),
                  child: Text(_statusLabel,
                    style: TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 8, fontWeight: FontWeight.w700,
                      letterSpacing: 2, color: _statusColor))),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded,
                  color: Colors.white12, size: 14),
                const SizedBox(width: 4),
                Text(_formatTs(ts),
                  style: const TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 9, color: Colors.white24, letterSpacing: 0.3)),
              ]),

              const SizedBox(height: 10),

              Text(motivo,
                style: const TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: Colors.white, letterSpacing: 0.3)),
              const SizedBox(height: 3),
              Text(artigo,
                style: TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 9, letterSpacing: 1.5,
                  color: TabuColors.rosaPrincipal.withOpacity(0.7))),

              if (descricao.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  color: Colors.white.withOpacity(0.03),
                  child: Text(descricao, maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 11, height: 1.5,
                      color: Colors.white54, letterSpacing: 0.2))),
              ],

              const SizedBox(height: 8),
              Text('Denunciado por: $reporter',
                style: const TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 9, color: Colors.white24, letterSpacing: 0.3)),

              // Protocolo (se já resolvido)
              if (protocolo != null) ...[
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.tag_rounded,
                    color: Colors.white12, size: 10),
                  const SizedBox(width: 4),
                  Text(protocolo,
                    style: const TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 8, color: Colors.white24, letterSpacing: 1)),
                ]),
              ],

              // Ações rápidas (só pendentes)
              if (isPending) ...[
                const SizedBox(height: 12),
                Row(children: [
                  // Ver detalhes
                  Expanded(child: GestureDetector(
                    onTap: onTap,
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color:  TabuColors.rosaDeep.withOpacity(0.12),
                        border: Border.all(
                          color: TabuColors.rosaPrincipal.withOpacity(0.3),
                          width: 0.8)),
                      child: const Center(child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.open_in_new_rounded,
                            color: TabuColors.rosaPrincipal, size: 11),
                          SizedBox(width: 6),
                          Text('VER DETALHES',
                            style: TextStyle(
                              fontFamily: TabuTypography.bodyFont,
                              fontSize: 9, fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                              color: TabuColors.rosaPrincipal)),
                        ])),
                    ))),
                  const SizedBox(width: 6),
                  // Ignorar
                  GestureDetector(
                    onTap: onDismiss,
                    child: Container(
                      width: 70, height: 36,
                      decoration: BoxDecoration(
                        color:  Colors.white.withOpacity(0.04),
                        border: Border.all(color: Colors.white12, width: 0.8)),
                      child: const Center(child: Text('IGNORAR',
                        style: TextStyle(
                          fontFamily: TabuTypography.bodyFont,
                          fontSize: 8, fontWeight: FontWeight.w700,
                          letterSpacing: 1.5, color: Colors.white38))))),
                ]),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  USER ADMIN TILE
// ══════════════════════════════════════════════════════════════════════════════
class _UserAdminTile extends StatelessWidget {
  final Map<String, dynamic> user;
  const _UserAdminTile({required this.user});

  
  @override
  Widget build(BuildContext context) {
    final name    = (user['name']   as String? ?? '—').toUpperCase();
    final email   =  user['email']  as String? ?? '';
    final city    =  user['city']   as String? ?? '';
    final state   =  user['state']  as String? ?? '';
    final vip     = (user['vip_lists'] as num? ?? 0).toInt();
    final partys  = (user['partys']    as num? ?? 0).toInt();
    final online  = (user['presence']  as Map?)?['online'] as bool? ?? false;
    final banido  = user['banido']  as bool? ?? false;
    final suspenso = user['suspenso'] as bool? ?? false;
    final reportCount = (user['report_count'] as num? ?? 0).toInt();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(children: [
        Container(width: 6, height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: banido    ? const Color(0xFFE85D5D)
                 : suspenso  ? const Color(0xFFFF8C00)
                 : online    ? const Color(0xFF4CAF50)
                 : Colors.white12)),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
            style: const TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 12, fontWeight: FontWeight.w700,
              letterSpacing: 1.5, color: Colors.white)),
          if (email.isNotEmpty)
            Text(email,
              style: const TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 9, color: Colors.white30, letterSpacing: 0.3)),
          if (city.isNotEmpty)
            Text('$city, $state',
              style: const TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 9, color: Colors.white24, letterSpacing: 0.3)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (banido)
            _badge('BANIDO', const Color(0xFFE85D5D))
          else if (suspenso)
            _badge('SUSPENSO', const Color(0xFFFF8C00)),
          if (reportCount > 0) _badge('$reportCount reports', Colors.white30),
          if (vip > 0) Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.star_rounded,
              color: Color(0xFFD4AF37), size: 10),
            const SizedBox(width: 3),
            Text('$vip VIP',
              style: const TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 9, color: Color(0xFFD4AF37), letterSpacing: 1)),
          ]),
          Text('$partys festas',
            style: const TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 9, color: Colors.white24, letterSpacing: 0.5)),
        ]),
      ]),
    );
  }

  Widget _badge(String label, Color color) => Container(
    margin: const EdgeInsets.only(bottom: 3),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      border: Border.all(color: color.withOpacity(0.5), width: 0.6)),
    child: Text(label,
      style: TextStyle(
        fontFamily: TabuTypography.bodyFont,
        fontSize: 7, fontWeight: FontWeight.w700,
        letterSpacing: 1.5, color: color)));
}

// ══════════════════════════════════════════════════════════════════════════════
//  SISTEMA CARD
// ══════════════════════════════════════════════════════════════════════════════
class _SistemaCard extends StatelessWidget {
  final IconData icon;
  final String   titulo;
  final String   subtitulo;
  final String   descricao;

  const _SistemaCard({
    required this.icon,
    required this.titulo,
    required this.subtitulo,
    required this.descricao,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color:  Colors.white.withOpacity(0.03),
      border: Border.all(
        color: Colors.white.withOpacity(0.07), width: 0.8)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: TabuColors.rosaPrincipal.withOpacity(0.7), size: 18),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titulo,
          style: const TextStyle(
            fontFamily: TabuTypography.bodyFont,
            fontSize: 12, fontWeight: FontWeight.w700,
            color: Colors.white, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(subtitulo,
          style: TextStyle(
            fontFamily: TabuTypography.bodyFont,
            fontSize: 9, letterSpacing: 1.5,
            color: TabuColors.rosaPrincipal.withOpacity(0.6))),
        const SizedBox(height: 8),
        Text(descricao,
          style: const TextStyle(
            fontFamily: TabuTypography.bodyFont,
            fontSize: 11, height: 1.6,
            color: Colors.white38, letterSpacing: 0.2)),
      ])),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  HELPERS
// ══════════════════════════════════════════════════════════════════════════════
class _StatChip extends StatelessWidget {
  final String   label;
  final String   value;
  final IconData icon;
  final bool     highlight;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) => Expanded(child: Column(
    mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 12,
      color: highlight ? TabuColors.rosaPrincipal : Colors.white24),
    const SizedBox(height: 4),
    Text(value, style: TextStyle(
      fontFamily: TabuTypography.displayFont,
      fontSize: 16, letterSpacing: 1,
      color: highlight ? TabuColors.rosaPrincipal : Colors.white,
      shadows: highlight ? [Shadow(
        color: TabuColors.glow.withOpacity(0.6), blurRadius: 8)] : null)),
    const SizedBox(height: 2),
    Text(label, style: const TextStyle(
      fontFamily: TabuTypography.bodyFont,
      fontSize: 7, fontWeight: FontWeight.w700,
      letterSpacing: 1.5, color: Colors.white24)),
  ]));
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
    Container(width: 0.5, height: 30, color: Colors.white10);
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 2, height: 12, color: TabuColors.rosaPrincipal),
    const SizedBox(width: 8),
    Text(label, style: const TextStyle(
      fontFamily: TabuTypography.bodyFont,
      fontSize: 9, fontWeight: FontWeight.w700,
      letterSpacing: 2.5, color: Colors.white38)),
  ]);
}

//══════════════════════════════════════════════════════════════════════════════
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
