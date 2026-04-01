// lib/screens/screens_home/home_screen/posts/report_post_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/services/services_administrative/reports/report_post_service.dart';


// ── Abre o sheet de denúncia ──────────────────────────────────────────────────
Future<void> showReportPostSheet(
  BuildContext context, {
  required String postId,
  required String postOwnerId,
  required String postTitulo,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.85),
    builder: (_) => ReportScreen(
      postId:       postId,
      postOwnerId:  postOwnerId,
      postTitulo:   postTitulo,
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  SHEET PRINCIPAL
// ══════════════════════════════════════════════════════════════════════════════
class ReportScreen extends StatefulWidget {
  final String postId;
  final String postOwnerId;
  final String postTitulo;

  const ReportScreen({
    required this.postId,
    required this.postOwnerId,
    required this.postTitulo,
  });

  @override
  State<ReportScreen> createState() => _ReportScreen();
}

class _ReportScreen extends State<ReportScreen>
    with SingleTickerProviderStateMixin {

  // ── Estado ─────────────────────────────────────────────────────────────────
  ReportMotivo? _motivo;
  final _descCtrl  = TextEditingController();
  final _descFocus = FocusNode();
  bool  _enviando  = false;
  bool  _enviado   = false;
  bool  _jaReportou = false;

  // Animação de entrada
  late AnimationController _animCtrl;
  late Animation<double>   _anim;

  static const _minChars = 20;

  bool get _descValida => _descCtrl.text.trim().length >= _minChars;
  bool get _podeEnviar => _motivo != null && _descValida && !_enviando;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _anim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _animCtrl.forward();
    _descCtrl.addListener(() => setState(() {}));
    _verificarJaReportou();
  }

  Future<void> _verificarJaReportou() async {
    final ja = await ReportService.instance.jaReportou(widget.postId);
    if (mounted) setState(() => _jaReportou = ja);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _descCtrl.dispose();
    _descFocus.dispose();
    super.dispose();
  }

  // ── Enviar denúncia ─────────────────────────────────────────────────────────
  Future<void> _enviar() async {
    if (!_podeEnviar) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    setState(() => _enviando = true);

    try {
      await ReportService.instance.reportPost(
        postId:      widget.postId,
        postOwnerId: widget.postOwnerId,
        motivo:      _motivo!,
        descricao:   _descCtrl.text,
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
          content: Text('ERRO AO ENVIAR: $e',
              style: const TextStyle(fontFamily: TabuTypography.bodyFont,
                  fontSize: 11, fontWeight: FontWeight.w700,
                  letterSpacing: 2, color: TabuColors.branco))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, 40 * (1 - _anim.value)),
        child: Opacity(opacity: _anim.value, child: child),
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: TabuColors.bgAlt,
          border: Border(
            top: BorderSide(color: TabuColors.rosaPrincipal, width: 1.5)),
        ),
        padding: EdgeInsets.only(bottom: bottom),
        child: _enviado
            ? _buildSucesso()
            : _jaReportou
                ? _buildJaReportou()
                : _buildFormulario(),
      ),
    );
  }

  // ── Já denunciou ────────────────────────────────────────────────────────────
  Widget _buildJaReportou() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _Handle(),
          const SizedBox(height: 24),
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: TabuColors.rosaPrincipal.withOpacity(0.12),
              border: Border.all(color: TabuColors.rosaPrincipal.withOpacity(0.4), width: 0.8)),
            child: const Icon(Icons.flag_rounded, color: TabuColors.rosaPrincipal, size: 24)),
          const SizedBox(height: 16),
          const Text('JÁ DENUNCIADO', style: TextStyle(
              fontFamily: TabuTypography.displayFont,
              fontSize: 18, letterSpacing: 4, color: TabuColors.branco)),
          const SizedBox(height: 8),
          const Text('Você já enviou uma denúncia para este post.\nNossa equipe irá analisar em breve.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: TabuTypography.bodyFont,
                  fontSize: 12, letterSpacing: 0.3,
                  color: TabuColors.subtle, height: 1.6)),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: double.infinity, height: 48,
              decoration: BoxDecoration(
                color: TabuColors.bgCard,
                border: Border.all(color: TabuColors.border, width: 0.8)),
              child: const Center(child: Text('FECHAR',
                  style: TextStyle(fontFamily: TabuTypography.bodyFont,
                      fontSize: 11, fontWeight: FontWeight.w700,
                      letterSpacing: 3, color: TabuColors.subtle))))),
        ]),
      ),
    );
  }

  // ── Sucesso ─────────────────────────────────────────────────────────────────
  Widget _buildSucesso() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _Handle(),
          const SizedBox(height: 24),
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: TabuColors.rosaPrincipal.withOpacity(0.15),
              border: Border.all(color: TabuColors.rosaPrincipal, width: 1)),
            child: const Icon(Icons.check_rounded, color: TabuColors.rosaPrincipal, size: 28)),
          const SizedBox(height: 16),
          const Text('DENÚNCIA ENVIADA', style: TextStyle(
              fontFamily: TabuTypography.displayFont,
              fontSize: 18, letterSpacing: 4, color: TabuColors.branco)),
          const SizedBox(height: 8),
          const Text('Recebemos sua denúncia. Nossa equipe\nirá analisar e tomar as medidas cabíveis.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: TabuTypography.bodyFont,
                  fontSize: 12, letterSpacing: 0.3,
                  color: TabuColors.subtle, height: 1.6)),
          const SizedBox(height: 6),
          Text('Referência: Art. 18º e 19º – Código de Conduta Tabu',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: TabuTypography.bodyFont,
                  fontSize: 9, letterSpacing: 1,
                  color: TabuColors.subtle.withOpacity(0.5))),
        ]),
      ),
    );
  }

  // ── Formulário ──────────────────────────────────────────────────────────────
  Widget _buildFormulario() {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Column(children: [
        _Handle(),

        // ── Cabeçalho ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF3D0A0A),
                  border: Border.all(color: const Color(0xFFE85D5D).withOpacity(0.5), width: 0.8)),
                child: const Icon(Icons.flag_outlined,
                    color: Color(0xFFE85D5D), size: 14)),
              const SizedBox(width: 12),
              const Text('DENUNCIAR POST', style: TextStyle(
                  fontFamily: TabuTypography.displayFont,
                  fontSize: 16, letterSpacing: 4, color: TabuColors.branco)),
            ]),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: TabuColors.bgCard,
                border: Border.all(color: TabuColors.border, width: 0.6)),
              child: Row(children: [
                const Icon(Icons.article_outlined, color: TabuColors.subtle, size: 12),
                const SizedBox(width: 8),
                Expanded(child: Text('"${widget.postTitulo}"',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: TabuTypography.bodyFont,
                        fontSize: 11, letterSpacing: 0.3,
                        color: TabuColors.dim, fontStyle: FontStyle.italic))),
              ])),
            const SizedBox(height: 4),
            const Text(
              'Denúncias são analisadas conforme o Código de Conduta Tabu (Art. 18º–20º).',
              style: TextStyle(fontFamily: TabuTypography.bodyFont,
                  fontSize: 9, letterSpacing: 0.5, color: TabuColors.subtle)),
          ]),
        ),

        Container(height: 0.5,
            margin: const EdgeInsets.symmetric(vertical: 14),
            color: TabuColors.border),

        // ── Conteúdo rolável ─────────────────────────────────────────────────
        Expanded(child: ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [

            // ── Passo 1: Motivo ───────────────────────────────────────────────
            _StepLabel(step: '01', label: 'MOTIVO DA DENÚNCIA'),
            const SizedBox(height: 4),
            const Text('Selecione o que melhor descreve a violação',
                style: TextStyle(fontFamily: TabuTypography.bodyFont,
                    fontSize: 10, letterSpacing: 0.5, color: TabuColors.subtle)),
            const SizedBox(height: 12),

            ...ReportMotivo.values.map((m) => _MotivoTile(
              motivo:     m,
              selecionado: _motivo == m,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _motivo = m);
              },
            )),

            const SizedBox(height: 20),
            Container(height: 0.5, color: TabuColors.border),
            const SizedBox(height: 20),

            // ── Passo 2: Descrição ────────────────────────────────────────────
            _StepLabel(step: '02', label: 'DESCREVA O PROBLEMA'),
            const SizedBox(height: 4),
            Row(children: [
              const Text('Mínimo de 20 caracteres',
                  style: TextStyle(fontFamily: TabuTypography.bodyFont,
                      fontSize: 10, letterSpacing: 0.5, color: TabuColors.subtle)),
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

            Container(
              decoration: BoxDecoration(
                color: TabuColors.bgCard,
                border: Border.all(
                  color: _descFocus.hasFocus
                      ? (_descValida ? TabuColors.rosaPrincipal : const Color(0xFFE85D5D))
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
                    hintText: 'Descreva o problema com detalhes para nos ajudar a analisar melhor...',
                    hintStyle: TextStyle(fontFamily: TabuTypography.bodyFont,
                        fontSize: 12, color: TabuColors.subtle, height: 1.5),
                    contentPadding: EdgeInsets.all(14),
                    counterText: ''),
                ),

                // Barra de progresso dos caracteres
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _descValida
                          ? [TabuColors.rosaDeep, TabuColors.rosaPrincipal]
                          : [const Color(0xFF3D0A0A), const Color(0xFFE85D5D)],
                    ),
                  ),
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
            ),

            if (!_descValida && _descCtrl.text.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(children: [
                  const Icon(Icons.info_outline, color: Color(0xFFE85D5D), size: 11),
                  const SizedBox(width: 5),
                  Text(
                    'Faltam ${_minChars - _descCtrl.text.trim().length} caracteres',
                    style: const TextStyle(fontFamily: TabuTypography.bodyFont,
                        fontSize: 10, letterSpacing: 0.8,
                        color: Color(0xFFE85D5D))),
                ])),

            const SizedBox(height: 28),

            // ── Aviso legal ───────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: TabuColors.rosaPrincipal.withOpacity(0.05),
                border: Border.all(color: TabuColors.border, width: 0.6)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.gavel_outlined,
                      color: TabuColors.subtle, size: 12),
                  const SizedBox(width: 6),
                  const Text('BASE LEGAL', style: TextStyle(
                      fontFamily: TabuTypography.bodyFont, fontSize: 8,
                      fontWeight: FontWeight.w700, letterSpacing: 2.5,
                      color: TabuColors.subtle)),
                ]),
                const SizedBox(height: 6),
                if (_motivo != null)
                  Text('${_motivo!.artigo} – ${_motivo!.label}',
                      style: const TextStyle(fontFamily: TabuTypography.bodyFont,
                          fontSize: 10, letterSpacing: 0.3,
                          color: TabuColors.dim, height: 1.5))
                else
                  const Text('Selecione um motivo para ver a base legal aplicável.',
                      style: TextStyle(fontFamily: TabuTypography.bodyFont,
                          fontSize: 10, letterSpacing: 0.3,
                          color: TabuColors.subtle, height: 1.5)),
                const SizedBox(height: 6),
                const Text(
                  'Denúncias falsas ou de má-fé podem resultar em penalidades conforme Art. 19º.',
                  style: TextStyle(fontFamily: TabuTypography.bodyFont,
                      fontSize: 9, letterSpacing: 0.3,
                      color: TabuColors.border, height: 1.5)),
              ]),
            ),

            const SizedBox(height: 20),

            // ── Botão enviar ──────────────────────────────────────────────────
            GestureDetector(
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
                  boxShadow: _podeEnviar ? [
                    BoxShadow(
                      color: const Color(0xFFE85D5D).withOpacity(0.3),
                      blurRadius: 16, offset: const Offset(0, 4)),
                  ] : null),
                child: Stack(alignment: Alignment.center, children: [
                  if (_enviando)
                    const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 1.5))
                  else
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
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
                    ]),
                ]),
              ),
            ),

            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                height: 44,
                child: const Center(child: Text('CANCELAR',
                    style: TextStyle(fontFamily: TabuTypography.bodyFont,
                        fontSize: 11, fontWeight: FontWeight.w700,
                        letterSpacing: 2.5, color: TabuColors.subtle)))),
            ),
          ],
        )),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  WIDGETS INTERNOS
// ══════════════════════════════════════════════════════════════════════════════
class _Handle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 36, height: 3,
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      decoration: BoxDecoration(
        color: TabuColors.border,
        borderRadius: BorderRadius.circular(2))));
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
        border: Border.all(color: TabuColors.rosaPrincipal.withOpacity(0.5), width: 0.8)),
      child: Center(child: Text(step,
          style: const TextStyle(fontFamily: TabuTypography.bodyFont,
              fontSize: 8, fontWeight: FontWeight.w800,
              letterSpacing: 0.5, color: TabuColors.rosaPrincipal)))),
    const SizedBox(width: 10),
    Text(label, style: const TextStyle(fontFamily: TabuTypography.bodyFont,
        fontSize: 10, fontWeight: FontWeight.w700,
        letterSpacing: 3, color: TabuColors.rosaPrincipal)),
    const SizedBox(width: 12),
    Expanded(child: Container(height: 0.5, color: TabuColors.border)),
  ]);
}

class _MotivoTile extends StatelessWidget {
  final ReportMotivo motivo;
  final bool         selecionado;
  final VoidCallback onTap;

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
                    fontSize: 9, letterSpacing: 1,
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