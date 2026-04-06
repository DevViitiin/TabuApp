// lib/screens/screens_home/chat/chat_room_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tabuapp/controllers/controllers_app/tabu_chat_controller.dart';
import 'package:tabuapp/screens/screens_administrative/reports_screens/report_chat_screen/report_chat_screen.dart';
import '../../../core/theme/tabu_theme.dart';
import '../../../models/chat_model.dart';
import '../../../services/services_app/cached_avatar.dart';

class ChatRoomScreen extends StatefulWidget {
  final String myUid;
  final String otherUid;
  final String otherName;
  final String? otherAvatar;

  const ChatRoomScreen({
    super.key,
    required this.myUid,
    required this.otherUid,
    required this.otherName,
    this.otherAvatar,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen>
    with WidgetsBindingObserver {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _showScrollBtn     = false;
  bool _hasText           = false;
  bool _isLoadingMore     = false;
  bool _initialScrollDone = false;
  int  _prevCount         = 0;

  // Chat ID no mesmo formato do Firebase (UIDs ordenados)
  String get _chatId {
    final ids = [widget.myUid, widget.otherUid]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _textCtrl.addListener(() {
      final has = _textCtrl.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
    
    // Listener para scroll automático quando teclado abrir
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        // Múltiplos scrolls em diferentes momentos para garantir
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && _scroll.hasClients) _scrollToBottom();
        });
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _scroll.hasClients) _scrollToBottom();
        });
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted && _scroll.hasClients) _scrollToBottom();
        });
      }
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _init();
      _setupScrollListener();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<TabuChatController>().markAsRead();
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // Quando o teclado abre/fecha, rola para o final
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    if (keyboardHeight > 0 && _focusNode.hasFocus) {
      // Teclado aberto - faz scroll com delay para garantir que o layout já ajustou
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && _scroll.hasClients) {
          _scrollToBottom();
        }
      });
      // Segundo scroll com mais delay para garantir
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted && _scroll.hasClients) {
          _scrollToBottom();
        }
      });
    }
  }

  Future<void> _init() async {
    if (!mounted) return;
    final ctrl = context.read<TabuChatController>();
    await ctrl.initialize(myUid: widget.myUid, otherUid: widget.otherUid);
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom(animated: false);
        _initialScrollDone = true;
      });
    }
  }

  void _setupScrollListener() {
    _scroll.addListener(() {
      if (!mounted) return;
      final atBottom =
          _scroll.position.pixels >= _scroll.position.maxScrollExtent - 120;
      if (_showScrollBtn == atBottom) {
        setState(() => _showScrollBtn = !atBottom);
      }
      if (_scroll.position.pixels <= 80 && !_isLoadingMore) {
        _isLoadingMore = true;
        context.read<TabuChatController>()
            .loadMore()
            .then((_) => _isLoadingMore = false);
      }
    });
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    if (animated) {
      _scroll.animateTo(max,
          duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    } else {
      _scroll.jumpTo(max);
    }
  }

  bool get _isNearBottom {
    if (!_scroll.hasClients) return true;
    return (_scroll.position.maxScrollExtent - _scroll.position.pixels) <= 160;
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.selectionClick();
    _textCtrl.clear();
    setState(() => _hasText = false);
    await context.read<TabuChatController>().send(text);
    // Múltiplos scrolls para garantir que a mensagem enviada apareça
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToBottom();
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && _scroll.hasClients) _scrollToBottom();
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _scroll.hasClients) _scrollToBottom();
    });
  }

  // ── Menu de opções ────────────────────────────────────────────────────────
  void _abrirMenuOpcoes() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (_) => _ChatOptionsSheet(
        otherName:   widget.otherName,
        onDenunciar: () {
          Navigator.pop(context);
          showReportChatScreen(
            context,
            chatId:       _chatId,
            reportedUid:  widget.otherUid,
            reportedName: widget.otherName,
            reporterUid:  widget.myUid,
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: TabuColors.bg,
      body: Stack(children: [
        Positioned(top: 0, left: 0, right: 0,
          child: Container(height: 1.5,
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [
              Colors.transparent, TabuColors.rosaDeep,
              TabuColors.rosaPrincipal, TabuColors.rosaClaro,
              TabuColors.rosaPrincipal, TabuColors.rosaDeep, Colors.transparent,
            ])))),
        SafeArea(child: Column(children: [
          _buildAppBar(),
          Expanded(child: Consumer<TabuChatController>(
            builder: (context, ctrl, _) {
              if (ctrl.isLoading) return _buildLoading();
              if (ctrl.error != null) return _buildError(ctrl.error!);
              final count = ctrl.messages.length;
              if (_initialScrollDone && count > _prevCount) {
                _prevCount = count;
                if (_isNearBottom) {
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _scrollToBottom());
                }
              } else {
                _prevCount = count;
              }
              return Stack(children: [
                ctrl.messages.isEmpty ? _buildEmpty() : _buildList(ctrl),
                if (_showScrollBtn) _buildScrollBtn(),
              ]);
            },
          )),
          _buildInput(),
        ])),
      ]),
    );
  }

  // ── App Bar ───────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return Consumer<TabuChatController>(builder: (_, ctrl, __) {
      final status   = ctrl.otherStatus;
      final isOnline = status?.isOnline ?? false;

      return Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: TabuColors.bg,
          border: Border(bottom: BorderSide(
              color: TabuColors.border.withOpacity(0.5), width: 0.5))),
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: TabuColors.dim, size: 16),
            onPressed: () => Navigator.pop(context)),
          const SizedBox(width: 4),
          Stack(children: [
            CachedAvatar(uid: widget.otherUid, name: widget.otherName,
                size: 40, radius: 6),
            if (isOnline)
              Positioned(right: 0, bottom: 0,
                child: Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    shape: BoxShape.circle,
                    border: Border.all(color: TabuColors.bg, width: 1.5),
                    boxShadow: [BoxShadow(
                        color: const Color(0xFF22C55E).withOpacity(0.5),
                        blurRadius: 6)]))),
          ]),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(widget.otherName.toUpperCase(),
                  style: const TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 13, fontWeight: FontWeight.w700,
                      letterSpacing: 2, color: TabuColors.branco)),
              const SizedBox(height: 2),
              Text(isOnline ? 'ONLINE AGORA' : _lastSeenText(status),
                  style: TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 9, letterSpacing: 1.5,
                      color: isOnline
                          ? const Color(0xFF22C55E) : TabuColors.subtle)),
            ])),
          GestureDetector(
            onTap: _abrirMenuOpcoes,
            child: Container(
              width: 34, height: 34,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                  border: Border.all(color: TabuColors.border, width: 0.8)),
              child: const Icon(Icons.more_horiz,
                  color: TabuColors.subtle, size: 15))),
        ]));
    });
  }

  String _lastSeenText(ParticipantStatus? status) {
    if (status == null) return 'OFFLINE';
    final diff    = DateTime.now().millisecondsSinceEpoch - status.lastSeen;
    final minutes = diff ~/ 60000;
    if (minutes < 1)  return 'VIU AGORA';
    if (minutes < 60) return 'VIU HÁ ${minutes}MIN';
    final hours = minutes ~/ 60;
    if (hours < 24)   return 'VIU HÁ ${hours}H';
    return 'OFFLINE';
  }

  // ── Lista ─────────────────────────────────────────────────────────────────
  Widget _buildList(TabuChatController ctrl) {
    final msgs = ctrl.messages;
    int lastMineIdx = -1;
    for (int i = msgs.length - 1; i >= 0; i--) {
      if (ctrl.isMine(msgs[i])) { lastMineIdx = i; break; }
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      itemCount: msgs.length + (ctrl.isLoadingMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (ctrl.isLoadingMore && i == 0) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 1.5, color: TabuColors.rosaPrincipal))));
        }
        final idx  = ctrl.isLoadingMore ? i - 1 : i;
        final msg  = msgs[idx];
        final mine = ctrl.isMine(msg);
        Widget? sep;
        if (idx == 0 || _differentDay(msgs[idx - 1].timestamp, msg.timestamp)) {
          sep = _buildDateSeparator(msg.timestamp);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (sep != null) sep,
          _MessageBubble(
            message:  msg, isMine: mine,
            otherUid: widget.otherUid,
            isLast:   mine && idx == lastMineIdx),
        ]);
      },
    );
  }

  bool _differentDay(int a, int b) {
    final da = DateTime.fromMillisecondsSinceEpoch(a);
    final db = DateTime.fromMillisecondsSinceEpoch(b);
    return da.day != db.day || da.month != db.month || da.year != db.year;
  }

  Widget _buildDateSeparator(int ts) {
    final dt  = DateTime.fromMillisecondsSinceEpoch(ts);
    final now = DateTime.now();
    String label;
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      label = 'HOJE';
    } else if (dt.day == now.day - 1 && dt.month == now.month && dt.year == now.year) {
      label = 'ONTEM';
    } else {
      label = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(children: [
        Expanded(child: Container(height: 0.5,
            decoration: const BoxDecoration(gradient: LinearGradient(
                colors: [Colors.transparent, TabuColors.border])))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(label, style: const TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 8, letterSpacing: 2.5, color: TabuColors.subtle))),
        Expanded(child: Container(height: 0.5,
            decoration: const BoxDecoration(gradient: LinearGradient(
                colors: [TabuColors.border, Colors.transparent])))),
      ]));
  }

  // ── Input ─────────────────────────────────────────────────────────────────
  Widget _buildInput() {
    return Consumer<TabuChatController>(builder: (_, ctrl, __) {
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: TabuColors.bg,
          border: Border(top: BorderSide(
              color: TabuColors.border.withOpacity(0.4), width: 0.5))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: Container(
            constraints: const BoxConstraints(maxHeight: 120),
            decoration: BoxDecoration(
              color: TabuColors.bgCard,
              border: Border.all(
                  color: _hasText
                      ? TabuColors.rosaPrincipal.withOpacity(0.4)
                      : TabuColors.border,
                  width: 0.8)),
            child: TextField(
              controller: _textCtrl, focusNode: _focusNode,
              enabled: !ctrl.isSending, maxLines: null,
              style: const TextStyle(fontFamily: TabuTypography.bodyFont,
                  fontSize: 14, color: TabuColors.branco, height: 1.4),
              decoration: InputDecoration(
                hintText: 'Mensagem...',
                hintStyle: TextStyle(fontFamily: TabuTypography.bodyFont,
                    fontSize: 13, letterSpacing: 0.5,
                    color: TabuColors.subtle.withOpacity(0.5)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12)),
              onSubmitted: (_) => _send()),
          )),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _hasText && !ctrl.isSending ? _send : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46, height: 46,
              decoration: BoxDecoration(
                gradient: _hasText
                    ? const LinearGradient(
                        colors: [TabuColors.rosaDeep, TabuColors.rosaPrincipal],
                        begin: Alignment.topLeft, end: Alignment.bottomRight)
                    : null,
                color: _hasText ? null : TabuColors.bgCard,
                border: Border.all(
                    color: _hasText
                        ? TabuColors.rosaPrincipal.withOpacity(0.3)
                        : TabuColors.border,
                    width: 0.8),
                boxShadow: _hasText ? [BoxShadow(
                    color: TabuColors.glow.withOpacity(0.35),
                    blurRadius: 14, offset: const Offset(0, 4))] : null),
              child: ctrl.isSending
                  ? const Center(child: SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5, color: Colors.white)))
                  : Icon(Icons.send_rounded, size: 18,
                      color: _hasText ? Colors.white : TabuColors.subtle))),
        ]));
    });
  }

  Widget _buildLoading() => const Center(child: SizedBox(width: 24, height: 24,
    child: CircularProgressIndicator(
        strokeWidth: 1.5, color: TabuColors.rosaPrincipal)));

  Widget _buildEmpty() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(
      width: 64, height: 64,
      decoration: BoxDecoration(
        color: TabuColors.bgCard,
        border: Border.all(
            color: TabuColors.rosaPrincipal.withOpacity(0.3), width: 0.8),
        boxShadow: [BoxShadow(
            color: TabuColors.glow.withOpacity(0.15),
            blurRadius: 20, spreadRadius: 2)]),
      child: const Icon(Icons.mark_chat_unread_outlined,
          color: TabuColors.rosaPrincipal, size: 26)),
    const SizedBox(height: 16),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: TabuColors.rosaPrincipal.withOpacity(0.1),
        border: Border.all(
            color: TabuColors.rosaPrincipal.withOpacity(0.35), width: 0.7)),
      child: const Text('CHAT AINDA NÃO ABERTO', style: TextStyle(
          fontFamily: TabuTypography.bodyFont,
          fontSize: 8, fontWeight: FontWeight.w700,
          letterSpacing: 2.5, color: TabuColors.rosaPrincipal))),
    const SizedBox(height: 14),
    Text('Seja o primeiro a dizer oi para\n${widget.otherName.toUpperCase()}',
        textAlign: TextAlign.center,
        style: const TextStyle(fontFamily: TabuTypography.bodyFont,
            fontSize: 12, letterSpacing: 0.3,
            color: TabuColors.dim, height: 1.5)),
    const SizedBox(height: 20),
    Icon(Icons.keyboard_arrow_down_rounded,
        color: TabuColors.subtle.withOpacity(0.4), size: 20),
  ]));

  Widget _buildError(String msg) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.error_outline_rounded,
        color: TabuColors.rosaPrincipal, size: 32),
    const SizedBox(height: 12),
    Text(msg, textAlign: TextAlign.center,
        style: const TextStyle(fontFamily: TabuTypography.bodyFont,
            fontSize: 12, color: TabuColors.dim)),
    const SizedBox(height: 16),
    GestureDetector(
      onTap: _init,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(border: Border.all(
            color: TabuColors.rosaPrincipal.withOpacity(0.5), width: 0.8)),
        child: const Text('TENTAR NOVAMENTE', style: TextStyle(
            fontFamily: TabuTypography.bodyFont,
            fontSize: 9, letterSpacing: 2.5,
            color: TabuColors.rosaPrincipal)))),
  ]));

  Widget _buildScrollBtn() => Positioned(
    right: 16, bottom: 16,
    child: GestureDetector(
      onTap: _scrollToBottom,
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: TabuColors.bgCard,
          border: Border.all(
              color: TabuColors.rosaPrincipal.withOpacity(0.4), width: 0.8),
          boxShadow: [BoxShadow(
              color: TabuColors.glow.withOpacity(0.2), blurRadius: 12)]),
        child: const Icon(Icons.keyboard_arrow_down_rounded,
            color: TabuColors.rosaPrincipal, size: 20))));

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SHEET DE OPÇÕES
// ══════════════════════════════════════════════════════════════════════════════
class _ChatOptionsSheet extends StatelessWidget {
  final String       otherName;
  final VoidCallback onDenunciar;
  const _ChatOptionsSheet({required this.otherName, required this.onDenunciar});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: TabuColors.bgAlt),
      child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 32, height: 2,
          margin: const EdgeInsets.only(top: 14),
          decoration: BoxDecoration(
              color: TabuColors.border,
              borderRadius: BorderRadius.circular(1))),
        Container(
          height: 1.5,
          margin: const EdgeInsets.only(top: 12),
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [
            Colors.transparent, TabuColors.rosaDeep,
            TabuColors.rosaPrincipal, TabuColors.rosaClaro,
            TabuColors.rosaPrincipal, TabuColors.rosaDeep, Colors.transparent,
          ]))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: TabuColors.bgCard,
                border: Border.all(color: TabuColors.border, width: 0.8)),
              child: const Icon(Icons.chat_bubble_outline_rounded,
                  color: TabuColors.subtle, size: 13)),
            const SizedBox(width: 10),
            Text(otherName.toUpperCase(), style: const TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 10, fontWeight: FontWeight.w700,
                letterSpacing: 2.5, color: TabuColors.subtle)),
          ])),
        Container(
          height: 0.5,
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [
            Colors.transparent, TabuColors.border, Colors.transparent,
          ]))),
        GestureDetector(
          onTap: onDenunciar,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF3D0A0A).withOpacity(0.5),
              border: Border.all(
                  color: const Color(0xFFE85D5D).withOpacity(0.25), width: 0.7)),
            child: Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF3D0A0A),
                  border: Border.all(
                      color: const Color(0xFFE85D5D).withOpacity(0.4), width: 0.7)),
                child: const Icon(Icons.report_gmailerrorred_rounded,
                    color: Color(0xFFE85D5D), size: 13)),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('DENUNCIAR CONVERSA', style: TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 12, fontWeight: FontWeight.w700,
                      letterSpacing: 1.5, color: Color(0xFFE85D5D))),
                  const SizedBox(height: 2),
                  const Text(
                    'Assédio, conteúdo impróprio, ameaças ou golpe',
                    style: TextStyle(
                        fontFamily: TabuTypography.bodyFont,
                        fontSize: 9, letterSpacing: 0.5,
                        color: TabuColors.subtle)),
                ])),
              const Icon(Icons.chevron_right_rounded,
                  color: Color(0xFFE85D5D), size: 16),
            ])),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            height: 44,
            decoration: BoxDecoration(
              color: TabuColors.bgCard,
              border: Border.all(color: TabuColors.border, width: 0.8)),
            child: const Center(child: Text('CANCELAR', style: TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 11, fontWeight: FontWeight.w700,
                letterSpacing: 2.5, color: TabuColors.subtle))))),
        const SizedBox(height: 8),
      ])),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  MESSAGE BUBBLE
