// lib/screens/screens_home/chat/chat_list_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:tabuapp/controllers/controllers_app/tabu_chat_controller.dart';
import 'package:tabuapp/screens/screens_administrative/chat_screen/chat_screen.dart';
import 'package:tabuapp/services/services_app/chat_request_service.dart';
import 'package:tabuapp/services/services_app/tabu_chat_service.dart';
import '../../../core/theme/tabu_theme.dart';
import '../../../models/chat_model.dart';
import '../../../models/chat_request_model.dart';
import '../../../services/services_app/cached_avatar.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        setState(() {});
      }
    });
  }

  void _goToTab(int index) {
    _tabCtrl.animateTo(index);
    setState(() {});
    if (index == 1 && _myUid.isNotEmpty) {
      ChatRequestService().markAllAsSeen(_myUid);
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TabuColors.bg,
      body: Stack(children: [
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            height: 1.5,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent, TabuColors.rosaDeep,
                TabuColors.rosaPrincipal, TabuColors.rosaClaro,
                TabuColors.rosaPrincipal, TabuColors.rosaDeep, Colors.transparent,
              ])))),
        SafeArea(
          child: Column(children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _ChatsTab(myUid: _myUid),
                  _RequestsTab(myUid: _myUid),
                ],
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: TabuColors.bg,
        border: Border(bottom: BorderSide(
            color: TabuColors.border.withOpacity(0.3), width: 0.5))),
      child: Row(children: [
        Container(width: 1, height: 14, color: TabuColors.rosaPrincipal),
        const SizedBox(width: 10),
        const Text('MENSAGENS', style: TextStyle(
            fontFamily: TabuTypography.bodyFont, fontSize: 12,
            fontWeight: FontWeight.w700, letterSpacing: 4,
            color: TabuColors.branco)),
        const Spacer(),
        _UnreadBadgeTotal(myUid: _myUid),
      ]),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: TabuColors.bg,
        border: Border(bottom: BorderSide(
            color: TabuColors.border.withOpacity(0.4), width: 0.5))),
      child: Row(children: [
        _TabBtn(
          label: 'CONVERSAS',
          isActive: _tabCtrl.index == 0,
          onTap: () => _goToTab(0),
        ),
        _TabBtn(
          label: 'SOLICITAÇÕES',
          isActive: _tabCtrl.index == 1,
          onTap: () => _goToTab(1),
          badgeStream: ChatRequestService().unseenCountStream(_myUid),
        ),
      ]),
    );
  }
}

// ── Badge total não lidos ──────────────────────────────────────────────────────
class _UnreadBadgeTotal extends StatelessWidget {
  final String myUid;
  const _UnreadBadgeTotal({required this.myUid});

  @override
  Widget build(BuildContext context) {
    if (myUid.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance
          .ref('Users/$myUid/unreadChatsCount')
          .onValue,
      builder: (_, snap) {
        final total = (snap.data?.snapshot.value as int?) ?? 0;
        if (total == 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: TabuColors.rosaPrincipal.withOpacity(0.15),
            border: Border.all(
                color: TabuColors.rosaPrincipal.withOpacity(0.4), width: 0.8)),
          child: Text('$total', style: const TextStyle(
              fontFamily: TabuTypography.bodyFont, fontSize: 10,
              fontWeight: FontWeight.w700, letterSpacing: 1,
              color: TabuColors.rosaPrincipal)));
      });
  }
}

// ── Tab Button ─────────────────────────────────────────────────────────────────
class _TabBtn extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Stream<int>? badgeStream;

  const _TabBtn({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.badgeStream,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(label, style: TextStyle(
                  fontFamily: TabuTypography.bodyFont, fontSize: 10,
                  fontWeight: FontWeight.w700, letterSpacing: 2.5,
                  color: isActive ? TabuColors.rosaPrincipal : TabuColors.subtle)),
              if (badgeStream != null)
                StreamBuilder<int>(
                  stream: badgeStream,
                  builder: (_, snap) {
                    final n = snap.data ?? 0;
                    if (n == 0) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(left: 7),
                      child: Container(
                        width: 16, height: 16,
                        decoration: BoxDecoration(
                          color: TabuColors.rosaPrincipal,
                          shape: BoxShape.circle,
                          border: Border.all(color: TabuColors.bg, width: 1.5)),
                        child: Center(child: Text('$n', style: const TextStyle(
                            fontFamily: TabuTypography.bodyFont, fontSize: 8,
                            fontWeight: FontWeight.w700, color: Colors.white)))));
                  }),
            ]),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 1.5, width: isActive ? 32 : 0,
              color: TabuColors.rosaPrincipal),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ABA: CONVERSAS
