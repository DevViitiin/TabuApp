// lib/screens/screens_administrative/reports_screens/report_chat_screen/report_chat_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/services/services_administrative/reports/report_chat_service.dart';

// ── Abre a tela de denúncia de conversa ──────────────────────────────────────
Future<void> showReportChatScreen(
  BuildContext context, {
  required String chatId,
  required String reportedUid,
  required String reportedName,
  required String reporterUid,
}) async {
  await Navigator.push(
    context,
    PageRouteBuilder(
      pageBuilder: (_, animation, __) => ReportChatScreen(
        chatId:       chatId,
        reportedUid:  reportedUid,
        reportedName: reportedName,
        reporterUid:  reporterUid,
      ),
      transitionsBuilder: (_, animation, __, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end:   Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve:  Curves.easeOutCubic,
        )),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 320),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  TELA PRINCIPAL
// ══════════════════════════════════════════════════════════════════════════════
class ReportChatScreen extends StatefulWidget {
  final String chatId;
  final String reportedUid;
  final String reportedName;
  final String reporterUid;

  const ReportChatScreen({
    super.key,
    required this.chatId,
    required this.reportedUid,
    required this.reportedName,
    required this.reporterUid,
  });

  @override
  State<ReportChatScreen> createState() => _ReportChatScreenState();
}

class _ReportChatScreenState extends State<ReportChatScreen>
    with SingleTickerProviderStateMixin {

  ReportChatMotivo? _motivo;
  final _descCtrl  = TextEditingController();
  final _descFocus = FocusNode();

  bool _enviando       = false;
  bool _enviado        = false;
  bool _jaReportou     = false;
  bool _checando       = true;

  // Confirma que o usuário leu os avisos antes de enviar
  bool _confirmaVerdade   = false;
  bool _confirmaConsequencias = false;

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  static const _minChars = 30;

  bool get _descValida   => _descCtrl.text.trim().length >= _minChars;
  bool get _podeEnviar   =>
      _motivo != null &&
      _descValida &&
      _confirmaVerdade &&
      _confirmaConsequencias &&
      !_enviando;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));

    _animCtrl.forward();
    _descCtrl.addListener(() => setState(() {}));
    _descFocus.addListener(() => setState(() {}));
    _verificarJaReportou();
  }

  Future<void> _verificarJaReportou() async {
    final ja = await ReportChatService.instance.jaReportou(widget.chatId);
    if (mounted) setState(() { _jaReportou = ja; _checando = false; });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _descCtrl.dispose();
    _descFocus.dispose();
    super.dispose();
  }

  // ── Enviar ─────────────────────────────────────────────────────────────────
  Future<void> _enviar() async {
    if (!_podeEnviar) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    setState(() => _enviando = true);

    try {
      await ReportChatService.instance.reportChat(
        chatId:       widget.chatId,
        reportedUid:  widget.reportedUid,
        reportedName: widget.reportedName,
        motivo:       _motivo!,
        descricao:    _descCtrl.text,
      );
      if (mounted) setState(() { _enviando = false; _enviado = true; });
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _enviando = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: const Color(0xFF3D0A0A),
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(),
          margin: const EdgeInsets.all(16),
          content: Text('ERRO: $e',
              style: const TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 11, fontWeight: FontWeight.w700,
                  letterSpacing: 1.5, color: TabuColors.branco)),
        ));
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: TabuColors.bgAlt,
        body: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: _checando
                ? _buildLoading()
                : _enviado
                    ? _buildSucesso()
                    : _jaReportou
                        ? _buildJaReportou()
                        : _buildFormulario(),
          ),
        ),
      ),
    );
  }

  // ── Loading ────────────────────────────────────────────────────────────────
  Widget _buildLoading() => const Center(
    child: SizedBox(width: 18, height: 18,
      child: CircularProgressIndicator(
          color: TabuColors.rosaPrincipal, strokeWidth: 1.5)));

  // ── Já denunciou ───────────────────────────────────────────────────────────
  Widget _buildJaReportou() {
    return SafeArea(child: Column(children: [
      _buildAppBar(),
      Expanded(child: Center(child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _IconBox(
            icon: Icons.chat_bubble_outline_rounded,
            color: TabuColors.rosaPrincipal),
          const SizedBox(height: 20),
          const Text('CONVERSA JÁ DENUNCIADA', style: TextStyle(
              fontFamily: TabuTypography.displayFont,
              fontSize: 18, letterSpacing: 3,
              color: TabuColors.branco)),
          const SizedBox(height: 12),
          Text(
            'Você já enviou uma denúncia sobre\nesta conversa com ${widget.reportedName.toUpperCase()}.\n\nNossa equipe irá analisar em breve.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 12, letterSpacing: 0.3,
                color: TabuColors.subtle, height: 1.7)),
          const SizedBox(height: 8),
          const Text(
            'Art. 18º e 19º – Código de Conduta Tabu',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 9, letterSpacing: 1,
                color: TabuColors.border)),
          const SizedBox(height: 32),
          _BotaoSecundario(label: 'VOLTAR', onTap: () => Navigator.pop(context)),
        ]),
      ))),
    ]));
  }

  // ── Sucesso ────────────────────────────────────────────────────────────────
  Widget _buildSucesso() {
    return SafeArea(child: Column(children: [
      _buildAppBar(),
      Expanded(child: Center(child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _IconBox(
            icon: Icons.check_rounded,
            color: TabuColors.rosaPrincipal,
            filled: true),
          const SizedBox(height: 20),
          const Text('DENÚNCIA ENVIADA', style: TextStyle(
              fontFamily: TabuTypography.displayFont,
              fontSize: 20, letterSpacing: 4,
              color: TabuColors.branco)),
          const SizedBox(height: 12),
          const Text(
            'Recebemos sua denúncia sobre esta conversa.\n\nNossa equipe irá analisar o conteúdo '
            'e tomar as medidas cabíveis conforme nossos Termos de Uso e Política de Privacidade.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 12, letterSpacing: 0.3,
                color: TabuColors.subtle, height: 1.7)),
          const SizedBox(height: 12),
          _LegalBox(items: const [
            'Suas mensagens não serão expostas publicamente.',
            'A análise é feita de forma sigilosa pela equipe Tabu.',
            'O denunciado não é notificado sobre sua identidade.',
          ]),
          const SizedBox(height: 8),
          const Text(
            'Art. 18º, 19º e 20º – Código de Conduta Tabu\nLGPD – Lei 13.709/2018',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 9, letterSpacing: 0.8,
                color: TabuColors.border)),
        ]),
      ))),
    ]));
  }

  // ── Formulário ─────────────────────────────────────────────────────────────
  Widget _buildFormulario() {
    return SafeArea(child: Column(children: [
      _buildAppBar(),
      _buildLinhaRosa(),
      Expanded(child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [

          _buildHeader(),
          const SizedBox(height: 20),
          _buildDivider(),
          const SizedBox(height: 20),

          // ── Aviso de privacidade ─────────────────────────────────────────
          _buildAvisoPrivacidade(),
          const SizedBox(height: 20),
          _buildDivider(),
          const SizedBox(height: 20),

          // ── Passo 1: Motivo ──────────────────────────────────────────────
          _StepLabel(step: '01', label: 'O QUE ACONTECEU?'),
          const SizedBox(height: 6),
          const Text(
            'Selecione a categoria que melhor descreve o problema nesta conversa',
            style: TextStyle(fontFamily: TabuTypography.bodyFont,
                fontSize: 10, letterSpacing: 0.5,
                color: TabuColors.subtle)),
          const SizedBox(height: 14),

          ...ReportChatMotivo.values.map((m) => _MotivoTile(
            motivo:      m,
            selecionado: _motivo == m,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _motivo = m);
            },
          )),

          const SizedBox(height: 20),
          _buildDivider(),
          const SizedBox(height: 20),

          // ── Passo 2: Descrição ───────────────────────────────────────────
          _StepLabel(step: '02', label: 'DESCREVA O QUE ACONTECEU'),
          const SizedBox(height: 6),
          Row(children: [
            const Text('Mínimo de 30 caracteres',
                style: TextStyle(fontFamily: TabuTypography.bodyFont,
                    fontSize: 10, letterSpacing: 0.5,
                    color: TabuColors.subtle)),
            const Spacer(),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 10, letterSpacing: 0.5,
                color: _descValida
                    ? TabuColors.rosaPrincipal
                    : _descCtrl.text.isEmpty
                        ? TabuColors.border
                        : const Color(0xFFE85D5D)),
              child: Text('${_descCtrl.text.trim().length}/$_minChars'),
            ),
          ]),
          const SizedBox(height: 10),
          _buildCampoDescricao(),
          if (!_descValida && _descCtrl.text.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                const Icon(Icons.info_outline,
                    color: Color(0xFFE85D5D), size: 11),
                const SizedBox(width: 5),
                Text(
                  'Faltam ${_minChars - _descCtrl.text.trim().length} caracteres',
                  style: const TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 10, letterSpacing: 0.8,
                      color: Color(0xFFE85D5D))),
              ])),

          const SizedBox(height: 20),
          _buildDivider(),
          const SizedBox(height: 20),

          // ── Passo 3: Base legal ──────────────────────────────────────────
          _StepLabel(step: '03', label: 'BASE LEGAL'),
          const SizedBox(height: 10),
          _buildBaseLegal(),

          const SizedBox(height: 20),
          _buildDivider(),
          const SizedBox(height: 20),

          // ── Passo 4: Confirmações ────────────────────────────────────────
          _StepLabel(step: '04', label: 'CONFIRMAÇÕES OBRIGATÓRIAS'),
          const SizedBox(height: 6),
          const Text(
            'Leia e confirme os itens abaixo antes de enviar',
            style: TextStyle(fontFamily: TabuTypography.bodyFont,
                fontSize: 10, letterSpacing: 0.5,
                color: TabuColors.subtle)),
          const SizedBox(height: 14),

          _CheckConfirm(
            valor: _confirmaVerdade,
            onChanged: (v) => setState(() => _confirmaVerdade = v),
            texto: 'Confirmo que as informações fornecidas são verídicas e que '
                'esta denúncia é feita de boa-fé, conforme Art. 19º do Código de Conduta Tabu.',
          ),
          const SizedBox(height: 10),
          _CheckConfirm(
            valor: _confirmaConsequencias,
            onChanged: (v) => setState(() => _confirmaConsequencias = v),
            texto: 'Estou ciente de que denúncias falsas ou de má-fé podem '
                'resultar em penalidades contra minha conta, incluindo suspensão.',
          ),

          const SizedBox(height: 20),
          _buildDivider(),
          const SizedBox(height: 20),

          // ── O que acontece depois ────────────────────────────────────────
          _buildOQueAcontece(),
          const SizedBox(height: 28),

          // ── Botões ───────────────────────────────────────────────────────
          _buildBotaoEnviar(),
          const SizedBox(height: 8),
          _BotaoSecundario(
            label: 'CANCELAR',
            onTap: () => Navigator.pop(context)),
        ],
      )),
    ]));
  }

  // ── Sub-widgets ────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 16, 0),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: TabuColors.dim, size: 16),
          onPressed: () => Navigator.pop(context)),
        const Spacer(),
        const Text('DENÚNCIA DE CONVERSA',
            style: TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 9, fontWeight: FontWeight.w700,
              letterSpacing: 3, color: TabuColors.subtle)),
        const SizedBox(width: 6),
      ]),
    );
  }

  Widget _buildLinhaRosa() => Container(
    height: 1.5,
    margin: const EdgeInsets.only(top: 6),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [
      Colors.transparent, TabuColors.rosaDeep,
      TabuColors.rosaPrincipal, TabuColors.rosaClaro,
      TabuColors.rosaPrincipal, TabuColors.rosaDeep, Colors.transparent,
    ])));

  Widget _buildDivider() => Container(
    height: 0.5,
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [
      Colors.transparent, TabuColors.border, Colors.transparent,
    ])));

  Widget _buildHeader() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF3D0A0A),
            border: Border.all(
                color: const Color(0xFFE85D5D).withOpacity(0.5), width: 0.8)),
          child: const Icon(Icons.report_gmailerrorred_rounded,
              color: Color(0xFFE85D5D), size: 16)),
        const SizedBox(width: 12),
        const Expanded(child: Text('DENUNCIAR CONVERSA', style: TextStyle(
            fontFamily: TabuTypography.displayFont,
            fontSize: 17, letterSpacing: 4,
            color: TabuColors.branco))),
      ]),
      const SizedBox(height: 14),

      // Card da conversa
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: TabuColors.bgCard,
          border: Border.all(color: TabuColors.border, width: 0.6)),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: TabuColors.bg,
              border: Border.all(
                  color: TabuColors.border.withOpacity(0.8), width: 0.7)),
            child: const Icon(Icons.chat_bubble_outline_rounded,
                color: TabuColors.subtle, size: 15)),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Text('CONVERSA COM  ',
                    style: TextStyle(
                        fontFamily: TabuTypography.bodyFont,
                        fontSize: 9, letterSpacing: 1.5,
                        color: TabuColors.subtle)),
                Text(widget.reportedName.toUpperCase(),
                    style: const TextStyle(
                        fontFamily: TabuTypography.bodyFont,
                        fontSize: 12, fontWeight: FontWeight.w700,
                        letterSpacing: 1.5, color: TabuColors.branco)),
              ]),
              const SizedBox(height: 4),
              const Text(
                'O conteúdo desta conversa será usado como base para a análise.',
                style: TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 9, letterSpacing: 0.3,
                    color: TabuColors.subtle, height: 1.4)),
            ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF3D0A0A),
              border: Border.all(
                  color: const Color(0xFFE85D5D).withOpacity(0.4), width: 0.6)),
            child: const Text('CHAT',
                style: TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 7, fontWeight: FontWeight.w700,
                    letterSpacing: 2, color: Color(0xFFE85D5D)))),
        ])),

      const SizedBox(height: 10),
      const Text(
        'Denúncias são tratadas de forma confidencial, conforme nossa Política de Privacidade e LGPD (Lei 13.709/2018).',
        style: TextStyle(fontFamily: TabuTypography.bodyFont,
            fontSize: 9, letterSpacing: 0.3,
            color: TabuColors.subtle, height: 1.5)),
    ]);
  }

  Widget _buildAvisoPrivacidade() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TabuColors.rosaPrincipal.withOpacity(0.04),
        border: Border.all(
            color: TabuColors.rosaPrincipal.withOpacity(0.2), width: 0.7)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.shield_outlined,
              color: TabuColors.rosaPrincipal, size: 13),
          const SizedBox(width: 8),
          const Text('SUA PRIVACIDADE É PROTEGIDA', style: TextStyle(
              fontFamily: TabuTypography.bodyFont, fontSize: 9,
              fontWeight: FontWeight.w700, letterSpacing: 2,
              color: TabuColors.rosaPrincipal)),
        ]),
        const SizedBox(height: 10),
        _PrivacyItem(
          icon: Icons.lock_outline_rounded,
          texto: 'Sua identidade não será revelada ao denunciado em nenhum momento.'),
        const SizedBox(height: 8),
        _PrivacyItem(
          icon: Icons.visibility_off_outlined,
          texto: 'O conteúdo desta conversa será acessado somente pela equipe de moderação Tabu.'),
        const SizedBox(height: 8),
        _PrivacyItem(
          icon: Icons.policy_outlined,
          texto: 'Os dados fornecidos serão tratados conforme a LGPD (Lei 13.709/2018) e nossa Política de Privacidade.'),
      ]),
    );
  }

  Widget _buildBaseLegal() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TabuColors.bgCard,
        border: Border.all(color: TabuColors.border, width: 0.6)),
      child: _motivo != null
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.gavel_outlined,
                    color: TabuColors.subtle, size: 12),
                const SizedBox(width: 8),
                Expanded(child: Text(_motivo!.label,
                    style: const TextStyle(
                        fontFamily: TabuTypography.bodyFont,
                        fontSize: 11, fontWeight: FontWeight.w700,
                        letterSpacing: 0.3, color: TabuColors.branco))),
              ]),
              const SizedBox(height: 8),
              Text(_motivo!.descricao,
                  style: const TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 10, letterSpacing: 0.3,
                      color: TabuColors.dim, height: 1.55)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: TabuColors.rosaPrincipal.withOpacity(0.07),
                  border: Border.all(
                      color: TabuColors.rosaPrincipal.withOpacity(0.25),
                      width: 0.6)),
                child: Text(_motivo!.artigo,
                    style: const TextStyle(
                        fontFamily: TabuTypography.bodyFont,
                        fontSize: 9, letterSpacing: 1,
                        color: TabuColors.rosaPrincipal))),
            ])
          : Row(children: [
              const Icon(Icons.gavel_outlined,
                  color: TabuColors.border, size: 12),
              const SizedBox(width: 8),
              const Expanded(child: Text(
                  'Selecione um motivo para ver a base legal aplicável.',
                  style: TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 10, letterSpacing: 0.3,
                      color: TabuColors.subtle, height: 1.5))),
            ]),
    );
  }

  Widget _buildCampoDescricao() {
    return Container(
      decoration: BoxDecoration(
        color: TabuColors.bgCard,
        border: Border.all(
          color: _descFocus.hasFocus
              ? (_descValida
                  ? TabuColors.rosaPrincipal
                  : const Color(0xFFE85D5D))
              : TabuColors.border,
          width: _descFocus.hasFocus ? 1.5 : 0.8)),
      child: Column(children: [
        TextField(
          controller: _descCtrl,
          focusNode:  _descFocus,
          maxLines:   6,
          maxLength:  600,
          style: const TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 13, color: TabuColors.branco, height: 1.5),
          cursorColor: TabuColors.rosaPrincipal,
          decoration: const InputDecoration(
            border: InputBorder.none, isDense: true,
            hintText: 'Descreva o que aconteceu nesta conversa. Quanto mais detalhes, mais fácil para nossa equipe analisar...',
            hintStyle: TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 12, color: TabuColors.subtle, height: 1.5),
            contentPadding: EdgeInsets.all(14),
            counterText: ''),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 2,
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: (_descCtrl.text.trim().length / _minChars).clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: _descValida
                    ? [TabuColors.rosaDeep, TabuColors.rosaPrincipal]
                    : [const Color(0xFF5D0A0A), const Color(0xFFE85D5D)])),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildOQueAcontece() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TabuColors.bgCard,
        border: Border.all(color: TabuColors.border, width: 0.6)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.info_outline_rounded,
              color: TabuColors.subtle, size: 12),
          const SizedBox(width: 8),
          const Text('O QUE ACONTECE APÓS O ENVIO', style: TextStyle(
              fontFamily: TabuTypography.bodyFont, fontSize: 8,
              fontWeight: FontWeight.w700, letterSpacing: 2,
              color: TabuColors.subtle)),
        ]),
        const SizedBox(height: 12),
        _ProcessoItem(numero: '1', texto:
            'Nossa equipe recebe a denúncia e inicia a análise em até 72h.'),
        const SizedBox(height: 8),
        _ProcessoItem(numero: '2', texto:
            'O histórico da conversa é revisado de forma sigilosa.'),
        const SizedBox(height: 8),
        _ProcessoItem(numero: '3', texto:
            'Se confirmada a violação, medidas são aplicadas: aviso, suspensão temporária ou banimento.'),
        const SizedBox(height: 8),
        _ProcessoItem(numero: '4', texto:
            'Você pode ser notificado sobre o resultado, conforme nossa Política de Privacidade.'),
      ]),
    );
  }

  Widget _buildBotaoEnviar() {
    return GestureDetector(
      onTap: _podeEnviar ? _enviar : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        decoration: BoxDecoration(
          color: _podeEnviar ? const Color(0xFFE85D5D) : TabuColors.bgCard,
          border: Border.all(
            color: _podeEnviar
                ? const Color(0xFFE85D5D)
                : TabuColors.border,
            width: 0.8),
          boxShadow: _podeEnviar ? [BoxShadow(
              color: const Color(0xFFE85D5D).withOpacity(0.3),
              blurRadius: 16, offset: const Offset(0, 4))] : null),
        child: Center(child: _enviando
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 1.5))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.report_gmailerrorred_rounded,
                    color: _podeEnviar ? Colors.white : TabuColors.subtle,
                    size: 16),
                const SizedBox(width: 10),
                Text('ENVIAR DENÚNCIA',
                    style: TextStyle(
                        fontFamily: TabuTypography.bodyFont,
                        fontSize: 12, fontWeight: FontWeight.w700,
                        letterSpacing: 3,
                        color: _podeEnviar ? Colors.white : TabuColors.subtle)),
              ])),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  WIDGETS AUXILIARES
