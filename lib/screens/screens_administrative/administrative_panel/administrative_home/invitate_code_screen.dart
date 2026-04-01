// lib/screens/screens_administrative/administrative_panel/invite_code/invite_code_screen.dart
//
//  Tela de gerenciamento do código de convite (Invitation_code no RTDB)
//  ▸ Exibe o código atual
//  ▸ Permite editar e salvar
//  ▸ Permite gerar um código aleatório
//  ▸ Histórico dos últimos códigos alterados (salvo localmente em sessão)
//
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';

class InviteCodeScreen extends StatefulWidget {
  final String adminUid;
  const InviteCodeScreen({super.key, required this.adminUid});

  @override
  State<InviteCodeScreen> createState() => _InviteCodeScreenState();
}

class _InviteCodeScreenState extends State<InviteCodeScreen> {
  final _db          = FirebaseDatabase.instance.ref();
  final _ctrl        = TextEditingController();
  final _focusNode   = FocusNode();

  String  _currentCode  = '';
  bool    _loading      = true;
  bool    _saving       = false;
  bool    _editing      = false;
  bool    _justCopied   = false;
  String? _error;
  String? _successMsg;

  // Histórico em memória da sessão
  final List<_CodeHistoryEntry> _history = [];

  @override
  void initState() {
    super.initState();
    _loadCode();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCode() async {
    setState(() { _loading = true; _error = null; });
    try {
      final snap = await _db.child('Invitation_code').get();
      final code = snap.value as String? ?? '';
      if (mounted) setState(() {
        _currentCode = code;
        _ctrl.text   = code;
        _loading     = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error   = 'Erro ao carregar código: $e';
        _loading = false;
      });
    }
  }

  Future<void> _saveCode() async {
    final novo = _ctrl.text.trim().toUpperCase();
    if (novo.isEmpty) {
      setState(() => _error = 'O código não pode ser vazio.');
      return;
    }
    if (novo == _currentCode) {
      setState(() { _editing = false; _error = null; });
      return;
    }
    if (novo.length < 4) {
      setState(() => _error = 'Mínimo 4 caracteres.');
      return;
    }

    setState(() { _saving = true; _error = null; _successMsg = null; });
    HapticFeedback.mediumImpact();

    try {
      await _db.child('Invitation_code').set(novo);

      _history.insert(0, _CodeHistoryEntry(
        codigo:     _currentCode,
        alteradoEm: DateTime.now(),
        alteradoPor: widget.adminUid,
      ));

      if (mounted) setState(() {
        _currentCode = novo;
        _ctrl.text   = novo;
        _saving      = false;
        _editing     = false;
        _successMsg  = 'Código atualizado com sucesso!';
      });

      // Limpa mensagem de sucesso após 3s
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _successMsg = null);
      });
    } catch (e) {
      if (mounted) setState(() {
        _error  = 'Erro ao salvar: $e';
        _saving = false;
      });
    }
  }

  void _startEditing() {
    setState(() {
      _editing    = true;
      _error      = null;
      _successMsg = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _ctrl.selection = TextSelection(
        baseOffset:   0,
        extentOffset: _ctrl.text.length,
      );
    });
  }

  void _cancelEditing() {
    setState(() {
      _editing = false;
      _error   = null;
      _ctrl.text = _currentCode;
    });
    _focusNode.unfocus();
  }

  void _generateRandom() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng   = Random.secure();
    final code  = List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
    setState(() {
      _ctrl.text = code;
      _editing   = true;
      _error     = null;
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: _currentCode));
    HapticFeedback.selectionClick();
    setState(() => _justCopied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _justCopied = false);
    });
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
          Expanded(child: _loading
              ? _buildLoading()
              : _buildBody()),
        ]),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x33FF2D7A), width: 0.8))),
      child: SafeArea(bottom: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Row(children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(width: 35, height: 35,
              color: Colors.transparent,
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white54, size: 18))),
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
              const Text('CÓDIGO DE CONVITE',
                style: TextStyle(
                  fontFamily:    TabuTypography.displayFont,
                  fontSize:      10, letterSpacing: 1, color: Colors.white)),
            ]),
            const SizedBox(height: 3),
            Text('Invitation_code · Firebase RTDB',
              style: TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 8, letterSpacing: 1,
                color: Colors.white.withOpacity(0.3))),
          ])),

          // Botão gerar aleatório
          GestureDetector(
            onTap: _generateRandom,
            child: Container(
              height: 35,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color:  TabuColors.rosaDeep.withOpacity(0.2),
                border: Border.all(
                  color: TabuColors.rosaPrincipal.withOpacity(0.4),
                  width: 0.8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: const [
                Icon(Icons.casino_outlined,
                  color: TabuColors.rosaPrincipal, size: 13),
                SizedBox(width: 4),
                Text('GERAR',
                  style: TextStyle(
                    fontFamily:    TabuTypography.bodyFont,
                    fontSize:      6, fontWeight: FontWeight.w700,
                    letterSpacing: 1, color: TabuColors.rosaPrincipal)),
              ])),
          ),
        ]),
      )),
    );
  }

  // ── Loading ───────────────────────────────────────────────────────────────
  Widget _buildLoading() => const Center(
    child: SizedBox(width: 22, height: 22,
      child: CircularProgressIndicator(strokeWidth: 1.5,
        valueColor: AlwaysStoppedAnimation(TabuColors.rosaPrincipal))));

  // ── Body ──────────────────────────────────────────────────────────────────
  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Código atual ───────────────────────────────────────────────────
        _sectionLabel('CÓDIGO ATUAL'),
        const SizedBox(height: 12),
        _buildCurrentCodeCard(),

        const SizedBox(height: 28),

        // ── Editor ────────────────────────────────────────────────────────
        _sectionLabel('ALTERAR CÓDIGO'),
        const SizedBox(height: 12),
        _buildEditor(),

        // ── Mensagens feedback ─────────────────────────────────────────────
        if (_error != null) ...[
          const SizedBox(height: 14),
          _buildFeedbackBanner(
            msg:   _error!,
            color: const Color(0xFFE85D5D),
            icon:  Icons.error_outline_rounded),
        ],
        if (_successMsg != null) ...[
          const SizedBox(height: 14),
          _buildFeedbackBanner(
            msg:   _successMsg!,
            color: const Color(0xFF4CAF50),
            icon:  Icons.check_circle_outline_rounded),
        ],

        const SizedBox(height: 32),

        // ── Info ───────────────────────────────────────────────────────────
        _buildInfoCard(),

        const SizedBox(height: 28),

        // ── Histórico da sessão ────────────────────────────────────────────
        if (_history.isNotEmpty) ...[
          _sectionLabel('HISTÓRICO DA SESSÃO'),
          const SizedBox(height: 12),
          _buildHistory(),
        ],
      ]),
    );
  }

  // ── Card código atual ─────────────────────────────────────────────────────
  Widget _buildCurrentCodeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      decoration: BoxDecoration(
        color:  TabuColors.rosaDeep.withOpacity(0.08),
        border: Border.all(
          color: TabuColors.rosaPrincipal.withOpacity(0.3), width: 0.8),
        boxShadow: [BoxShadow(
          color:      TabuColors.glow.withOpacity(0.1),
          blurRadius: 20, offset: const Offset(0, 4))]),
      child: Column(children: [

        // Linha topo decorativa
        Container(
          width: double.infinity, height: 1.5,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [
            Colors.transparent, TabuColors.rosaDeep,
            TabuColors.rosaPrincipal, TabuColors.rosaDeep, Colors.transparent,
          ]))),

        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.vpn_key_rounded,
            color: TabuColors.rosaPrincipal, size: 14),
          const SizedBox(width: 10),
          Text(_currentCode.isEmpty ? '—' : _currentCode,
            style: TextStyle(
              fontFamily:    TabuTypography.displayFont,
              fontSize:      36, letterSpacing: 12,
              color:         Colors.white,
              shadows: [Shadow(
                color: TabuColors.glow.withOpacity(0.6), blurRadius: 20)])),
        ]),

        const SizedBox(height: 16),

        // Botão copiar
        GestureDetector(
          onTap: _currentCode.isNotEmpty ? _copyCode : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color:  _justCopied
                  ? const Color(0xFF4CAF50).withOpacity(0.15)
                  : Colors.white.withOpacity(0.05),
              border: Border.all(
                color: _justCopied
                    ? const Color(0xFF4CAF50).withOpacity(0.5)
                    : Colors.white.withOpacity(0.12),
                width: 0.8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                _justCopied
                    ? Icons.check_rounded
                    : Icons.copy_rounded,
                color: _justCopied
                    ? const Color(0xFF4CAF50)
                    : Colors.white38,
                size: 12),
              const SizedBox(width: 8),
              Text(
                _justCopied ? 'COPIADO!' : 'COPIAR CÓDIGO',
                style: TextStyle(
                  fontFamily:    TabuTypography.bodyFont,
                  fontSize:      9, fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: _justCopied
                      ? const Color(0xFF4CAF50)
                      : Colors.white38)),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── Editor ────────────────────────────────────────────────────────────────
  Widget _buildEditor() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // Campo de texto
      Container(
        decoration: BoxDecoration(
          color:  Colors.white.withOpacity(0.04),
          border: Border.all(
            color: _editing
                ? TabuColors.rosaPrincipal.withOpacity(0.5)
                : Colors.white.withOpacity(0.1),
            width: _editing ? 1.0 : 0.7)),
        child: Row(children: [
          Expanded(child: TextField(
            controller:  _ctrl,
            focusNode:   _focusNode,
            enabled:     !_saving,
            maxLength:   20,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              _UpperCaseFormatter(),
            ],
            style: const TextStyle(
              fontFamily:    TabuTypography.displayFont,
              fontSize:      22, letterSpacing: 6,
              color:         Colors.white),
            decoration: InputDecoration(
              hintText:      'NOVO CÓDIGO',
              hintStyle:     TextStyle(
                fontFamily:    TabuTypography.displayFont,
                fontSize:      22, letterSpacing: 6,
                color:         Colors.white.withOpacity(0.15)),
              border:        InputBorder.none,
              counterText:   '',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14)),
            onChanged: (_) {
              if (!_editing) setState(() => _editing = true);
              if (_error != null) setState(() => _error = null);
            },
          )),

          // Limpar
          if (_editing)
            GestureDetector(
              onTap: () {
                _ctrl.clear();
                setState(() => _error = null);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.close_rounded,
                  color: Colors.white24, size: 16))),
        ]),
      ),

      const SizedBox(height: 6),
      Text('Apenas letras (A-Z) e números. Sem espaços ou caracteres especiais.',
        style: TextStyle(
          fontFamily: TabuTypography.bodyFont,
          fontSize: 9, letterSpacing: 0.5,
          color: Colors.white.withOpacity(0.25))),

      const SizedBox(height: 16),

      // Botões de ação
      Row(children: [

        // Cancelar (só quando editando)
        if (_editing) ...[
          Expanded(child: GestureDetector(
            onTap: _saving ? null : _cancelEditing,
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color:  Colors.white.withOpacity(0.04),
                border: Border.all(color: Colors.white12, width: 0.8)),
              child: const Center(child: Text('CANCELAR',
                style: TextStyle(
                  fontFamily:    TabuTypography.bodyFont,
                  fontSize:      10, fontWeight: FontWeight.w700,
                  letterSpacing: 2.5, color: Colors.white38)))))),
          const SizedBox(width: 10),
        ],

        // Salvar / Editar
        Expanded(child: GestureDetector(
          onTap: _saving
              ? null
              : _editing ? _saveCode : _startEditing,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 46,
            decoration: BoxDecoration(
              gradient: _editing
                  ? const LinearGradient(
                      colors: [TabuColors.rosaDeep, TabuColors.rosaPrincipal],
                      begin:  Alignment.centerLeft,
                      end:    Alignment.centerRight)
                  : null,
              color: _editing ? null : Colors.white.withOpacity(0.06),
              border: Border.all(
                color: _editing
                    ? TabuColors.rosaPrincipal.withOpacity(0.3)
                    : Colors.white.withOpacity(0.12),
                width: 0.8),
              boxShadow: _editing ? [BoxShadow(
                color:      TabuColors.glow.withOpacity(0.3),
                blurRadius: 14, offset: const Offset(0, 4))] : null),
            child: Center(child: _saving
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation(Colors.white)))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      _editing
                          ? Icons.save_rounded
                          : Icons.edit_outlined,
                      color: _editing ? Colors.white : Colors.white54,
                      size: 14),
                    const SizedBox(width: 8),
                    Text(
                      _editing ? 'SALVAR CÓDIGO' : 'EDITAR CÓDIGO',
                      style: TextStyle(
                        fontFamily:    TabuTypography.bodyFont,
                        fontSize:      10, fontWeight: FontWeight.w700,
                        letterSpacing: 2.5,
                        color: _editing ? Colors.white : Colors.white54)),
                  ])),
          ),
        )),
      ]),
    ]);
  }

  // ── Banner de feedback ────────────────────────────────────────────────────
  Widget _buildFeedbackBanner({
    required String  msg,
    required Color   color,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color:  color.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.3), width: 0.7)),
      child: Row(children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 10),
        Expanded(child: Text(msg,
          style: TextStyle(
            fontFamily: TabuTypography.bodyFont,
            fontSize: 11, height: 1.4, letterSpacing: 0.3,
            color: color.withOpacity(0.9)))),
      ]),
    );
  }

  // ── Info card ─────────────────────────────────────────────────────────────
  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:  Colors.white.withOpacity(0.025),
        border: Border.all(color: Colors.white.withOpacity(0.07), width: 0.7)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.info_outline_rounded,
            color: Colors.white30, size: 13),
          const SizedBox(width: 8),
          Text('SOBRE O CÓDIGO DE CONVITE',
            style: TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 9, fontWeight: FontWeight.w700,
              letterSpacing: 2, color: Colors.white.withOpacity(0.3))),
        ]),
        const SizedBox(height: 12),
        Container(height: 0.5,
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [
            Colors.transparent, Color(0x1AFFFFFF), Colors.transparent,
          ]))),
        const SizedBox(height: 12),
        _infoItem(
          icon: Icons.lock_outline_rounded,
          texto: 'O código é exigido no cadastro. Sem ele, nenhum novo usuário consegue criar uma conta no app.'),
        const SizedBox(height: 10),
        _infoItem(
          icon: Icons.warning_amber_rounded,
          texto: 'Após alterar, o código anterior deixa de funcionar imediatamente. Comunique os usuários antes de trocar.',
          warn: true),
        const SizedBox(height: 10),
        _infoItem(
          icon: Icons.casino_outlined,
          texto: 'Use o botão GERAR para criar um código aleatório de 6 caracteres alfanuméricos seguros.'),
      ]),
    );
  }

  Widget _infoItem({
    required IconData icon,
    required String   texto,
    bool warn = false,
  }) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon,
        color: warn
            ? const Color(0xFFFF8C00).withOpacity(0.7)
            : Colors.white.withOpacity(0.25),
        size: 12),
      const SizedBox(width: 10),
      Expanded(child: Text(texto,
        style: TextStyle(
          fontFamily: TabuTypography.bodyFont,
          fontSize: 11, height: 1.6, letterSpacing: 0.2,
          color: warn
              ? const Color(0xFFFF8C00).withOpacity(0.7)
              : Colors.white.withOpacity(0.35)))),
    ]);
  }

  // ── Histórico ─────────────────────────────────────────────────────────────
  Widget _buildHistory() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withOpacity(0.07), width: 0.7)),
      child: Column(children: [
        for (int i = 0; i < _history.length; i++) ...[
          if (i > 0)
            Container(height: 0.5, color: Colors.white.withOpacity(0.06)),
          _HistoryTile(entry: _history[i]),
        ],
      ]),
    );
  }

  Widget _sectionLabel(String label) => Row(children: [
    Container(width: 2, height: 12, color: TabuColors.rosaPrincipal),
    const SizedBox(width: 8),
    Text(label, style: TextStyle(
      fontFamily: TabuTypography.bodyFont,
      fontSize: 9, fontWeight: FontWeight.w700,
      letterSpacing: 2.5, color: Colors.white.withOpacity(0.38))),
  ]);
}

