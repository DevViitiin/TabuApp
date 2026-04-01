import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  MODELO DE ARTIGO
// ══════════════════════════════════════════════════════════════════════════════
class ArtigoTabu {
  final String codigo;
  final String fonte;
  final String titulo;
  final String descricaoBase;

  const ArtigoTabu({
    required this.codigo,
    required this.fonte,
    required this.titulo,
    required this.descricaoBase,
  });

  String get label => '$codigo – $titulo';
}

const List<ArtigoTabu> kArtigosTabu = [
  ArtigoTabu(
    codigo: 'Art. 1º – TU', fonte: 'Termos de Uso',
    titulo: 'Restrição de idade (18+)',
    descricaoBase: 'Você está sendo penalizado porque utilizou o Tabu sendo menor de 18 anos, '
        'ou forneceu dados falsos para burlar a restrição etária da plataforma. '
        'O acesso ao app é exclusivo para maiores de idade e sua conduta viola diretamente essa regra.',
  ),
  ArtigoTabu(
    codigo: 'Art. 4º – TU', fonte: 'Termos de Uso',
    titulo: 'Informações de cadastro falsas',
    descricaoBase: 'Você está sendo penalizado porque criou sua conta com informações falsas ou '
        'deliberadamente incorretas. Mentir no cadastro é uma violação direta dos Termos de Uso '
        'e compromete a integridade da plataforma para todos os outros usuários.',
  ),
  ArtigoTabu(
    codigo: 'Art. 5º – TU', fonte: 'Termos de Uso',
    titulo: 'Comprometimento de segurança da conta',
    descricaoBase: 'Você está sendo penalizado porque sua conta foi utilizada de forma indevida, '
        'seja por compartilhamento de acesso, negligência com suas credenciais ou '
        'permissão de uso por terceiros. Você é o único responsável por tudo que acontece na sua conta.',
  ),
  ArtigoTabu(
    codigo: 'Art. 6º – TU', fonte: 'Termos de Uso',
    titulo: 'Informações fraudulentas',
    descricaoBase: 'Você está sendo penalizado porque foram identificadas fraudes ou inconsistências '
        'graves nas informações vinculadas à sua conta. Contas com dados fraudulentos '
        'são passíveis de suspensão imediata ou exclusão definitiva da plataforma.',
  ),
  ArtigoTabu(
    codigo: 'Art. 9º – TU', fonte: 'Termos de Uso',
    titulo: 'Responsabilidade pelo conteúdo publicado',
    descricaoBase: 'Você está sendo penalizado porque publicou ou compartilhou conteúdo impróprio '
        'na plataforma. Tudo o que você posta é de sua responsabilidade — '
        'não existe "foi sem querer" ou "era uma brincadeira" como justificativa válida.',
  ),
  ArtigoTabu(
    codigo: 'Art. 10º, I – TU', fonte: 'Termos de Uso',
    titulo: 'Conteúdo ilegal',
    descricaoBase: 'Você está sendo penalizado porque publicou conteúdo que viola a lei. '
        'A plataforma não tolera qualquer tipo de conteúdo ilegal e se reserva o direito '
        'de reportar o caso às autoridades competentes caso necessário.',
  ),
  ArtigoTabu(
    codigo: 'Art. 10º, II – TU', fonte: 'Termos de Uso',
    titulo: 'Conteúdo ofensivo, discriminatório ou prejudicial',
    descricaoBase: 'Você está sendo penalizado porque seu conteúdo foi considerado ofensivo, '
        'discriminatório ou diretamente prejudicial a outros usuários. '
        'Esse tipo de comportamento não será tolerado e pode resultar em punições progressivas.',
  ),
  ArtigoTabu(
    codigo: 'Art. 10º, III – TU', fonte: 'Termos de Uso',
    titulo: 'Comprometimento da segurança do app',
    descricaoBase: 'Você está sendo penalizado porque seu comportamento ou conteúdo colocou '
        'em risco a segurança e a integridade do aplicativo. Isso inclui tentativas '
        'de explorar brechas, disseminar malware ou prejudicar a experiência de outros usuários.',
  ),
  ArtigoTabu(
    codigo: 'Art. 18º – TU', fonte: 'Termos de Uso',
    titulo: 'Violação sujeita a denúncia',
    descricaoBase: 'Você está sendo penalizado porque sua conduta foi denunciada por outros usuários '
        'e a equipe do Tabu confirmou a violação após análise. '
        'Reincidências serão tratadas com punições cada vez mais severas.',
  ),
  ArtigoTabu(
    codigo: 'Art. 19º – TU', fonte: 'Termos de Uso',
    titulo: 'Aplicação de penalidade formal',
    descricaoBase: 'Você está sendo penalizado formalmente após análise da equipe do Tabu. '
        'Esta penalidade foi aplicada dentro dos critérios previstos nos Termos de Uso '
        'e representa uma medida oficial da plataforma contra sua conduta.',
  ),
  ArtigoTabu(
    codigo: 'Art. 20º – TU', fonte: 'Termos de Uso',
    titulo: 'Violação grave – medidas legais',
    descricaoBase: 'Você está sendo penalizado por uma violação considerada grave pela equipe do Tabu. '
        'Além da punição na plataforma, o Tabu se reserva o direito de tomar as medidas '
        'legais cabíveis, incluindo registro de boletim de ocorrência e acionamento judicial.',
  ),
  ArtigoTabu(
    codigo: 'Art. 2º – PP', fonte: 'Política de Privacidade',
    titulo: 'Uso indevido de dados pessoais',
    descricaoBase: 'Você está sendo penalizado porque utilizou ou tentou utilizar dados pessoais '
        'de outros usuários de forma não autorizada. Dados coletados pela plataforma '
        'existem para o funcionamento do app — qualquer uso fora disso é uma violação grave.',
  ),
  ArtigoTabu(
    codigo: 'Art. 3º – PP', fonte: 'Política de Privacidade',
    titulo: 'Compartilhamento não autorizado de dados',
    descricaoBase: 'Você está sendo penalizado porque compartilhou ou expôs dados pessoais de '
        'outros usuários sem consentimento. Isso inclui prints, repasses em grupos externos '
        'e qualquer forma de divulgação não autorizada de informações privadas.',
  ),
  ArtigoTabu(
    codigo: 'Art. 5º – PP', fonte: 'Política de Privacidade',
    titulo: 'Exposição indevida de dados de terceiros',
    descricaoBase: 'Você está sendo penalizado porque publicou conteúdo que expõe informações '
        'privadas de outras pessoas sem autorização. Você é responsável por tudo que '
        'publica, inclusive quando envolve dados de terceiros.',
  ),
  ArtigoTabu(
    codigo: 'Art. 6º – PP', fonte: 'Política de Privacidade',
    titulo: 'Violação da política de privacidade',
    descricaoBase: 'Você está sendo penalizado porque seu conteúdo ou comportamento viola '
        'diretamente a Política de Privacidade do Tabu. O conteúdo em questão '
        'foi ou será removido, e punições adicionais podem ser aplicadas.',
  ),
  ArtigoTabu(
    codigo: 'Art. 8º – PP', fonte: 'Política de Privacidade',
    titulo: 'Comprometimento de credenciais',
    descricaoBase: 'Você está sendo penalizado porque suas credenciais foram comprometidas '
        'por negligência ou uso irresponsável. A segurança da sua conta é sua '
        'responsabilidade — qualquer acesso não autorizado decorrente disso recai sobre você.',
  ),
];