// ══════════════════════════════════════════════════════════════════════════════
class _ChatsTab extends StatelessWidget {
  final String myUid;
  const _ChatsTab({required this.myUid});

  void _openChat(BuildContext context, String otherUid) {
    HapticFeedback.selectionClick();
    Navigator.push(context, PageRouteBuilder(
      pageBuilder: (_, animation, __) => ChangeNotifierProvider(
        create: (_) => TabuChatController(),
        child: _OtherUserChatRoom(myUid: myUid, otherUid: otherUid)),
      transitionsBuilder: (_, animation, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child),
      transitionDuration: const Duration(milliseconds: 280),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: TabuChatService().chatIdsStream(myUid),
      builder: (context, idsSnap) {
        if (idsSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: SizedBox(width: 20, height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 1.5, color: TabuColors.rosaPrincipal)));
        }

        final chatIds = idsSnap.data ?? [];
        if (chatIds.isEmpty) return _buildEmpty();

        return _ChatTileList(
          chatIds: chatIds,
          myUid: myUid,
          onTap: (otherUid) => _openChat(context, otherUid),
        );
      });
  }

  Widget _buildEmpty() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 56, height: 56,
        decoration: BoxDecoration(
            border: Border.all(color: TabuColors.border, width: 0.8),
            color: TabuColors.bgCard),
        child: const Icon(Icons.chat_bubble_outline_rounded,
            color: TabuColors.border, size: 22)),
      const SizedBox(height: 16),
      const Text('NENHUMA CONVERSA AINDA', style: TextStyle(
          fontFamily: TabuTypography.bodyFont, fontSize: 9,
          fontWeight: FontWeight.w700, letterSpacing: 3.5, color: TabuColors.subtle)),
      const SizedBox(height: 6),
      const Text('Visite perfis e envie mensagens', style: TextStyle(
          fontFamily: TabuTypography.bodyFont, fontSize: 12,
          letterSpacing: 0.3, color: TabuColors.dim)),
    ]));
}

// Lista reativa ordenada por última mensagem
class _ChatTileList extends StatefulWidget {
  final List<String> chatIds;
  final String myUid;
  final Function(String otherUid) onTap;

  const _ChatTileList({
    required this.chatIds,
    required this.myUid,
    required this.onTap,
  });

  @override
  State<_ChatTileList> createState() => _ChatTileListState();
}

class _ChatTileListState extends State<_ChatTileList> {
  final Map<String, TabuChat> _chats = {};
  final Map<String, StreamSubscription> _subs = {};

  @override
  void initState() {
    super.initState();
    _subscribeAll(widget.chatIds);
  }

  @override
  void didUpdateWidget(_ChatTileList old) {
    super.didUpdateWidget(old);
    final removed = old.chatIds.toSet().difference(widget.chatIds.toSet());
    final added   = widget.chatIds.toSet().difference(old.chatIds.toSet());
    for (final id in removed) { _subs[id]?.cancel(); _subs.remove(id); _chats.remove(id); }
    if (added.isNotEmpty) _subscribeAll(added.toList());
  }

