// lib/screens/screens_administrative/reports_screens/report_user_screen/report_user_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/services/services_administrative/reports/report_user_service.dart';

// ── Abre a tela de denúncia de usuário ───────────────────────────────────────
Future<void> showReportUserScreen(
  BuildContext context, {
  required String reportedUserId,
  required String reportedUserName,
  required String reporterUid,
}) async {
  await Navigator.push(
    context,
    PageRouteBuilder(
      pageBuilder: (_, animation, __) => ReportUserScreen(
        reportedUserId:   reportedUserId,
        reportedUserName: reportedUserName,
        reporterUid:      reporterUid,
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
class ReportUserScreen extends StatefulWidget {
  final String reportedUserId;
  final String reportedUserName;
  final String reporterUid;

  const ReportUserScreen({
    super.key,
    required this.reportedUserId,
    required this.reportedUserName,
    required this.reporterUid,
  });

  @override
  State<ReportUserScreen> createState() => _ReportUserScreenState();
}

class _ReportUserScreenState extends State<ReportUserScreen>
    with SingleTickerProviderStateMixin {

  // ── Estado ─────────────────────────────────────────────────────────────────
  ReportUserMotivo? _motivo;
  final _descCtrl  = TextEditingController();
  final _descFocus = FocusNode();
  bool  _enviando  = false;
  bool  _enviado   = false;
  bool  _jaReportou = false;
  bool  _checandoReport = true;

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  static const _minChars = 20;

  bool get _descValida  => _descCtrl.text.trim().length >= _minChars;
  bool get _podeEnviar  => _motivo != null && _descValida && !_enviando;

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
    final ja = await ReportUserService.instance
        .jaReportou(widget.reportedUserId);
    if (mounted) setState(() {
      _jaReportou      = ja;
      _checandoReport  = false;
    });
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
      await ReportUserService.instance.reportUser(
        reportedUserId:   widget.reportedUserId,
        reportedUserName: widget.reportedUserName,
        motivo:           _motivo!,
        descricao:        _descCtrl.text,
      );
      if (mounted) setState(() { _enviando = false; _enviado = true; });
      await Future.delayed(const Duration(seconds: 2));
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
            child: _checandoReport
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
  Widget _buildLoading() {
    return const Center(
      child: SizedBox(width: 18, height: 18,
        child: CircularProgressIndicator(
            color: TabuColors.rosaPrincipal, strokeWidth: 1.5)),
    );
  }

  // ── Já denunciou ────────────────────────────────────────────────────────────
  Widget _buildJaReportou() {
    return SafeArea(
      child: Column(children: [
        _buildAppBar(),
        Expanded(child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  color: TabuColors.rosaPrincipal.withOpacity(0.12),
                  border: Border.all(
                      color: TabuColors.rosaPrincipal.withOpacity(0.4),
                      width: 0.8)),
                child: const Icon(Icons.flag_rounded,
                    color: TabuColors.rosaPrincipal, size: 26)),
              const SizedBox(height: 20),
              const Text('JÁ DENUNCIADO', style: TextStyle(
                  fontFamily: TabuTypography.displayFont,
                  fontSize: 20, letterSpacing: 4,
                  color: TabuColors.branco)),
              const SizedBox(height: 12),
              Text(
                'Você já enviou uma denúncia contra\n${widget.reportedUserName.toUpperCase()}.\nNossa equipe irá analisar em breve.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 12, letterSpacing: 0.3,
                    color: TabuColors.subtle, height: 1.7)),
              const SizedBox(height: 8),
              const Text(
                'Conforme Art. 19º – Código de Conduta Tabu',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 9, letterSpacing: 1,
                    color: TabuColors.border)),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity, height: 48,
                  decoration: BoxDecoration(
                    color: TabuColors.bgCard,
                    border: Border.all(color: TabuColors.border, width: 0.8)),
                  child: const Center(child: Text('VOLTAR',
                      style: TextStyle(
                          fontFamily: TabuTypography.bodyFont,
                          fontSize: 11, fontWeight: FontWeight.w700,
                          letterSpacing: 3, color: TabuColors.subtle))))),
            ]),
          ),
        )),
      ]),
    );
  }

  // ── Sucesso ─────────────────────────────────────────────────────────────────
  Widget _buildSucesso() {
    return SafeArea(
      child: Column(children: [
        _buildAppBar(),
        Expanded(child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  color: TabuColors.rosaPrincipal.withOpacity(0.15),
                  border: Border.all(
                      color: TabuColors.rosaPrincipal, width: 1)),
                child: const Icon(Icons.check_rounded,
                    color: TabuColors.rosaPrincipal, size: 28)),
              const SizedBox(height: 20),
              const Text('DENÚNCIA ENVIADA', style: TextStyle(
                  fontFamily: TabuTypography.displayFont,
                  fontSize: 20, letterSpacing: 4,
                  color: TabuColors.branco)),
              const SizedBox(height: 12),
              const Text(
                'Recebemos sua denúncia. Nossa equipe\nirá analisar e tomar as medidas cabíveis\nconforme o Código de Conduta Tabu.',
                textAlign: TextAlign.center,
                style: TextStyle(
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
            ]),
          ),
        )),
      ]),
    );
  }

  // ── Formulário ──────────────────────────────────────────────────────────────
  Widget _buildFormulario() {
    return SafeArea(
      child: Column(children: [
        _buildAppBar(),
        _buildLinhaRosa(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: [

              // ── Header ──────────────────────────────────────────────────────
              _buildHeader(),
              const SizedBox(height: 24),
              _buildDivider(),
              const SizedBox(height: 24),

              // ── Passo 1: Motivo ──────────────────────────────────────────────
              _StepLabel(step: '01', label: 'MOTIVO DA DENÚNCIA'),
              const SizedBox(height: 6),
              const Text(
                'Selecione o que melhor descreve a violação cometida',
                style: TextStyle(fontFamily: TabuTypography.bodyFont,
                    fontSize: 10, letterSpacing: 0.5,
                    color: TabuColors.subtle)),
              const SizedBox(height: 14),

              ...ReportUserMotivo.values.map((m) => _MotivoTile(
                motivo:      m,
                selecionado: _motivo == m,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _motivo = m);
                },
              )),

              const SizedBox(height: 24),
              _buildDivider(),
              const SizedBox(height: 24),

              // ── Passo 2: Descrição ───────────────────────────────────────────
              _StepLabel(step: '02', label: 'DESCREVA O PROBLEMA'),
              const SizedBox(height: 6),
              Row(children: [
                const Text('Mínimo de 20 caracteres',
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

              const SizedBox(height: 24),

              // ── Base Legal ───────────────────────────────────────────────────
              _buildBaseLegal(),
              const SizedBox(height: 24),

              // ── Aviso de responsabilidade ────────────────────────────────────
              _buildAvisoResponsabilidade(),
              const SizedBox(height: 28),

              // ── Botão Enviar ─────────────────────────────────────────────────
              _buildBotaoEnviar(),
              const SizedBox(height: 8),
              _buildBotaoCancelar(),
            ],
          ),
        ),
      ]),
    );
  }

  // ── Sub-widgets do formulário ──────────────────────────────────────────────

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 16, 0),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: TabuColors.dim, size: 16),
          onPressed: () => Navigator.pop(context)),
        const Spacer(),
        Text('DENÚNCIA',
            style: TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 9, fontWeight: FontWeight.w700,
              letterSpacing: 3,
              color: TabuColors.subtle.withOpacity(0.6))),
        const SizedBox(width: 16),
      ]),
    );
  }

  Widget _buildLinhaRosa() {
    return Container(
      height: 1.5,
      margin: const EdgeInsets.only(top: 6),
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [
        Colors.transparent, TabuColors.rosaDeep,
        TabuColors.rosaPrincipal, TabuColors.rosaClaro,
        TabuColors.rosaPrincipal, TabuColors.rosaDeep, Colors.transparent,
      ])),
    );
  }

  Widget _buildDivider() => Container(
    height: 0.5,
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [
      Colors.transparent, TabuColors.border, Colors.transparent,
    ])),
  );

  Widget _buildHeader() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFF3D0A0A),
            border: Border.all(
                color: const Color(0xFFE85D5D).withOpacity(0.5),
                width: 0.8)),
          child: const Icon(Icons.flag_outlined,
              color: Color(0xFFE85D5D), size: 14)),
        const SizedBox(width: 12),
        const Text('DENUNCIAR USUÁRIO', style: TextStyle(
            fontFamily: TabuTypography.displayFont,
            fontSize: 17, letterSpacing: 4,
            color: TabuColors.branco)),
      ]),
      const SizedBox(height: 12),

      // Card do usuário denunciado
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: TabuColors.bgCard,
          border: Border.all(color: TabuColors.border, width: 0.6)),
        child: Row(children: [
          const Icon(Icons.person_outline_rounded,
              color: TabuColors.subtle, size: 14),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.reportedUserName.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 12, fontWeight: FontWeight.w700,
                    letterSpacing: 1.5, color: TabuColors.branco)),
              const SizedBox(height: 2),
              const Text('Usuário reportado',
                  style: TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 9, letterSpacing: 0.5,
                      color: TabuColors.subtle)),
            ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF3D0A0A),
              border: Border.all(
                  color: const Color(0xFFE85D5D).withOpacity(0.4),
                  width: 0.6)),
            child: const Text('ALVO',
                style: TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 7, fontWeight: FontWeight.w700,
                    letterSpacing: 2, color: Color(0xFFE85D5D)))),
        ])),
      const SizedBox(height: 8),
      const Text(
        'Denúncias são analisadas conforme o Código de Conduta Tabu (Art. 18º–20º).',
        style: TextStyle(fontFamily: TabuTypography.bodyFont,
            fontSize: 9, letterSpacing: 0.5,
            color: TabuColors.subtle)),
    ]);
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          controller: _descCtrl,
          focusNode:  _descFocus,
          maxLines:   5,
          maxLength:  500,
          style: const TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 13, color: TabuColors.branco, height: 1.5),
          cursorColor: TabuColors.rosaPrincipal,
          decoration: const InputDecoration(
            border: InputBorder.none,
            isDense: true,
            hintText: 'Descreva com detalhes o comportamento que motivou esta denúncia...',
            hintStyle: TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 12, color: TabuColors.subtle, height: 1.5),
            contentPadding: EdgeInsets.all(14),
            counterText: ''),
        ),
        // Barra de progresso
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 2,
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: (_descCtrl.text.trim().length / _minChars).clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _descValida
                      ? [TabuColors.rosaDeep, TabuColors.rosaPrincipal]
                      : [const Color(0xFF5D0A0A), const Color(0xFFE85D5D)],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildBaseLegal() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TabuColors.rosaPrincipal.withOpacity(0.05),
        border: Border.all(color: TabuColors.border, width: 0.6)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.gavel_outlined, color: TabuColors.subtle, size: 12),
          const SizedBox(width: 8),
          const Text('BASE LEGAL', style: TextStyle(
              fontFamily: TabuTypography.bodyFont, fontSize: 8,
              fontWeight: FontWeight.w700, letterSpacing: 2.5,
              color: TabuColors.subtle)),
        ]),
        const SizedBox(height: 8),
        if (_motivo != null)
          Text('${_motivo!.artigo}\n${_motivo!.label}',
              style: const TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 11, letterSpacing: 0.3,
                  color: TabuColors.dim, height: 1.6))
        else
          const Text(
            'Selecione um motivo para ver a base legal aplicável.',
            style: TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 10, letterSpacing: 0.3,
                color: TabuColors.subtle, height: 1.5)),
      ]),
    );
  }

  Widget _buildAvisoResponsabilidade() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF3D0A0A).withOpacity(0.4),
        border: Border.all(
            color: const Color(0xFFE85D5D).withOpacity(0.2), width: 0.6)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.warning_amber_rounded,
            color: Color(0xFFE85D5D), size: 13),
        const SizedBox(width: 8),
        const Expanded(child: Text(
          'Denúncias falsas ou de má-fé podem resultar em penalidades '
          'contra o denunciante, conforme Art. 19º do Código de Conduta Tabu.',
          style: TextStyle(fontFamily: TabuTypography.bodyFont,
              fontSize: 10, letterSpacing: 0.3,
              color: TabuColors.subtle, height: 1.5))),
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
          color: _podeEnviar
              ? const Color(0xFFE85D5D)
              : TabuColors.bgCard,
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
                Icon(Icons.flag_rounded,
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

  Widget _buildBotaoCancelar() {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        height: 44,
        child: const Center(child: Text('CANCELAR',
            style: TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 11, fontWeight: FontWeight.w700,
                letterSpacing: 2.5, color: TabuColors.subtle)))),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  STEP LABEL