// ══════════════════════════════════════════════════════════════════════════════

class _IconBox extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final bool     filled;
  const _IconBox({required this.icon, required this.color, this.filled = false});

  @override
  Widget build(BuildContext context) => Container(
    width: 60, height: 60,
    decoration: BoxDecoration(
      color: filled
          ? color.withOpacity(0.15)
          : color.withOpacity(0.10),
      border: Border.all(
          color: filled ? color : color.withOpacity(0.4),
          width: filled ? 1.0 : 0.8)),
    child: Icon(icon, color: color, size: 26));
}

class _BotaoSecundario extends StatelessWidget {
  final String       label;
  final VoidCallback onTap;
  const _BotaoSecundario({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity, height: 48,
      decoration: BoxDecoration(
        color: TabuColors.bgCard,
        border: Border.all(color: TabuColors.border, width: 0.8)),
      child: Center(child: Text(label,
          style: const TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 11, fontWeight: FontWeight.w700,
              letterSpacing: 3, color: TabuColors.subtle)))));
}

class _StepLabel extends StatelessWidget {
  final String step;
  final String label;
  const _StepLabel({required this.step, required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 22, height: 22,
      decoration: BoxDecoration(
        color: TabuColors.rosaPrincipal.withOpacity(0.15),
        border: Border.all(
            color: TabuColors.rosaPrincipal.withOpacity(0.5), width: 0.8)),
      child: Center(child: Text(step,
          style: const TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 8, fontWeight: FontWeight.w800,
              letterSpacing: 0.5, color: TabuColors.rosaPrincipal)))),
    const SizedBox(width: 10),
    Flexible(child: Text(label, style: const TextStyle(
        fontFamily: TabuTypography.bodyFont,
        fontSize: 10, fontWeight: FontWeight.w700,
        letterSpacing: 2.5, color: TabuColors.rosaPrincipal))),
    const SizedBox(width: 12),
    Expanded(child: Container(height: 0.5, color: TabuColors.border)),
  ]);
}