// ══════════════════════════════════════════════════════════════════════════════
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool        isMine;
  final String      otherUid;
  final bool        isLast;

  const _MessageBubble({
    required this.message, required this.isMine,
    required this.otherUid, this.isLast = false,
  });

  String _formatHour(int ts) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _readAgoText(int readAtMs) {
    final diff    = DateTime.now().millisecondsSinceEpoch - readAtMs;
    final seconds = diff ~/ 1000;
    if (seconds < 60)  return 'visto agora';
    final minutes = seconds ~/ 60;
    if (minutes < 60)  return 'visto há ${minutes}min';
    final hours = minutes ~/ 60;
    if (hours < 24)    return 'visto há ${hours}h';
    return 'visto há ${hours ~/ 24}d';
  }

  @override
  Widget build(BuildContext context) {
    final isRead   = message.isReadBy(otherUid);
    final readAtMs = message.readAtBy(otherUid);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Align(
            alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.74),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                decoration: BoxDecoration(
                  gradient: isMine
                      ? const LinearGradient(
                          colors: [TabuColors.rosaDeep, Color(0xFF8B1A4A)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight)
                      : null,
                  color: isMine ? null : TabuColors.bgCard,
                  border: Border.all(
                    color: isMine
                        ? TabuColors.rosaPrincipal.withOpacity(0.25)
                        : TabuColors.border.withOpacity(0.6),
                    width: 0.6),
                  boxShadow: isMine ? [BoxShadow(
                      color: TabuColors.glow.withOpacity(0.15),
                      blurRadius: 10, offset: const Offset(0, 3))] : null),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Align(alignment: Alignment.centerLeft,
                      child: Text(message.text,
                          style: TextStyle(
                              fontFamily: TabuTypography.bodyFont,
                              fontSize: 14, height: 1.45,
                              color: isMine
                                  ? Colors.white
                                  : TabuColors.branco.withOpacity(0.92)))),
                    const SizedBox(height: 4),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(_formatHour(message.timestamp),
                          style: TextStyle(
                              fontFamily: TabuTypography.bodyFont,
                              fontSize: 9, letterSpacing: 0.5,
                              color: isMine
                                  ? Colors.white.withOpacity(0.55)
                                  : TabuColors.subtle)),
                      if (isMine) ...[
                        const SizedBox(width: 4),
                        Icon(
                          isRead ? Icons.done_all_rounded : Icons.done_rounded,
                          size: 12,
                          color: isRead
                              ? const Color(0xFF60A5FA)
                              : Colors.white.withOpacity(0.45)),
                      ],
                    ]),
                  ],
                ),
              ),
            ),
          ),
          if (isMine && isLast) ...[
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isRead) ...[
                    const Icon(Icons.done_all_rounded,
                        size: 10, color: Color(0xFF60A5FA)),
                    const SizedBox(width: 4),
                    Text(readAtMs != null ? _readAgoText(readAtMs) : 'visto',
                        style: const TextStyle(
                            fontFamily: TabuTypography.bodyFont,
                            fontSize: 9, letterSpacing: 0.5,
                            color: Color(0xFF60A5FA))),
                  ] else ...[
                    Icon(Icons.done_rounded, size: 10,
                        color: TabuColors.subtle.withOpacity(0.6)),
                    const SizedBox(width: 4),
                    Text('enviado', style: TextStyle(
                        fontFamily: TabuTypography.bodyFont,
                        fontSize: 9, letterSpacing: 0.5,
                        color: TabuColors.subtle.withOpacity(0.6))),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}