  void _subscribeAll(List<String> ids) {
    for (final id in ids) {
      if (_subs.containsKey(id)) continue;
      _subs[id] = TabuChatService().singleChatStream(id).listen((chat) {
        if (chat != null && mounted) {
          setState(() => _chats[id] = chat);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final sub in _subs.values) sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _chats.values.toList()
      ..sort((a, b) => b.metadata.lastTimestamp.compareTo(a.metadata.lastTimestamp));

    if (sorted.isEmpty) {
      return const Center(child: SizedBox(width: 20, height: 20,
        child: CircularProgressIndicator(
            strokeWidth: 1.5, color: TabuColors.rosaPrincipal)));
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: sorted.length,
      itemBuilder: (ctx, i) {
        final chat = sorted[i];
        return _ChatTile(
          key: ValueKey(chat.chatId),
          chat: chat,
          myUid: widget.myUid,
          onTap: () => widget.onTap(chat.otherUserId(widget.myUid)),
        );
      });
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ABA: SOLICITAÇÕES
// ══════════════════════════════════════════════════════════════════════════════
class _RequestsTab extends StatelessWidget {
  final String myUid;
  const _RequestsTab({required this.myUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ChatRequest>>(
      stream: ChatRequestService().pendingRequestsStream(myUid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: SizedBox(width: 20, height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 1.5, color: TabuColors.rosaPrincipal)));
        }
        final requests = snap.data ?? [];
        if (requests.isEmpty) return _buildEmpty();
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: requests.length,
          itemBuilder: (ctx, i) => _RequestCard(
            key: ValueKey(requests[i].id),
            request: requests[i], myUid: myUid));
      });
  }

  Widget _buildEmpty() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 56, height: 56,
        decoration: BoxDecoration(
            border: Border.all(color: TabuColors.border, width: 0.8),
            color: TabuColors.bgCard),
        child: const Icon(Icons.mark_chat_unread_outlined,
            color: TabuColors.border, size: 22)),
      const SizedBox(height: 16),
      const Text('SEM SOLICITAÇÕES', style: TextStyle(
          fontFamily: TabuTypography.bodyFont, fontSize: 9,
          fontWeight: FontWeight.w700, letterSpacing: 3.5, color: TabuColors.subtle)),
      const SizedBox(height: 6),
      const Text('Quando alguém quiser conversar,\naparece aqui',
          textAlign: TextAlign.center, style: TextStyle(
              fontFamily: TabuTypography.bodyFont, fontSize: 12,
              letterSpacing: 0.3, color: TabuColors.dim)),
    ]));
}

// ══════════════════════════════════════════════════════════════════════════════
//  CARD DE SOLICITAÇÃO
// ══════════════════════════════════════════════════════════════════════════════
class _RequestCard extends StatefulWidget {
  final ChatRequest request; final String myUid;
  const _RequestCard({super.key, required this.request, required this.myUid});
  @override State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  bool _loadingAccept = false, _loadingDecline = false, _done = false;

  Future<void> _accept() async {
    setState(() => _loadingAccept = true);
    HapticFeedback.mediumImpact();
    await ChatRequestService().acceptRequest(widget.request.id, widget.myUid);
    if (!mounted) return;
    setState(() { _loadingAccept = false; _done = true; });
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    Navigator.push(context, PageRouteBuilder(
      pageBuilder: (_, animation, __) => ChangeNotifierProvider(
        create: (_) => TabuChatController(),
        child: _OtherUserChatRoom(
            myUid: widget.myUid, otherUid: widget.request.fromUid)),
      transitionsBuilder: (_, animation, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child),
      transitionDuration: const Duration(milliseconds: 280),
    ));
  }