class _LegalBox extends StatelessWidget {
  final List<String> items;
  const _LegalBox({required this.items});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: TabuColors.bgCard,
      border: Border.all(color: TabuColors.border, width: 0.6)),
    child: Column(children: items.map((t) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.check_circle_outline_rounded,
            color: TabuColors.rosaPrincipal, size: 11),
        const SizedBox(width: 8),
        Expanded(child: Text(t,
            style: const TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 10, letterSpacing: 0.3,
                color: TabuColors.dim, height: 1.5))),
      ]))).toList()),
  );
}

class _PrivacyItem extends StatelessWidget {
  final IconData icon;
  final String   texto;
  const _PrivacyItem({required this.icon, required this.texto});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, color: TabuColors.rosaPrincipal, size: 12),
    const SizedBox(width: 8),
    Expanded(child: Text(texto,
        style: const TextStyle(
            fontFamily: TabuTypography.bodyFont,
            fontSize: 10, letterSpacing: 0.3,
            color: TabuColors.dim, height: 1.5))),
  ]);
}

class _ProcessoItem extends StatelessWidget {
  final String numero;
  final String texto;
  const _ProcessoItem({required this.numero, required this.texto});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(
      width: 18, height: 18,
      decoration: BoxDecoration(
        color: TabuColors.rosaPrincipal.withOpacity(0.1),
        border: Border.all(
            color: TabuColors.rosaPrincipal.withOpacity(0.35), width: 0.7)),
      child: Center(child: Text(numero,
          style: const TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 8, fontWeight: FontWeight.w800,
              color: TabuColors.rosaPrincipal)))),
    const SizedBox(width: 10),
    Expanded(child: Text(texto,
        style: const TextStyle(
            fontFamily: TabuTypography.bodyFont,
            fontSize: 10, letterSpacing: 0.3,
            color: TabuColors.dim, height: 1.5))),
  ]);
}