// ══════════════════════════════════════════════════════════════════════════════
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
    Text(label, style: const TextStyle(
        fontFamily: TabuTypography.bodyFont,
        fontSize: 10, fontWeight: FontWeight.w700,
        letterSpacing: 3, color: TabuColors.rosaPrincipal)),
    const SizedBox(width: 12),
    Expanded(child: Container(height: 0.5, color: TabuColors.border)),
  ]);
}

// ══════════════════════════════════════════════════════════════════════════════
//  MOTIVO TILE
// ══════════════════════════════════════════════════════════════════════════════
class _MotivoTile extends StatelessWidget {
  final ReportUserMotivo motivo;
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
              ? const Color(0xFFE85D5D).withOpacity(0.08)
              : TabuColors.bgCard,
          border: Border.all(
            color: selecionado
                ? const Color(0xFFE85D5D).withOpacity(0.6)
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
                      color: selecionado
                          ? TabuColors.branco : TabuColors.dim)),
              const SizedBox(height: 2),
              Text(motivo.artigo,
                  style: TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 9, letterSpacing: 0.8,
                      color: selecionado
                          ? const Color(0xFFE85D5D).withOpacity(0.8)
                          : TabuColors.border)),
            ])),
          if (selecionado)
            const Icon(Icons.flag_rounded,
                color: Color(0xFFE85D5D), size: 14),
        ]),
      ),
    );
  }
}