  Future<void> _decline() async {
    setState(() => _loadingDecline = true);
    HapticFeedback.selectionClick();
    await ChatRequestService().declineRequest(widget.request.id, widget.myUid);
    if (mounted) setState(() { _loadingDecline = false; _done = true; });
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return const SizedBox.shrink();
    final req   = widget.request;
    final isNew = !req.seen;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: TabuColors.bgCard,
          border: Border.all(
            color: isNew
                ? TabuColors.rosaPrincipal.withOpacity(0.35)
                : TabuColors.border.withOpacity(0.6),
            width: isNew ? 0.9 : 0.6),
          boxShadow: isNew ? [BoxShadow(
              color: TabuColors.glow.withOpacity(0.08),
              blurRadius: 16, offset: const Offset(0, 4))] : null),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          if (isNew) Container(
            width: double.infinity, height: 2,
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [
              TabuColors.rosaDeep, TabuColors.rosaPrincipal,
              TabuColors.rosaClaro, TabuColors.rosaPrincipal, TabuColors.rosaDeep]))),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(children: [
              Stack(children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isNew
                          ? TabuColors.rosaPrincipal.withOpacity(0.4)
                          : TabuColors.border,
                      width: isNew ? 1.2 : 0.6)),
                  child: req.fromAvatar.isNotEmpty
                      ? Image.network(req.fromAvatar, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _avatarFallback(req.fromName))
                      : _avatarFallback(req.fromName)),
                if (isNew) Positioned(top: 0, right: 0,
                  child: Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: TabuColors.rosaPrincipal, shape: BoxShape.circle,
                      border: Border.all(color: TabuColors.bgCard, width: 1.5),
                      boxShadow: [BoxShadow(
                          color: TabuColors.glow.withOpacity(0.5), blurRadius: 6)]))),
              ]),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(req.fromName.toUpperCase(),
                        style: TextStyle(fontFamily: TabuTypography.bodyFont,
                            fontSize: 13, fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            color: isNew ? TabuColors.branco : TabuColors.dim),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                    if (isNew) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: TabuColors.rosaPrincipal.withOpacity(0.12),
                          border: Border.all(
                              color: TabuColors.rosaPrincipal.withOpacity(0.4), width: 0.7)),
                        child: const Text('NOVA', style: TextStyle(
                            fontFamily: TabuTypography.bodyFont, fontSize: 7,
                            fontWeight: FontWeight.w700, letterSpacing: 2,
                            color: TabuColors.rosaPrincipal))),
                    ],
                  ]),
                  const SizedBox(height: 5),
                  Row(children: [
                    const Icon(Icons.mark_chat_unread_outlined,
                        size: 10, color: TabuColors.subtle),
                    const SizedBox(width: 5),
                    const Text('quer conversar com você', style: TextStyle(
                        fontFamily: TabuTypography.bodyFont, fontSize: 11,
                        letterSpacing: 0.2, color: TabuColors.subtle)),
                  ]),
                  const SizedBox(height: 4),
                  Text(_formatTime(req.createdAt), style: const TextStyle(
                      fontFamily: TabuTypography.bodyFont, fontSize: 9,
                      letterSpacing: 0.5, color: TabuColors.border)),
                ])),
            ])),

          Container(height: 0.5, decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent, TabuColors.border, Colors.transparent]))),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(children: [
              Expanded(child: GestureDetector(
                onTap: _loadingDecline || _loadingAccept ? null : _decline,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: TabuColors.bgCard,
                    border: Border.all(
                        color: TabuColors.border.withOpacity(0.6), width: 0.7)),
                  child: Center(child: _loadingDecline
                      ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5, color: TabuColors.subtle))
                      : const Text('RECUSAR', style: TextStyle(
                          fontFamily: TabuTypography.bodyFont, fontSize: 10,
                          fontWeight: FontWeight.w700, letterSpacing: 2.5,
                          color: TabuColors.subtle)))))),
              const SizedBox(width: 10),
              Expanded(child: GestureDetector(
                onTap: _loadingAccept || _loadingDecline ? null : _accept,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [TabuColors.rosaDeep, TabuColors.rosaPrincipal],
                      begin: Alignment.centerLeft, end: Alignment.centerRight),
                    border: Border.all(
                        color: TabuColors.rosaPrincipal.withOpacity(0.3), width: 0.7),
                    boxShadow: [BoxShadow(
                        color: TabuColors.glow.withOpacity(0.25),
                        blurRadius: 12, offset: const Offset(0, 3))]),
                  child: Center(child: _loadingAccept
                      ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5, color: Colors.white))
                      : const Text('ACEITAR', style: TextStyle(
                          fontFamily: TabuTypography.bodyFont, fontSize: 10,
                          fontWeight: FontWeight.w700, letterSpacing: 2.5,
                          color: TabuColors.branco)))))),
            ])),
        ]),
      ),
    );
  }

  Widget _avatarFallback(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(color: TabuColors.bgAlt,
      child: Center(child: Text(initial, style: const TextStyle(
          fontFamily: TabuTypography.displayFont, fontSize: 20,
          color: TabuColors.rosaPrincipal))));
  }

  String _formatTime(int ts) {
    final diff    = DateTime.now().millisecondsSinceEpoch - ts;
    final minutes = diff ~/ 60000;
    if (minutes < 1)  return 'agora';
    if (minutes < 60) return 'há ${minutes}min';
    final hours = minutes ~/ 60;
    if (hours < 24)   return 'há ${hours}h';
    return 'há ${hours ~/ 24}d';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  CHAT TILE
// ══════════════════════════════════════════════════════════════════════════════
class _ChatTile extends StatelessWidget {
  final TabuChat chat;
  final String myUid;
  final VoidCallback onTap;

  const _ChatTile({
    super.key,
    required this.chat,
    required this.myUid,
    required this.onTap,
  });

  String _formatTime(int ts) {
    if (ts == 0) return '';
    final dt   = DateTime.fromMillisecondsSinceEpoch(ts);
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0)
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (diff.inDays == 1) return 'ONTEM';
    if (diff.inDays < 7) {
      const d = ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB'];
      return d[dt.weekday % 7];
    }
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final otherUid    = chat.otherUserId(myUid);
    final unread      = chat.myUnreadCount(myUid);
    final iLastSender = chat.metadata.lastSender == myUid;

    return Column(children: [
      StreamBuilder<bool>(
        stream: TabuChatService().userOnlineStream(otherUid),
        initialData: false,
        builder: (context, onlineSnap) {
          final isOnline = onlineSnap.data ?? false;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              splashColor: TabuColors.rosaPrincipal.withOpacity(0.05),
              highlightColor: TabuColors.bgCard.withOpacity(0.5),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  Stack(children: [
                    CachedAvatar(uid: otherUid, name: otherUid, size: 50, radius: 8),
                    if (isOnline)
                      Positioned(
                        right: 0, bottom: 0,
                        child: Container(
                          width: 13, height: 13,
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E),
                            shape: BoxShape.circle,
                            border: Border.all(color: TabuColors.bg, width: 2),
                            boxShadow: [BoxShadow(
                                color: const Color(0xFF22C55E).withOpacity(0.5),
                                blurRadius: 8, spreadRadius: 1)]),
                        )),
                    if (!isOnline)
                      Positioned(
                        right: 0, bottom: 0,
                        child: Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(
                            color: TabuColors.bgCard,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: TabuColors.border.withOpacity(0.5), width: 1.5)),
                        )),
                  ]),

                  const SizedBox(width: 14),

                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _OtherUserName(uid: otherUid, bold: unread > 0),
                            const SizedBox(height: 2),
                            isOnline
                                ? const Text('online agora',
                                    style: TextStyle(
                                      fontFamily: TabuTypography.bodyFont,
                                      fontSize: 9, letterSpacing: 0.5,
                                      color: Color(0xFF22C55E)))
                                : _LastSeenText(uid: otherUid),
                          ],
                        )),
                        const SizedBox(width: 8),
                        Text(_formatTime(chat.metadata.lastTimestamp),
                            style: TextStyle(
                              fontFamily: TabuTypography.bodyFont,
                              fontSize: 9, letterSpacing: 1,
                              color: unread > 0
                                  ? TabuColors.rosaPrincipal : TabuColors.subtle)),
                      ]),
                      const SizedBox(height: 6),
                      Row(children: [
                        if (iLastSender && chat.metadata.lastMessage.isNotEmpty)
                          Padding(padding: const EdgeInsets.only(right: 5),
                            child: StreamBuilder<int>(
                              stream: TabuChatService().unreadStream(
                                  chat.chatId, otherUid),
                              initialData: 0,
                              builder: (_, snap) {
                                final recipientRead = (snap.data ?? 0) == 0;
                                return Icon(
                                  recipientRead
                                      ? Icons.done_all_rounded
                                      : Icons.done_rounded,
                                  size: 13,
                                  color: recipientRead
                                      ? const Color(0xFF60A5FA)
                                      : TabuColors.subtle);
                              })),

                        Expanded(child: Text(
                          chat.metadata.lastMessage.isEmpty
                              ? 'Chat ainda não aberto'
                              : chat.metadata.lastMessage,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: TabuTypography.bodyFont,
                            fontSize: 12, letterSpacing: 0.2,
                            color: chat.metadata.lastMessage.isEmpty
                                ? TabuColors.border
                                : unread > 0
                                    ? TabuColors.dim : TabuColors.subtle,
                            fontWeight: unread > 0
                                ? FontWeight.w600 : FontWeight.normal,
                            fontStyle: chat.metadata.lastMessage.isEmpty
                                ? FontStyle.italic : FontStyle.normal))),

                        if (unread > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: TabuColors.rosaPrincipal.withOpacity(0.15),
                              border: Border.all(
                                  color: TabuColors.rosaPrincipal.withOpacity(0.4),
                                  width: 0.8)),
                            child: Text(unread > 99 ? '99+' : '$unread',
                                style: const TextStyle(
                                  fontFamily: TabuTypography.bodyFont,
                                  fontSize: 10, fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                  color: TabuColors.rosaPrincipal))),
                        ],
                      ]),
                    ])),
                ]),
              ),
            ),
          );
        }),

      Padding(padding: const EdgeInsets.only(left: 80),
        child: Container(height: 0.5, decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [TabuColors.border, Colors.transparent])))),
    ]);
  }
}