// ══════════════════════════════════════════════════════════════════════════════
//  HISTORY TILE
// ══════════════════════════════════════════════════════════════════════════════
class _HistoryTile extends StatelessWidget {
  final _CodeHistoryEntry entry;
  const _HistoryTile({required this.entry});

  String _formatTs(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60)  return 'agora';
    if (diff.inMinutes < 60)  return '${diff.inMinutes}min atrás';
    if (diff.inHours   < 24)  return '${diff.inHours}h atrás';
    return '${diff.inDays}d atrás';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color:  Colors.white.withOpacity(0.04),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.6)),
          child: Text(entry.codigo,
            style: const TextStyle(
              fontFamily:    TabuTypography.displayFont,
              fontSize:      14, letterSpacing: 4,
              color:         Colors.white38))),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('CÓDIGO ANTERIOR',
            style: TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 8, fontWeight: FontWeight.w700,
              letterSpacing: 2, color: Colors.white24)),
          const SizedBox(height: 3),
          Text(_formatTs(entry.alteradoEm),
            style: const TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 9, color: Colors.white24, letterSpacing: 0.3)),
        ])),
        const Icon(Icons.history_rounded, color: Colors.white12, size: 14),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  DATA CLASS
// ══════════════════════════════════════════════════════════════════════════════
class _CodeHistoryEntry {
  final String   codigo;
  final DateTime alteradoEm;
  final String   alteradoPor;
  const _CodeHistoryEntry({
    required this.codigo,
    required this.alteradoEm,
    required this.alteradoPor,
  });
}

// ══════════════════════════════════════════════════════════════════════════════
//  FORMATTER
// ══════════════════════════════════════════════════════════════════════════════
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}