// ══════════════════════════════════════════════════════════════════════════════
//  MOTIVO TILE
// ══════════════════════════════════════════════════════════════════════════════
class _MotivoTile extends StatelessWidget {
  final ReportChatMotivo motivo;
  final bool             selecionado;
  final VoidCallback     onTap;

  const _MotivoTile({
    required this.motivo,
    required this.selecionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selecionado
              ? const Color(0xFFE85D5D).withOpacity(0.07)
              : TabuColors.bgCard,
          border: Border.all(
            color: selecionado
                ? const Color(0xFFE85D5D).withOpacity(0.55)
                : TabuColors.border,
            width: selecionado ? 1.2 : 0.7)),
        child: Row(children: [
          // Radio
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 18, height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selecionado
                  ? const Color(0xFFE85D5D)
                  : Colors.transparent,
              border: Border.all(
                color: selecionado
                    ? const Color(0xFFE85D5D)
                    : TabuColors.border,
                width: selecionado ? 0 : 1.5)),
            child: selecionado
                ? const Icon(Icons.check_rounded,
                    color: Colors.white, size: 11)
                : null),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(motivo.label,
                  style: TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 12, fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                      color: selecionado ? TabuColors.branco : TabuColors.dim)),
              const SizedBox(height: 2),
              Text(motivo.artigo,
                  style: TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 9, letterSpacing: 0.8,
                      color: selecionado
                          ? const Color(0xFFE85D5D).withOpacity(0.75)
                          : TabuColors.border)),
            ])),
          if (selecionado)
            const Icon(Icons.report_gmailerrorred_rounded,
                color: Color(0xFFE85D5D), size: 14),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  CHECKBOX DE CONFIRMAÇÃO
// ══════════════════════════════════════════════════════════════════════════════
class _CheckConfirm extends StatelessWidget {
  final bool                 valor;
  final ValueChanged<bool>   onChanged;
  final String               texto;

  const _CheckConfirm({
    required this.valor,
    required this.onChanged,
    required this.texto,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(!valor);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: valor
              ? TabuColors.rosaPrincipal.withOpacity(0.06)
              : TabuColors.bgCard,
          border: Border.all(
            color: valor
                ? TabuColors.rosaPrincipal.withOpacity(0.4)
                : TabuColors.border,
            width: valor ? 1.0 : 0.7)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 18, height: 18,
            decoration: BoxDecoration(
              color: valor ? TabuColors.rosaPrincipal : Colors.transparent,
              border: Border.all(
                color: valor ? TabuColors.rosaPrincipal : TabuColors.border,
                width: valor ? 0 : 1.5)),
            child: valor
                ? const Icon(Icons.check_rounded,
                    color: Colors.white, size: 12)
                : null),
          const SizedBox(width: 12),
          Expanded(child: Text(texto,
              style: TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 11, letterSpacing: 0.3,
                  color: valor ? TabuColors.dim : TabuColors.subtle,
                  height: 1.5))),
        ]),
      ),
    );
  }
}