// ── Último visto ──────────────────────────────────────────────────────────────
class _LastSeenText extends StatelessWidget {
  final String uid;
  const _LastSeenText({required this.uid});

  String _format(int lastSeenMs) {
    if (lastSeenMs == 0) return 'offline';
    final diff    = DateTime.now().millisecondsSinceEpoch - lastSeenMs;
    final minutes = diff ~/ 60000;
    if (minutes < 2)  return 'visto agora';
    if (minutes < 60) return 'visto há ${minutes}min';
    final hours = minutes ~/ 60;
    if (hours < 24)   return 'visto há ${hours}h';
    return 'visto há ${hours ~/ 24}d';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: TabuChatService().userLastSeenStream(uid),
      initialData: 0,
      builder: (_, snap) => Text(
        _format(snap.data ?? 0),
        style: TextStyle(
          fontFamily: TabuTypography.bodyFont,
          fontSize: 9, letterSpacing: 0.5,
          color: TabuColors.subtle.withOpacity(0.7)),
      ));
  }
}

// ── Nome via stream ───────────────────────────────────────────────────────────
class _OtherUserName extends StatelessWidget {
  final String uid; final bool bold;
  const _OtherUserName({required this.uid, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('Users/$uid/name').onValue,
      builder: (_, snap) {
        final name = snap.data?.snapshot.value as String? ?? '...';
        return Text(name.toUpperCase(),
          style: TextStyle(
              fontFamily: TabuTypography.bodyFont, fontSize: 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 1.5, color: TabuColors.branco),
          maxLines: 1, overflow: TextOverflow.ellipsis);
      });
  }
}

// ── Helper: carrega dados do outro usuário e abre ChatRoomScreen ──────────────
class _OtherUserChatRoom extends StatelessWidget {
  final String myUid, otherUid;
  const _OtherUserChatRoom({required this.myUid, required this.otherUid});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DatabaseEvent>(
      future: FirebaseDatabase.instance.ref('Users/$otherUid').once(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(backgroundColor: TabuColors.bg,
            body: Center(child: SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 1.5, color: TabuColors.rosaPrincipal))));
        }
        final data   = snap.data!.snapshot.value as Map<dynamic, dynamic>?;
        final name   = data?['name']   as String? ?? 'Usuário';
        final avatar = data?['avatar'] as String?;
        return ChatRoomScreen(
            myUid: myUid, otherUid: otherUid,
            otherName: name, otherAvatar: avatar);
      });
  }
}