// ══════════════════════════════════════════════════════════════════════════════
//  ENUM DE AÇÕES
// ══════════════════════════════════════════════════════════════════════════════
enum AcaoAdmin {
  ignorar, advertencia, suspensao, banimento, removerConteudo,
}

extension AcaoAdminX on AcaoAdmin {
  String get id {
    switch (this) {
      case AcaoAdmin.ignorar:         return 'ignorar';
      case AcaoAdmin.advertencia:     return 'advertencia';
      case AcaoAdmin.suspensao:       return 'suspensao';
      case AcaoAdmin.banimento:       return 'banimento';
      case AcaoAdmin.removerConteudo: return 'remover_conteudo';
    }
  }
  String get label {
    switch (this) {
      case AcaoAdmin.ignorar:         return 'IGNORAR';
      case AcaoAdmin.advertencia:     return 'ADVERTÊNCIA';
      case AcaoAdmin.suspensao:       return 'SUSPENSÃO';
      case AcaoAdmin.banimento:       return 'BANIMENTO';
      case AcaoAdmin.removerConteudo: return 'REMOVER CONTEÚDO';
    }
  }
  String get descricao {
    switch (this) {
      case AcaoAdmin.ignorar:         return 'Nenhuma medida. Denúncia arquivada como improcedente.';
      case AcaoAdmin.advertencia:     return 'Notifica o usuário formalmente. Sem bloqueio de acesso.';
      case AcaoAdmin.suspensao:       return 'Bloqueia o acesso do usuário por período determinado.';
      case AcaoAdmin.banimento:       return 'Remove o acesso permanentemente. Ação irreversível.';
      case AcaoAdmin.removerConteudo: return 'Apaga o conteúdo denunciado da plataforma.';
    }
  }
  Color get cor {
    switch (this) {
      case AcaoAdmin.ignorar:         return Colors.white24;
      case AcaoAdmin.advertencia:     return const Color(0xFFD4AF37);
      case AcaoAdmin.suspensao:       return const Color(0xFFFF8C00);
      case AcaoAdmin.banimento:       return const Color(0xFFE85D5D);
      case AcaoAdmin.removerConteudo: return const Color(0xFFE85D5D);
    }
  }
  IconData get icon {
    switch (this) {
      case AcaoAdmin.ignorar:         return Icons.check_circle_outline_rounded;
      case AcaoAdmin.advertencia:     return Icons.warning_amber_rounded;
      case AcaoAdmin.suspensao:       return Icons.pause_circle_outline_rounded;
      case AcaoAdmin.banimento:       return Icons.block_rounded;
      case AcaoAdmin.removerConteudo: return Icons.delete_outline_rounded;
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class ReportDetailScreen extends StatefulWidget {
  final Map<String, dynamic> report;
  final String               tipo;
  final String               reportKey;

  const ReportDetailScreen({
    super.key,
    required this.report,
    required this.tipo,
    required this.reportKey,
  });

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  final _db        = FirebaseDatabase.instance.ref();
  final _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  Map<String, dynamic>? _conteudoDenunciado;
  Map<String, dynamic>? _reportedUser;
  bool _loadingConteudo = true;
  bool _processando     = false;
  String? _protocolo;

  AcaoAdmin?   _acaoSelecionada;
  ArtigoTabu?  _artigoSelecionado;
  bool         _editandoArtigo   = false;
  bool         _descricaoEditada = false;

  final _artigoCustomCtrl = TextEditingController();
  final _motivoCtrl       = TextEditingController();
  DateTime? _suspensaoInicio;
  DateTime? _suspensaoFim;

  String get _tipoLabel => widget.tipo == 'posts'   ? 'POST'
                         : widget.tipo == 'stories' ? 'STORY'
                         : widget.tipo == 'users'   ? 'USUÁRIO'
                         : 'CHAT';

  String get _artigoFinalCodigo {
    if (_editandoArtigo) return _artigoCustomCtrl.text.trim();
    return _artigoSelecionado?.codigo ?? '';
  }

  @override
  void initState() {
    super.initState();
    final artigoInicial = widget.report['artigo'] as String?;
    if (artigoInicial != null && artigoInicial.isNotEmpty) {
      final match = kArtigosTabu.where(
        (a) => a.codigo.toLowerCase() == artigoInicial.toLowerCase(),
      ).firstOrNull;
      if (match != null) {
        _artigoSelecionado = match;
        _motivoCtrl.text   = match.descricaoBase;
      } else {
        _editandoArtigo        = true;
        _artigoCustomCtrl.text = artigoInicial;
      }
    }
    _carregarConteudo();
  }

  @override
  void dispose() {
    _motivoCtrl.dispose();
    _artigoCustomCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _carregarConteudo() async {
    setState(() => _loadingConteudo = true);
    try {
      final r = widget.report;
      if (widget.tipo == 'posts') {
        final postId = r['post_id'] as String?;
        if (postId != null) {
          final snap = await _db.child('Posts/post/$postId').get();
          if (snap.exists) _conteudoDenunciado = Map<String, dynamic>.from(snap.value as Map);
        }
        final ownerUid = r['post_owner_id'] as String?;
        if (ownerUid != null) await _carregarUsuario(ownerUid);
      } else if (widget.tipo == 'stories') {
        final storyId = r['story_id'] as String?;
        if (storyId != null) {
          final snap = await _db.child('Posts/story/$storyId').get();
          if (snap.exists) _conteudoDenunciado = Map<String, dynamic>.from(snap.value as Map);
        }
        final ownerUid = r['story_owner_id'] as String?;
        if (ownerUid != null) await _carregarUsuario(ownerUid);
      } else if (widget.tipo == 'users') {
        final uid = r['reported_user_id'] as String?;
        if (uid != null) await _carregarUsuario(uid);
      } else if (widget.tipo == 'chats') {
        final chatId = r['chat_id'] as String?;
        if (chatId != null) {
          final snap = await _db.child('ChatMessages/$chatId').get();
          if (snap.exists) _conteudoDenunciado = Map<String, dynamic>.from(snap.value as Map);
        }
        final reportedUid = r['reported_uid'] as String?;
        if (reportedUid != null) await _carregarUsuario(reportedUid);
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingConteudo = false);
  }

  Future<void> _carregarUsuario(String uid) async {
    final snap = await _db.child('Users/$uid').get();
    if (snap.exists) {
      _reportedUser         = Map<String, dynamic>.from(snap.value as Map);
      _reportedUser!['uid'] = uid;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _processarAcao() async {
    if (_acaoSelecionada == null) return;
    if (_artigoFinalCodigo.isEmpty) { _snack('Selecione ou informe o artigo violado.'); return; }
    if (_motivoCtrl.text.trim().isEmpty) { _snack('Preencha a justificativa / descrição da infração.'); return; }

    HapticFeedback.mediumImpact();
    setState(() => _processando = true);

    try {
      final callable = _functions.httpsCallable('processarDenuncia');
      final result   = await callable.call({
        'denunciaId':    widget.reportKey,
        'denunciaTipo':  widget.tipo,
        'acao':          _acaoSelecionada!.id,
        'motivoAdmin':   _motivoCtrl.text.trim(),
        'artigoViolado': _artigoFinalCodigo,
        if (_acaoSelecionada == AcaoAdmin.suspensao) ...{
          'suspensaoInicio': _suspensaoInicio?.millisecondsSinceEpoch,
          'suspensaoFim':    _suspensaoFim?.millisecondsSinceEpoch,
        },
      });
      final proto = result.data['protocolo'] as String? ?? '—';
      if (mounted) setState(() { _protocolo = proto; _processando = false; });
      await _mostrarSucesso(proto);
    } on FirebaseFunctionsException catch (e) {
      if (mounted) { setState(() => _processando = false); _snack('Erro: ${e.message}'); }
    } catch (_) {
      if (mounted) { setState(() => _processando = false); _snack('Erro inesperado. Tente novamente.'); }
    }
  }

  Future<void> _mostrarSucesso(String protocolo) async {
    await showModalBottomSheet(
      context:          context,
      backgroundColor:  const Color(0xFF0D0020),
      isDismissible:    false,
      isScrollControlled: true,        // FIX: permite que o sheet use altura variável
      shape:            const RoundedRectangleBorder(),
      builder: (_) => _SucessoSheet(
        protocolo: protocolo,
        acao:      _acaoSelecionada!,
        onOk: () { Navigator.pop(context); Navigator.pop(context); },
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(
        fontFamily: TabuTypography.bodyFont, fontSize: 11, letterSpacing: 0.5)),
      backgroundColor: const Color(0xFF1A0030),
    ));
  }

  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isPending = (widget.report['status'] as String? ?? 'pending') == 'pending';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF07000F),
        // FIX: resizeToAvoidBottomInset evita que o teclado quebre o layout
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          // FIX: SafeArea envolve TODA a tela, inclusive o header
          child: Column(children: [
            _buildHeader(),
            Expanded(child: SingleChildScrollView(
              padding: EdgeInsets.only(
                // FIX: padding bottom dinâmico respeita home indicator / barra de navegação
                bottom: MediaQuery.of(context).padding.bottom + 24,
              ),
              child: Column(children: [
                _buildInfoDenuncia(),
                if (_reportedUser != null) _buildReportedUser(),
                _buildConteudoDenunciado(),
                if (_reportedUser != null) _buildHistoricoPenalidades(),
                if (!isPending) _buildJaResolvido(),
                if (isPending && _protocolo == null) _buildFormAcao(),
              ]),
            )),
          ]),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x33FF2D7A), width: 0.8)),
      ),
      // FIX: removido SafeArea interno — já está coberto pelo SafeArea externo no build()
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Row(children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38, height: 38,
              color: Colors.transparent,
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white54, size: 18)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: TabuColors.rosaDeep,
                child: Text(_tipoLabel,
                  style: const TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 8, fontWeight: FontWeight.w700,
                    letterSpacing: 2, color: Colors.white))),
              const SizedBox(width: 10),
              const Text('DENÚNCIA · DETALHES',
                style: TextStyle(
                  fontFamily: TabuTypography.displayFont,
                  fontSize: 11, letterSpacing: 3, color: Colors.white)),
            ]),
            const SizedBox(height: 3),
            Text(widget.reportKey,
              style: TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 8, letterSpacing: 0.5,
                color: Colors.white.withOpacity(0.2))),
          ])),
        ]),
      ),
    );
  }

  // ── Info da denúncia ──────────────────────────────────────────────────────
  Widget _buildInfoDenuncia() {
    final r         = widget.report;
    final motivo    = r['motivo_label'] as String? ?? r['motivo'] as String? ?? '—';
    final artigo    = r['artigo']       as String? ?? '—';
    final descricao = r['descricao']    as String? ?? '';
    final reporter  = r['reporter_uid'] as String? ?? '—';
    final ts        = r['created_at']   as int?;
    final status    = r['status']       as String? ?? 'pending';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:  Colors.white.withOpacity(0.03),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 0.8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('DETALHES DA DENÚNCIA'),
        const SizedBox(height: 14),
        _infoRow('MOTIVO', motivo, TabuColors.rosaPrincipal),
        const SizedBox(height: 8),
        _infoRow('ARTIGO', artigo, Colors.white54),
        const SizedBox(height: 8),
        _infoRow('DENUNCIANTE', reporter, Colors.white38),
        if (ts != null) ...[
          const SizedBox(height: 8),
          _infoRow('DATA', _formatData(ts), Colors.white38),
        ],
        const SizedBox(height: 8),
        _infoRow('STATUS', status.toUpperCase(), _statusColor(status)),
        if (descricao.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.white.withOpacity(0.03),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('DESCRIÇÃO',
                style: TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 8, fontWeight: FontWeight.w700,
                  letterSpacing: 2, color: Colors.white.withOpacity(0.3))),
              const SizedBox(height: 6),
              Text(descricao,
                style: const TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 12, height: 1.6, color: Colors.white70)),
            ])),
        ],
      ]),
    );
  }

  // ── Usuário denunciado ────────────────────────────────────────────────────
  Widget _buildReportedUser() {
    final u           = _reportedUser!;
    final name        = (u['name'] as String? ?? '—').toUpperCase();
    final email       = u['email']  as String? ?? '';
    final city        = u['city']   as String? ?? '';
    final state       = u['state']  as String? ?? '';
    final banido      = u['banido']    as bool? ?? false;
    final suspenso    = u['suspenso']  as bool? ?? false;
    final reportCount = (u['report_count'] as num? ?? 0).toInt();
    final penalidadeAtiva = u['penalidade_ativa'] as String?;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        border: Border.all(
          color: banido   ? const Color(0xFFE85D5D).withOpacity(0.4)
               : suspenso ? const Color(0xFFFF8C00).withOpacity(0.4)
               : Colors.white.withOpacity(0.08),
          width: 0.8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('USUÁRIO DENUNCIADO'),
        const SizedBox(height: 14),
        Row(children: [
          Container(width: 46, height: 46,
            decoration: BoxDecoration(
              color: TabuColors.rosaDeep.withOpacity(0.3),
              border: Border.all(color: TabuColors.rosaPrincipal.withOpacity(0.3))),
            child: const Icon(Icons.person_outline,
              color: TabuColors.rosaPrincipal, size: 20)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
              style: const TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 14, fontWeight: FontWeight.w700,
                letterSpacing: 1.5, color: Colors.white)),
            if (email.isNotEmpty)
              Text(email,
                style: const TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 10, color: Colors.white38, letterSpacing: 0.3)),
            if (city.isNotEmpty)
              Text('$city · $state',
                style: const TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 9, color: Colors.white24)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (banido)       _statusBadge('BANIDO',   const Color(0xFFE85D5D))
            else if (suspenso) _statusBadge('SUSPENSO', const Color(0xFFFF8C00))
            else if (penalidadeAtiva != null)
              _statusBadge(penalidadeAtiva.toUpperCase(), const Color(0xFFD4AF37)),
            if (reportCount > 0) ...[
              const SizedBox(height: 4),
              _statusBadge('$reportCount REPORTS', Colors.white30),
            ],
          ]),
        ]),
      ]),
    );
  }

  // ── Conteúdo denunciado ───────────────────────────────────────────────────
  Widget _buildConteudoDenunciado() {
    if (_loadingConteudo) return _loadingCard();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:  Colors.white.withOpacity(0.03),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 0.8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('CONTEÚDO DENUNCIADO'),
        const SizedBox(height: 14),
        if (_conteudoDenunciado == null)
          Text('Conteúdo não encontrado ou já removido.',
            style: TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 12, color: Colors.white38))
        else if (widget.tipo == 'posts' || widget.tipo == 'stories')
          _buildConteudoPost(_conteudoDenunciado!)
        else if (widget.tipo == 'chats')
          _buildConteudoChat(_conteudoDenunciado!),
      ]),
    );
  }

  Widget _buildConteudoPost(Map<String, dynamic> c) {
    final titulo    = c['titulo']       as String? ?? c['central_text']  as String? ?? '—';
    final descricao = c['descricao']    as String? ?? '';
    final tipo      = c['tipo']         as String? ?? c['type']          as String? ?? '—';
    final emoji     = c['emoji']        as String? ?? c['central_emoji'] as String?;
    final mediaUrl  = c['media_url']    as String?;
    final userName  = c['user_name']    as String? ?? '—';
    final likes     = (c['likes']       as num? ?? 0).toInt();
    final views     = (c['view_count']  as num? ?? 0).toInt();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          color: Colors.white.withOpacity(0.06),
          child: Text(tipo.toUpperCase(),
            style: const TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 8, fontWeight: FontWeight.w700,
              letterSpacing: 2, color: Colors.white54))),
        const SizedBox(width: 8),
        Text('por $userName',
          style: const TextStyle(
            fontFamily: TabuTypography.bodyFont,
            fontSize: 10, color: Colors.white38)),
      ]),
      const SizedBox(height: 10),
      if (emoji != null)
        Center(child: Container(
          width: double.infinity, height: 100,
          color: Colors.white.withOpacity(0.03),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 48))))),
      if (mediaUrl != null)
        ClipRect(child: SizedBox(
          height: 180, width: double.infinity,
          child: Image.network(mediaUrl, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 80, color: Colors.white.withOpacity(0.03),
              child: const Center(child: Icon(
                Icons.broken_image_outlined, color: Colors.white24)))))),
      if (titulo.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text(titulo,
          style: const TextStyle(
            fontFamily: TabuTypography.bodyFont,
            fontSize: 14, fontWeight: FontWeight.w600,
            color: Colors.white, letterSpacing: 0.3)),
      ],
      if (descricao.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(descricao,
          style: const TextStyle(
            fontFamily: TabuTypography.bodyFont,
            fontSize: 12, height: 1.5, color: Colors.white54)),
      ],
      const SizedBox(height: 10),
      Row(children: [
        const Icon(Icons.favorite_border_rounded, color: Colors.white24, size: 12),
        const SizedBox(width: 4),
        Text('$likes curtidas',
          style: const TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 9, color: Colors.white24)),
        if (views > 0) ...[
          const SizedBox(width: 12),
          const Icon(Icons.visibility_outlined, color: Colors.white24, size: 12),
          const SizedBox(width: 4),
          Text('$views visualizações',
            style: const TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 9, color: Colors.white24)),
        ],
      ]),
    ]);
  }

  Widget _buildConteudoChat(Map<String, dynamic> msgs) {
    final entries = msgs.entries
        .where((e) => e.key != 'rs' && e.value is Map)
        .map((e) => Map<String, dynamic>.from(e.value as Map))
        .toList()
      ..sort((a, b) =>
        (a['timestamp'] as int? ?? 0).compareTo(b['timestamp'] as int? ?? 0));

    final reported = widget.report['reported_uid'] as String? ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entries.map((msg) {
        final sender     = msg['sender_id'] as String? ?? '';
        final text       = msg['text']      as String? ?? '';
        final ts         = msg['timestamp'] as int?;
        final isReported = sender == reported;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isReported
                ? const Color(0xFFE85D5D).withOpacity(0.06)
                : Colors.white.withOpacity(0.03),
            border: Border.all(
              color: isReported
                  ? const Color(0xFFE85D5D).withOpacity(0.2)
                  : Colors.white.withOpacity(0.05),
              width: 0.6)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (isReported)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                margin: const EdgeInsets.only(right: 8, top: 2),
                color: const Color(0xFFE85D5D).withOpacity(0.2),
                child: const Text('●',
                  style: TextStyle(fontSize: 6, color: Color(0xFFE85D5D)))),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(text,
                style: TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 12, height: 1.5,
                  color: isReported ? Colors.white70 : Colors.white38)),
              if (ts != null)
                Text(_formatData(ts),
                  style: const TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 8, color: Colors.white24, letterSpacing: 0.3)),
            ])),
          ]),
        );
      }).toList(),
    );
  }

  // ── Histórico de penalidades ──────────────────────────────────────────────
  Widget _buildHistoricoPenalidades() {
    final pens = _reportedUser!['penalidades'];
    if (pens == null || pens is! Map) return const SizedBox.shrink();

    final lista = (pens as Map).entries.map((e) {
      final v = Map<String, dynamic>.from(e.value as Map);
      v['_key'] = e.key;
      return v;
    }).toList()
      ..sort((a, b) =>
        (b['aplicada_em'] as int? ?? 0).compareTo(a['aplicada_em'] as int? ?? 0));

    if (lista.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:  Colors.white.withOpacity(0.02),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 0.8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('HISTÓRICO DE PENALIDADES (${lista.length})'),
        const SizedBox(height: 14),
        ...lista.map((p) {
          final tipo   = p['tipo']           as String? ?? '—';
          final artigo = p['artigo_violado'] as String? ?? '—';
          final motivo = p['motivo_admin']   as String? ?? '';
          final proto  = p['protocolo']      as String? ?? '—';
          final em     = p['aplicada_em']    as int?;

          Color tCor = Colors.white38;
          if (tipo == 'banimento')        tCor = const Color(0xFFE85D5D);
          if (tipo == 'suspensao')        tCor = const Color(0xFFFF8C00);
          if (tipo == 'advertencia')      tCor = const Color(0xFFD4AF37);
          if (tipo == 'remover_conteudo') tCor = const Color(0xFFE85D5D);

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:  tCor.withOpacity(0.05),
              border: Border.all(color: tCor.withOpacity(0.2), width: 0.6)),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tipo.toUpperCase().replaceAll('_', ' '),
                  style: TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 10, fontWeight: FontWeight.w700,
                    letterSpacing: 1.5, color: tCor)),
                Text(artigo,
                  style: TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 9, color: tCor.withOpacity(0.6), letterSpacing: 0.5)),
                if (motivo.isNotEmpty)
                  Text(motivo,
                    style: const TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 10, color: Colors.white38, height: 1.4)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(proto,
                  style: const TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 8, color: Colors.white24, letterSpacing: 0.5)),
                if (em != null)
                  Text(_formatData(em),
                    style: const TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 8, color: Colors.white24)),
              ]),
            ]),
          );
        }),
      ]),
    );
  }

  // ── Já resolvido ──────────────────────────────────────────────────────────
  Widget _buildJaResolvido() {
    final status = widget.report['status']      as String? ?? '';
    final proto  = widget.report['protocolo']   as String?;
    final acao   = widget.report['acao_tomada'] as String?;
    final em     = widget.report['resolvido_em'] as int?;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:  Colors.white.withOpacity(0.02),
        border: Border.all(
          color: status == 'actioned'
              ? const Color(0xFF4CAF50).withOpacity(0.3)
              : Colors.white12,
          width: 0.8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(
            status == 'actioned' ? Icons.check_circle_rounded : Icons.cancel_outlined,
            color: status == 'actioned' ? const Color(0xFF4CAF50) : Colors.white24,
            size: 16),
          const SizedBox(width: 8),
          Text(
            status == 'actioned' ? 'DENÚNCIA RESOLVIDA' : 'DENÚNCIA IGNORADA',
            style: const TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 10, fontWeight: FontWeight.w700,
              letterSpacing: 2, color: Colors.white54)),
        ]),
        if (acao != null) ...[
          const SizedBox(height: 8),
          Text('Ação: ${acao.toUpperCase().replaceAll('_', ' ')}',
            style: const TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 11, color: Colors.white54)),
        ],
        if (em != null) ...[
          const SizedBox(height: 4),
          Text('Resolvido em: ${_formatData(em)}',
            style: const TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 10, color: Colors.white38)),
        ],
        if (proto != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: TabuColors.rosaDeep.withOpacity(0.15),
              border: Border.all(color: TabuColors.rosaPrincipal.withOpacity(0.4))),
            child: Row(children: [
              const Icon(Icons.tag_rounded, color: TabuColors.rosaPrincipal, size: 12),
              const SizedBox(width: 6),
              Text(proto,
                style: const TextStyle(
                  fontFamily: TabuTypography.displayFont,
                  fontSize: 13, letterSpacing: 2, color: TabuColors.rosaPrincipal)),
            ])),
        ],
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FORMULÁRIO DE AÇÃO
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildFormAcao() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color:  TabuColors.rosaDeep.withOpacity(0.15),
            border: Border.all(color: TabuColors.rosaPrincipal.withOpacity(0.3), width: 0.8)),
          child: Row(children: [
            const Icon(Icons.gavel_rounded, color: TabuColors.rosaPrincipal, size: 16),
            const SizedBox(width: 10),
            const Text('TOMAR MEDIDA DISCIPLINAR',
              style: TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 10, fontWeight: FontWeight.w700,
                letterSpacing: 2, color: TabuColors.rosaPrincipal)),
          ])),

        const SizedBox(height: 12),

        ...AcaoAdmin.values.map((a) => _acaoTile(a)),

        if (_acaoSelecionada == AcaoAdmin.suspensao) ...[
          const SizedBox(height: 12),
          _buildDatePickers(),
        ],

        const SizedBox(height: 16),
        _buildArtigoVioladoSection(),
        const SizedBox(height: 16),

        // Botão confirmar
        GestureDetector(
          onTap: _acaoSelecionada == null || _processando ? null : _processarAcao,
          child: Container(
            width: double.infinity, height: 52,
            decoration: BoxDecoration(
              color: _acaoSelecionada == null
                  ? Colors.white.withOpacity(0.05)
                  : _acaoSelecionada!.cor.withOpacity(0.9),
              border: Border.all(
                color: _acaoSelecionada == null ? Colors.white12 : _acaoSelecionada!.cor,
                width: 0.8)),
            child: Center(child: _processando
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    if (_acaoSelecionada != null)
                      Icon(_acaoSelecionada!.icon, color: Colors.white, size: 15),
                    const SizedBox(width: 10),
                    Text(
                      _acaoSelecionada == null
                          ? 'SELECIONE UMA AÇÃO'
                          : 'CONFIRMAR · ${_acaoSelecionada!.label}',
                      style: TextStyle(
                        fontFamily: TabuTypography.bodyFont,
                        fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2,
                        color: _acaoSelecionada == null ? Colors.white24 : Colors.white)),
                  ])),
          ),
        ),
        const SizedBox(height: 8),
        Text('Emails serão enviados automaticamente ao denunciante e ao denunciado.',
          style: TextStyle(
            fontFamily: TabuTypography.bodyFont,
            fontSize: 9, color: Colors.white.withOpacity(0.2), letterSpacing: 0.3)),
      ]),
    );
  }

  // ── Artigo violado ────────────────────────────────────────────────────────
  Widget _buildArtigoVioladoSection() {
    return Container(
      decoration: BoxDecoration(
        color:  Colors.white.withOpacity(0.025),
        border: Border.all(
          color: _artigoSelecionado != null || (_editandoArtigo && _artigoCustomCtrl.text.isNotEmpty)
              ? TabuColors.rosaPrincipal.withOpacity(0.35)
              : Colors.white.withOpacity(0.08),
          width: 0.8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Row(children: [
            Container(width: 2, height: 12, color: TabuColors.rosaPrincipal),
            const SizedBox(width: 8),
            const Text('ARTIGO VIOLADO *',
              style: TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 8, fontWeight: FontWeight.w700,
                letterSpacing: 2.5, color: Colors.white38)),
            const Spacer(),
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _editandoArtigo = !_editandoArtigo;
                  if (_editandoArtigo) {
                    if (_artigoSelecionado != null) {
                      _artigoCustomCtrl.text = _artigoSelecionado!.codigo;
                    }
                  } else {
                    _artigoCustomCtrl.clear();
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _editandoArtigo
                      ? TabuColors.rosaDeep.withOpacity(0.3)
                      : Colors.white.withOpacity(0.05),
                  border: Border.all(
                    color: _editandoArtigo
                        ? TabuColors.rosaPrincipal.withOpacity(0.5)
                        : Colors.white12,
                    width: 0.6)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    _editandoArtigo ? Icons.list_rounded : Icons.edit_rounded,
                    color: _editandoArtigo ? TabuColors.rosaPrincipal : Colors.white38,
                    size: 10),
                  const SizedBox(width: 5),
                  Text(
                    _editandoArtigo ? 'USAR LISTA' : 'INSERIR MANUALMENTE',
                    style: TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 7, fontWeight: FontWeight.w700, letterSpacing: 1.5,
                      color: _editandoArtigo ? TabuColors.rosaPrincipal : Colors.white38)),
                ]),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        if (!_editandoArtigo) ...[
          _buildArtigoDropdown(),
          if (_artigoSelecionado != null) ...[
            const SizedBox(height: 10),
            _buildDescricaoAutoSection(),
          ],
        ],
        if (_editandoArtigo) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: _campoSemLabel(
              controller: _artigoCustomCtrl,
              hint:       'Ex: Art. 10º, II – Termos de Uso',
              maxLines:   1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: _buildDescricaoManualSection(mostrarSugerido: false),
          ),
        ],
      ]),
    );
  }

  Widget _buildArtigoDropdown() {
    final grupos = <String, List<ArtigoTabu>>{};
    for (final a in kArtigosTabu) {
      grupos.putIfAbsent(a.fonte, () => []).add(a);
    }
    return Theme(
      data: Theme.of(context).copyWith(canvasColor: const Color(0xFF0D0020)),
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 0),
        decoration: BoxDecoration(
          color:  Colors.white.withOpacity(0.04),
          border: Border.all(
            color: _artigoSelecionado != null
                ? TabuColors.rosaPrincipal.withOpacity(0.4)
                : Colors.white12,
            width: 0.8)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<ArtigoTabu>(
            value:      _artigoSelecionado,
            isExpanded: true,
            dropdownColor: const Color(0xFF0D0020),
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white38, size: 18),
            hint: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('Selecionar artigo violado...',
                style: TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 12, color: Colors.white24))),
            selectedItemBuilder: (_) => kArtigosTabu.map((a) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(a.codigo,
                      style: const TextStyle(
                        fontFamily: TabuTypography.bodyFont,
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: TabuColors.rosaPrincipal, letterSpacing: 0.5)),
                    Text(a.titulo,
                      style: const TextStyle(
                        fontFamily: TabuTypography.bodyFont,
                        fontSize: 9, color: Colors.white54)),
                  ]),
              ),
            )).toList(),
            items: _buildDropdownItems(grupos),
            onChanged: (artigo) {
              HapticFeedback.selectionClick();
              setState(() {
                _artigoSelecionado = artigo;
                _descricaoEditada  = false;
                if (artigo != null) _motivoCtrl.text = artigo.descricaoBase;
              });
            },
          ),
        ),
      ),
    );
  }

  List<DropdownMenuItem<ArtigoTabu>> _buildDropdownItems(Map<String, List<ArtigoTabu>> grupos) {
    final items = <DropdownMenuItem<ArtigoTabu>>[];
    grupos.forEach((fonte, artigos) {
      items.add(DropdownMenuItem<ArtigoTabu>(
        enabled: false, value: null,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Row(children: [
            Container(width: 2, height: 10,
              color: fonte == 'Termos de Uso'
                  ? TabuColors.rosaPrincipal
                  : const Color(0xFF4FC3F7)),
            const SizedBox(width: 8),
            Text(fonte.toUpperCase(),
              style: TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 7, fontWeight: FontWeight.w700, letterSpacing: 2.5,
                color: fonte == 'Termos de Uso'
                    ? TabuColors.rosaPrincipal.withOpacity(0.7)
                    : const Color(0xFF4FC3F7).withOpacity(0.7))),
          ]),
        ),
      ));
      for (final artigo in artigos) {
        items.add(DropdownMenuItem<ArtigoTabu>(
          value: artigo,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(artigo.codigo,
                  style: const TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: Colors.white, letterSpacing: 0.3)),
                Text(artigo.titulo,
                  style: const TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 9, color: Colors.white54)),
              ]),
          ),
        ));
      }
    });
    return items;
  }

  Widget _buildDescricaoAutoSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            color: _artigoSelecionado!.fonte == 'Termos de Uso'
                ? TabuColors.rosaDeep.withOpacity(0.4)
                : const Color(0xFF4FC3F7).withOpacity(0.15),
            child: Text(_artigoSelecionado!.fonte.toUpperCase(),
              style: TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 7, fontWeight: FontWeight.w700, letterSpacing: 1.5,
                color: _artigoSelecionado!.fonte == 'Termos de Uso'
                    ? TabuColors.rosaPrincipal
                    : const Color(0xFF4FC3F7)))),
          const SizedBox(width: 8),
          const Text('JUSTIFICATIVA / DESCRIÇÃO DA INFRAÇÃO',
            style: TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 7, fontWeight: FontWeight.w700,
              letterSpacing: 2, color: Colors.white24)),
          const Spacer(),
          if (_descricaoEditada)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              color: const Color(0xFFD4AF37).withOpacity(0.2),
              child: const Text('EDITADO',
                style: TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 7, fontWeight: FontWeight.w700,
                  letterSpacing: 1.5, color: Color(0xFFD4AF37)))),
        ]),
        const SizedBox(height: 8),
        _buildDescricaoManualSection(mostrarSugerido: true),
      ]),
    );
  }

  Widget _buildDescricaoManualSection({required bool mostrarSugerido}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (!mostrarSugerido) ...[
        const Text('JUSTIFICATIVA / DESCRIÇÃO DA INFRAÇÃO *',
          style: TextStyle(
            fontFamily: TabuTypography.bodyFont,
            fontSize: 8, fontWeight: FontWeight.w700,
            letterSpacing: 2, color: Colors.white38)),
        const SizedBox(height: 6),
      ],
      Container(
        decoration: BoxDecoration(
          color:  Colors.white.withOpacity(0.04),
          border: Border.all(
            color: _descricaoEditada
                ? const Color(0xFFD4AF37).withOpacity(0.4)
                : Colors.white12,
            width: 0.8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            controller: _motivoCtrl,
            maxLines:   5,
            style: const TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 12, color: Colors.white, height: 1.6),
            cursorColor: TabuColors.rosaPrincipal,
            onChanged: (_) {
              if (!_descricaoEditada && _artigoSelecionado != null) {
                setState(() => _descricaoEditada =
                    _motivoCtrl.text != _artigoSelecionado!.descricaoBase);
              }
            },
            decoration: const InputDecoration(
              hintText: 'Descreva o motivo da infração e a medida tomada...',
              hintStyle: TextStyle(
                fontFamily: TabuTypography.bodyFont, fontSize: 11, color: Colors.white24),
              contentPadding: EdgeInsets.all(12),
              border: InputBorder.none,
            ),
          ),
          if (_descricaoEditada && _artigoSelecionado != null)
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _motivoCtrl.text  = _artigoSelecionado!.descricaoBase;
                  _descricaoEditada = false;
                });
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFD4AF37), width: 0.4))),
                child: Row(children: const [
                  Icon(Icons.refresh_rounded, color: Color(0xFFD4AF37), size: 11),
                  SizedBox(width: 6),
                  Text('RESTAURAR TEXTO SUGERIDO',
                    style: TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 8, fontWeight: FontWeight.w700,
                      letterSpacing: 1.5, color: Color(0xFFD4AF37))),
                ]),
              ),
            ),
        ]),
      ),
    ]);
  }

  Widget _acaoTile(AcaoAdmin a) {
    final sel = _acaoSelecionada == a;
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); setState(() => _acaoSelecionada = a); },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: sel ? a.cor.withOpacity(0.12) : Colors.white.withOpacity(0.03),
          border: Border.all(
            color: sel ? a.cor.withOpacity(0.7) : Colors.white.withOpacity(0.07),
            width: sel ? 1 : 0.6)),
        child: Row(children: [
          Icon(a.icon, color: sel ? a.cor : Colors.white38, size: 16),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.label,
              style: TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5,
                color: sel ? a.cor : Colors.white54)),
            const SizedBox(height: 2),
            Text(a.descricao,
              style: const TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 9, color: Colors.white24, height: 1.4)),
          ])),
          if (sel) Icon(Icons.check_circle_rounded, color: a.cor, size: 16),
        ]),
      ),
    );
  }

  Widget _buildDatePickers() {
    return Row(children: [
      Expanded(child: _datePicker(
        label: 'INÍCIO', value: _suspensaoInicio,
        onTap: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 365)),
            builder: (_, child) => Theme(
              data: ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: TabuColors.rosaPrincipal,
                  onPrimary: Colors.white,
                  surface: Color(0xFF0D0020))),
              child: child!));
          if (d != null) setState(() => _suspensaoInicio = d);
        },
      )),
      const SizedBox(width: 8),
      Expanded(child: _datePicker(
        label: 'FIM', value: _suspensaoFim,
        onTap: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: (_suspensaoInicio ?? DateTime.now()).add(const Duration(days: 1)),
            firstDate:   (_suspensaoInicio ?? DateTime.now()).add(const Duration(days: 1)),
            lastDate: DateTime.now().add(const Duration(days: 365)),
            builder: (_, child) => Theme(
              data: ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: TabuColors.rosaPrincipal,
                  onPrimary: Colors.white,
                  surface: Color(0xFF0D0020))),
              child: child!));
          if (d != null) setState(() => _suspensaoFim = d);
        },
      )),
    ]);
  }

  Widget _datePicker({
    required String    label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    final fmt = DateFormat('dd/MM/yyyy');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:  Colors.white.withOpacity(0.04),
          border: Border.all(
            color: value != null ? const Color(0xFFFF8C00).withOpacity(0.5) : Colors.white12,
            width: 0.8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
            style: const TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 8, fontWeight: FontWeight.w700,
              letterSpacing: 2, color: Colors.white24)),
          const SizedBox(height: 6),
          Text(value != null ? fmt.format(value) : 'Selecionar',
            style: TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 12,
              color: value != null ? Colors.white : Colors.white38)),
        ]),
      ),
    );
  }

  Widget _campoSemLabel({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color:  Colors.white.withOpacity(0.04),
        border: Border.all(color: Colors.white12, width: 0.8)),
      child: TextField(
        controller: controller,
        maxLines:   maxLines,
        style: const TextStyle(
          fontFamily: TabuTypography.bodyFont,
          fontSize: 12, color: Colors.white, height: 1.5),
        cursorColor: TabuColors.rosaPrincipal,
        decoration: InputDecoration(
          hintText:       hint,
          hintStyle:      const TextStyle(
            fontFamily: TabuTypography.bodyFont,
            fontSize: 11, color: Colors.white24),
          contentPadding: const EdgeInsets.all(12),
          border:         InputBorder.none,
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _loadingCard() => Container(
    margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
    height: 80,
    decoration: BoxDecoration(
      color:  Colors.white.withOpacity(0.02),
      border: Border.all(color: Colors.white.withOpacity(0.06), width: 0.8)),
    child: const Center(
      child: SizedBox(width: 20, height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          valueColor: AlwaysStoppedAnimation(TabuColors.rosaPrincipal)))));

  Widget _sectionLabel(String text) => Row(children: [
    Container(width: 2, height: 12, color: TabuColors.rosaPrincipal),
    const SizedBox(width: 8),
    Text(text, style: const TextStyle(
      fontFamily: TabuTypography.bodyFont,
      fontSize: 8, fontWeight: FontWeight.w700,
      letterSpacing: 2.5, color: Colors.white38)),
  ]);

  Widget _infoRow(String label, String value, Color color) => Row(children: [
    SizedBox(width: 90, child: Text(label,
      style: const TextStyle(
        fontFamily: TabuTypography.bodyFont,
        fontSize: 8, fontWeight: FontWeight.w700,
        letterSpacing: 1.5, color: Colors.white24))),
    Expanded(child: Text(value,
      style: TextStyle(
        fontFamily: TabuTypography.bodyFont,
        fontSize: 11, color: color, letterSpacing: 0.3))),
  ]);

  Widget _statusBadge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(border: Border.all(color: color.withOpacity(0.5), width: 0.7)),
    child: Text(label,
      style: TextStyle(
        fontFamily: TabuTypography.bodyFont,
        fontSize: 8, fontWeight: FontWeight.w700,
        letterSpacing: 1.5, color: color)));

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':   return const Color(0xFFD4AF37);
      case 'actioned':  return const Color(0xFF4CAF50);
      case 'dismissed': return Colors.white24;
      default:          return Colors.white24;
    }
  }

  String _formatData(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateFormat('dd/MM/yyyy · HH:mm').format(dt);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SUCESSO SHEET — FIX: scrollável + SafeArea correta
// ══════════════════════════════════════════════════════════════════════════════
class _SucessoSheet extends StatelessWidget {
  final String       protocolo;
  final AcaoAdmin    acao;
  final VoidCallback onOk;

  const _SucessoSheet({
    required this.protocolo,
    required this.acao,
    required this.onOk,
  });

  @override
  Widget build(BuildContext context) {
    // FIX: usa viewInsets para garantir que o sheet não fique atrás da navbar
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom
        + MediaQuery.of(context).padding.bottom;

    return SingleChildScrollView(
      // FIX: permite scroll caso o conteúdo seja maior que a tela
      physics: const ClampingScrollPhysics(),
      child: Padding(
        // FIX: padding lateral + bottom dinâmico (home indicator / navbar)
        padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomPadding),
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          // Handle
          Container(
            width: 36, height: 3,
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),

          Container(
            width: 60, height: 60,
            color: acao.cor.withOpacity(0.12),
            child: Icon(acao.icon, color: acao.cor, size: 26)),

          const SizedBox(height: 16),

          const Text('MEDIDA APLICADA',
            style: TextStyle(
              fontFamily: TabuTypography.displayFont,
              fontSize: 16, letterSpacing: 4, color: Colors.white)),

          const SizedBox(height: 6),

          Text(acao.label,
            style: TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 12, letterSpacing: 2, color: acao.cor)),

          const SizedBox(height: 20),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:  TabuColors.rosaDeep.withOpacity(0.12),
              border: Border.all(color: TabuColors.rosaPrincipal.withOpacity(0.4))),
            child: Column(children: [
              const Text('PROTOCOLO DA DENÚNCIA',
                style: TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 8, fontWeight: FontWeight.w700,
                  letterSpacing: 3, color: Colors.white38)),
              const SizedBox(height: 8),
              Text(protocolo,
                style: const TextStyle(
                  fontFamily: TabuTypography.displayFont,
                  fontSize: 20, letterSpacing: 3,
                  color: TabuColors.rosaPrincipal)),
            ])),

          const SizedBox(height: 12),

          Text(
            'Emails enviados automaticamente para o denunciante e denunciado.\n'
            'Guarde o protocolo para referências futuras.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 10, height: 1.6,
              color: Colors.white.withOpacity(0.3))),

          const SizedBox(height: 24),

          // FIX: botão CONCLUIR sempre visível — não fica atrás da navbar
          GestureDetector(
            onTap: onOk,
            child: Container(
              width: double.infinity, height: 52,
              color: TabuColors.rosaPrincipal,
              child: const Center(
                child: Text('CONCLUIR',
                  style: TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 11, fontWeight: FontWeight.w700,
                    letterSpacing: 3, color: Colors.white))))),
        ]),
      ),
    );
  }
}