// lib/screens/screens_home/home_screen/posts/story_report_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/models/story_model.dart';
import '../../../../services/services_administrative/reports/report_story_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  MODELO DE MOTIVO DE DENÚNCIA
// ══════════════════════════════════════════════════════════════════════════════
class _ReportMotivo {
  final String id;
  final String label;
  final String artigo;
  final String descricaoLegal;
  final IconData icone;

  const _ReportMotivo({
    required this.id,
    required this.label,
    required this.artigo,
    required this.descricaoLegal,
    required this.icone,
  });
}

// ══════════════════════════════════════════════════════════════════════════════
//  TELA DE DENÚNCIA DE STORY
// ══════════════════════════════════════════════════════════════════════════════
class StoryReportScreen extends StatefulWidget {
  final StoryModel story;
  final String     reporterUid;

  const StoryReportScreen({
    super.key,
    required this.story,
    required this.reporterUid,
  });

  @override
  State<StoryReportScreen> createState() => _StoryReportScreenState();
}

class _StoryReportScreenState extends State<StoryReportScreen>
    with SingleTickerProviderStateMixin {

  static const List<_ReportMotivo> _motivos = [
    _ReportMotivo(
      id:             'violacao_lei',
      label:          'Viola a lei',
      artigo:         'Termos de Uso – Art. 10º, I',
      descricaoLegal: 'Conteúdo que viola a legislação brasileira vigente.',
      icone:          Icons.gavel_rounded,
    ),
    _ReportMotivo(
      id:             'ofensivo',
      label:          'Ofensivo ou discriminatório',
      artigo:         'Termos de Uso – Art. 10º, II',
      descricaoLegal: 'Conteúdo ofensivo, discriminatório ou prejudicial a terceiros.',
      icone:          Icons.warning_amber_rounded,
    ),
    _ReportMotivo(
      id:             'seguranca',
      label:          'Ameaça à segurança',
      artigo:         'Termos de Uso – Art. 10º, III',
      descricaoLegal: 'Conteúdo que compromete a segurança ou integridade do app.',
      icone:          Icons.shield_outlined,
    ),
    _ReportMotivo(
      id:             'spam',
      label:          'Spam ou conteúdo repetitivo',
      artigo:         'Termos de Uso – Art. 10º, II',
      descricaoLegal: 'Conteúdo repetitivo, enganoso ou sem valor para a comunidade.',
      icone:          Icons.block_rounded,
    ),
    _ReportMotivo(
      id:             'privacidade',
      label:          'Violação de privacidade',
      artigo:         'Política de Privacidade – Art. 5º e 6º',
      descricaoLegal: 'Exposição indevida de dados ou conteúdo privado de terceiros.',
      icone:          Icons.lock_outline_rounded,
    ),
    _ReportMotivo(
      id:             'outro',
      label:          'Outro motivo',
      artigo:         'Termos de Uso – Art. 18º',
      descricaoLegal: 'Qualquer outra violação ao Código de Conduta do Tabu.',
      icone:          Icons.more_horiz_rounded,
    ),
  ];

  _ReportMotivo? _motivoSelecionado;
  final _descricaoCtrl = TextEditingController();
  bool _enviando       = false;
  bool _enviado        = false;

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _descricaoCtrl.dispose();
    super.dispose();
  }

  // ── Envio ─────────────────────────────────────────────────────────────────
  Future<void> _enviar() async {
    if (_motivoSelecionado == null || _enviando) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();

    setState(() => _enviando = true);

    try {
      await ReportService.instance.reportStory(
        storyId:       widget.story.id,
        storyOwnerId:  widget.story.userId,
        reporterUid:   widget.reporterUid,
        motivo:        _motivoSelecionado!.id,
        motivoLabel:   _motivoSelecionado!.label,
        artigo:        _motivoSelecionado!.artigo,
        descricao:     _descricaoCtrl.text.trim(),
      );

      if (!mounted) return;
      setState(() {
        _enviando = false;
        _enviado  = true;
      });

      await Future.delayed(const Duration(milliseconds: 1800));
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF3D0A0A),
          behavior:        SnackBarBehavior.floating,
          shape:           const RoundedRectangleBorder(),
          margin:          const EdgeInsets.all(16),
          content: const Text(
            'Erro ao enviar denúncia. Tente novamente.',
            style: TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize:   12, fontWeight: FontWeight.w700,
              letterSpacing: 1.5, color: Colors.white,
            ),
          ),
        ),
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0010),
        body: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: _enviado ? _buildSucesso() : _buildFormulario(),
          ),
        ),
      ),
    );
  }

  // ── Formulário ────────────────────────────────────────────────────────────
  Widget _buildFormulario() {
    return SafeArea(
      child: Column(children: [

        // ── Header ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
          child: Row(children: [
            _IconBtn(
              icon:  Icons.close,
              onTap: () => Navigator.pop(context),
            ),
            const Spacer(),
            const Text('DENUNCIAR STORY',
              style: TextStyle(
                fontFamily:    TabuTypography.displayFont,
                fontSize:      13, letterSpacing: 3,
                color:         Colors.white,
              )),
            const Spacer(),
            const SizedBox(width: 40),
          ]),
        ),

        // ── Linha decorativa ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Container(
            height: 0.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent,
                TabuColors.rosaPrincipal.withOpacity(0.6),
                Colors.transparent,
              ]),
            ),
          ),
        ),

        // ── Preview do story ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _StoryPreviewTile(story: widget.story),
        ),

        // ── Corpo scrollável ─────────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Subtítulo
                const Text('SELECIONE O MOTIVO',
                  style: TextStyle(
                    fontFamily:    TabuTypography.bodyFont,
                    fontSize:      10, fontWeight: FontWeight.w700,
                    letterSpacing: 2.5, color: Colors.white38,
                  )),
                const SizedBox(height: 12),

                // Lista de motivos
                ...List.generate(_motivos.length, (i) {
                  final m        = _motivos[i];
                  final selected = _motivoSelecionado?.id == m.id;
                  return _MotivoTile(
                    motivo:   m,
                    selected: selected,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _motivoSelecionado = m);
                    },
                  );
                }),

                // Detalhes legais do motivo selecionado
                if (_motivoSelecionado != null) ...[
                  const SizedBox(height: 16),
                  _LegalBox(motivo: _motivoSelecionado!),
                ],

                const SizedBox(height: 20),

                // Campo de descrição opcional
                const Text('DESCRIÇÃO ADICIONAL (OPCIONAL)',
                  style: TextStyle(
                    fontFamily:    TabuTypography.bodyFont,
                    fontSize:      10, fontWeight: FontWeight.w700,
                    letterSpacing: 2.5, color: Colors.white38,
                  )),
                const SizedBox(height: 10),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1), width: 0.8),
                  ),
                  child: TextField(
                    controller:  _descricaoCtrl,
                    maxLines:    4,
                    maxLength:   280,
                    style: const TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize:   13, color: Colors.white,
                    ),
                    decoration: InputDecoration(
                      hintText:       'Descreva com mais detalhes o que aconteceu...',
                      hintStyle:      TextStyle(
                        fontFamily: TabuTypography.bodyFont,
                        fontSize:   12, color: Colors.white24,
                      ),
                      border:         InputBorder.none,
                      contentPadding: const EdgeInsets.all(14),
                      counterStyle:   const TextStyle(
                        fontFamily: TabuTypography.bodyFont,
                        fontSize: 10, color: Colors.white24,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Nota de política
                _NotaLegal(),

                const SizedBox(height: 24),

                // Botão enviar
                _BotaoEnviar(
                  ativo:    _motivoSelecionado != null,
                  enviando: _enviando,
                  onTap:    _enviar,
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  // ── Tela de sucesso ───────────────────────────────────────────────────────
  Widget _buildSucesso() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TabuColors.rosaDeep.withOpacity(0.15),
                border: Border.all(
                  color: TabuColors.rosaPrincipal.withOpacity(0.5), width: 1),
                boxShadow: [BoxShadow(
                  color: TabuColors.glow.withOpacity(0.35),
                  blurRadius: 24, spreadRadius: 2,
                )],
              ),
              child: const Icon(
                Icons.check_rounded,
                color: TabuColors.rosaPrincipal, size: 32,
              ),
            ),
            const SizedBox(height: 24),
            const Text('DENÚNCIA ENVIADA',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily:    TabuTypography.displayFont,
                fontSize:      18, letterSpacing: 4,
                color:         Colors.white,
              )),
            const SizedBox(height: 12),
            Text(
              'Nossa equipe analisará o conteúdo com base nos Termos de Uso. '
              'Obrigado por contribuir com uma comunidade mais segura.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize:   12, height: 1.7,
                color:      Colors.white.withOpacity(0.5),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  PREVIEW DO STORY DENUNCIADO
// ══════════════════════════════════════════════════════════════════════════════
class _StoryPreviewTile extends StatelessWidget {
  final StoryModel story;
  const _StoryPreviewTile({required this.story});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:  Colors.white.withOpacity(0.04),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 0.8),
      ),
      child: Row(children: [

        // Miniatura do story
        Container(
          width: 44, height: 60,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            border: Border.all(
              color: TabuColors.rosaPrincipal.withOpacity(0.3), width: 0.8),
          ),
          child: story.mediaUrl != null
              ? Image.network(story.mediaUrl!, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _storyIcon())
              : _storyIcon(),
        ),
        const SizedBox(width: 12),

        // Info
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(story.userName.toUpperCase(),
              style: const TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 11, fontWeight: FontWeight.w700,
                letterSpacing: 1.5, color: Colors.white,
              )),
            const SizedBox(height: 4),
            Text(_tipoLabel(story.type),
              style: TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 10, color: Colors.white38, letterSpacing: 0.5,
              )),
            if (story.centralText != null) ...[
              const SizedBox(height: 4),
              Text(story.centralText!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 11, color: Colors.white54,
                )),
            ],
          ],
        )),

        // Badge visibilidade
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color:  Colors.white.withOpacity(0.06),
            border: Border.all(color: Colors.white12, width: 0.6),
          ),
          child: Text(story.visibilidade.toUpperCase(),
            style: const TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 8, fontWeight: FontWeight.w700,
              letterSpacing: 1.5, color: Colors.white38,
            )),
        ),
      ]),
    );
  }

  Widget _storyIcon() => Center(child: Icon(
    story.type == 'emoji'  ? Icons.emoji_emotions_outlined :
    story.type == 'texto'  ? Icons.text_fields_rounded     :
                             Icons.image_outlined,
    color: Colors.white24, size: 20,
  ));

  String _tipoLabel(String t) {
    switch (t) {
      case 'camera': return 'Foto · Story';
      case 'texto':  return 'Texto · Story';
      case 'emoji':  return 'Emoji · Story';
      default:       return 'Story';
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  TILE DE MOTIVO
// ══════════════════════════════════════════════════════════════════════════════
class _MotivoTile extends StatelessWidget {
  final _ReportMotivo motivo;
  final bool          selected;
  final VoidCallback  onTap;

  const _MotivoTile({
    required this.motivo,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin:   const EdgeInsets.only(bottom: 8),
        padding:  const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: selected
              ? TabuColors.rosaDeep.withOpacity(0.18)
              : Colors.white.withOpacity(0.04),
          border: Border.all(
            color: selected
                ? TabuColors.rosaPrincipal.withOpacity(0.6)
                : Colors.white.withOpacity(0.08),
            width: selected ? 1.0 : 0.8,
          ),
        ),
        child: Row(children: [
          Icon(motivo.icone,
            size:  18,
            color: selected ? TabuColors.rosaPrincipal : Colors.white38,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(motivo.label,
            style: TextStyle(
              fontFamily:    TabuTypography.bodyFont,
              fontSize:      13, fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: selected ? Colors.white : Colors.white70,
            ))),
          AnimatedOpacity(
            opacity:  selected ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 180),
            child: Container(
              width: 18, height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TabuColors.rosaPrincipal,
              ),
              child: const Icon(Icons.check, size: 11, color: Colors.white),
            ),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  BOX DE REFERÊNCIA LEGAL
// ══════════════════════════════════════════════════════════════════════════════
class _LegalBox extends StatelessWidget {
  final _ReportMotivo motivo;
  const _LegalBox({required this.motivo});

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve:    Curves.easeOutCubic,
      child: Container(
        width:   double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: TabuColors.rosaDeep.withOpacity(0.08),
          border: Border(
            left: BorderSide(
              color: TabuColors.rosaPrincipal.withOpacity(0.5), width: 2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(motivo.artigo,
              style: TextStyle(
                fontFamily:    TabuTypography.bodyFont,
                fontSize:      9, fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
                color:         TabuColors.rosaPrincipal.withOpacity(0.8),
              )),
            const SizedBox(height: 5),
            Text(motivo.descricaoLegal,
              style: TextStyle(
                fontFamily:    TabuTypography.bodyFont,
                fontSize:      11, height: 1.6,
                color:         Colors.white54,
                letterSpacing: 0.2,
              )),
            const SizedBox(height: 8),
            Text(
              'Nos termos do Art. 19º, denúncias procedentes podem resultar em '
              'advertência, suspensão temporária ou exclusão da conta.',
              style: TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 10, height: 1.5,
                color: Colors.white30, letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  NOTA LEGAL RODAPÉ
// ══════════════════════════════════════════════════════════════════════════════
class _NotaLegal extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 0.6),
      ),
      child: Text(
        'Ao enviar esta denúncia, você confirma que as informações são '
        'verdadeiras e que a denúncia está em conformidade com os Termos de Uso '
        'do Tabu (Art. 18º). Denúncias de má-fé podem resultar em penalidades '
        'conforme o Art. 19º.',
        style: TextStyle(
          fontFamily: TabuTypography.bodyFont,
          fontSize: 10, height: 1.6,
          color: Colors.white24, letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  BOTÃO ENVIAR
// ══════════════════════════════════════════════════════════════════════════════
class _BotaoEnviar extends StatelessWidget {
  final bool         ativo;
  final bool         enviando;
  final VoidCallback onTap;

  const _BotaoEnviar({
    required this.ativo,
    required this.enviando,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: ativo && !enviando ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width:    double.infinity,
        height:   52,
        decoration: BoxDecoration(
          gradient: ativo
              ? const LinearGradient(
                  colors: [TabuColors.rosaDeep, TabuColors.rosaPrincipal],
                  begin:  Alignment.centerLeft,
                  end:    Alignment.centerRight,
                )
              : null,
          color: ativo ? null : Colors.white.withOpacity(0.06),
          border: Border.all(
            color: ativo
                ? TabuColors.rosaPrincipal
                : Colors.white.withOpacity(0.1),
            width: 1,
          ),
          boxShadow: ativo
              ? [BoxShadow(
                  color:       TabuColors.glow.withOpacity(0.35),
                  blurRadius:  16, spreadRadius: 1,
                )]
              : null,
        ),
        child: Center(
          child: enviando
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ))
              : Text(
                  'ENVIAR DENÚNCIA',
                  style: TextStyle(
                    fontFamily:    TabuTypography.bodyFont,
                    fontSize:      12, fontWeight: FontWeight.w700,
                    letterSpacing: 2.5,
                    color: ativo ? Colors.white : Colors.white30,
                  ),
                ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  BOTÃO ÍCONE
// ══════════════════════════════════════════════════════════════════════════════
class _IconBtn extends StatelessWidget {
  final IconData     icon;
  final VoidCallback onTap;

  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40, height: 40,
      color: Colors.transparent,
      child: Icon(icon, color: Colors.white70, size: 22),
    ),
  );
}