// lib/widgets/main_navigation.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:rxdart/rxdart.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/services/services_app/chat_request_service.dart';
import 'package:tabuapp/services/services_app/user_data_notifier.dart';
import 'package:tabuapp/services/services_app/user_avatar_service.dart';

// ── Telas compartilhadas ───────────────────────────────────────────────────
import 'package:tabuapp/screens/screens_home/home_screen/home/home_screen.dart'
    show HomeScreen;
import 'package:tabuapp/screens/screens_home/search_screen/search/search_screen.dart';
import 'package:tabuapp/screens/screens_administrative/chat_screen/chat_list_screen.dart';
import 'package:tabuapp/screens/screens_home/perfil_screen/perfil/perfil_screen.dart';

class TabuShell extends StatefulWidget {
  final Map<String, dynamic> userData;
  final bool isAdmin;

  const TabuShell({
    super.key,
    required this.userData,
    this.isAdmin = false,
  });

  @override
  State<TabuShell> createState() => _TabuShellState();
}

class _TabuShellState extends State<TabuShell> with WidgetsBindingObserver {
  int _currentIndex = 0;

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  late final List<Widget> _screens;

  final _db = FirebaseDatabase.instance;

  Future<void> _setOnline() async {
    if (_myUid.isEmpty) return;
    final ref = _db.ref('Users/$_myUid/presence');
    await ref.onDisconnect().update({
      'online':    false,
      'last_seen': ServerValue.timestamp,
    });
    await ref.update({
      'online':    true,
      'last_seen': ServerValue.timestamp,
    });
  }

  Future<void> _setOffline() async {
    if (_myUid.isEmpty) return;
    await _db.ref('Users/$_myUid/presence').onDisconnect().cancel();
    await _db.ref('Users/$_myUid/presence').update({
      'online':    false,
      'last_seen': ServerValue.timestamp,
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _setOnline();
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _setOffline();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    UserDataNotifier.instance.init(widget.userData);
    final uid = widget.userData['uid'] as String?
             ?? widget.userData['id']  as String? ?? '';
    if (uid.isNotEmpty) UserAvatarService.instance.invalidate(uid);

    _setOnline();

    _screens = [
      HomeScreen(userData: widget.userData, isAdmin: widget.isAdmin),
      const SearchScreenPaginated(),
      const ChatListScreen(),
      PerfilScreen(userData: widget.userData),
    ];
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setOffline();
    super.dispose();
  }

  void _onTabTapped(int index) {
    HapticFeedback.lightImpact();
    // Ao abrir a aba de chat, zera o badge de solicitações imediatamente
    if (index == 2 && _myUid.isNotEmpty) {
      ChatRequestService().markAllAsSeen(_myUid);
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TabuColors.bg,
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: _TabuNavBar(
        currentIndex: _currentIndex,
        myUid:        _myUid,
        onTap:        _onTabTapped,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  BOTTOM NAV BAR
// ════════════════════════════════════════════════════════════════════════════
class _TabuNavBar extends StatelessWidget {
  const _TabuNavBar({
    required this.currentIndex,
    required this.myUid,
    required this.onTap,
  });

  final int    currentIndex;
  final String myUid;
  final ValueChanged<int> onTap;

  static const _items = [
    _NavItem(icon: Icons.home_outlined,       activeIcon: Icons.home,        label: 'FEED'),
    _NavItem(icon: Icons.search,              activeIcon: Icons.search,      label: 'SEARCH'),
    _NavItem(icon: Icons.chat_bubble_outline, activeIcon: Icons.chat_bubble, label: 'CHAT'),
    _NavItem(icon: Icons.person_outline,      activeIcon: Icons.person,      label: 'PERFIL'),
  ];

  /// Stream de mensagens não lidas (unreadChatsCount no nó do usuário)
  Stream<int> _unreadMsgsStream() {
    if (myUid.isEmpty) return Stream.value(0);
    return FirebaseDatabase.instance
        .ref('Users/$myUid/unreadChatsCount')
        .onValue
        .map((e) => (e.snapshot.value as int?) ?? 0);
  }

  /// Stream de solicitações pendentes não vistas
  Stream<int> _pendingRequestsStream() {
    if (myUid.isEmpty) return Stream.value(0);
    return ChatRequestService().unseenCountStream(myUid);
  }

  /// Stream combinado: {msgs, requests}
  Stream<_ChatBadgeData> _chatBadgeStream() {
    return Rx.combineLatest2(
      _unreadMsgsStream(),
      _pendingRequestsStream(),
      (int msgs, int reqs) => _ChatBadgeData(msgs: msgs, requests: reqs),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: TabuColors.nav,
        border: Border(top: BorderSide(color: TabuColors.borderMid, width: 0.8)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(_items.length, (i) {
              if (i == 2) {
                // Aba de chat: badge combinado
                return Expanded(
                  child: StreamBuilder<_ChatBadgeData>(
                    stream: _chatBadgeStream(),
                    initialData: const _ChatBadgeData(msgs: 0, requests: 0),
                    builder: (_, snap) {
                      final data = snap.data ?? const _ChatBadgeData(msgs: 0, requests: 0);
                      return _ChatNavButton(
                        item:     _items[i],
                        isActive: i == currentIndex,
                        msgs:     data.msgs,
                        requests: data.requests,
                        onTap:    () => onTap(i),
                      );
                    },
                  ),
                );
              }
              return Expanded(
                child: _NavButton(
                  item:     _items[i],
                  isActive: i == currentIndex,
                  badge:    0,
                  onTap:    () => onTap(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ── Dado agregado do badge ────────────────────────────────────────────────────
class _ChatBadgeData {
  final int msgs;
  final int requests;
  const _ChatBadgeData({required this.msgs, required this.requests});
}

// ════════════════════════════════════════════════════════════════════════════
//  BOTÃO DE CHAT COM BADGE DUPLO
// ════════════════════════════════════════════════════════════════════════════
class _ChatNavButton extends StatelessWidget {
  const _ChatNavButton({
    required this.item,
    required this.isActive,
    required this.msgs,
    required this.requests,
    required this.onTap,
  });

  final _NavItem     item;
  final bool         isActive;
  final int          msgs;
  final int          requests;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasMsg = msgs > 0;
    final hasReq = requests > 0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ── Badge row acima do ícone ────────────────────────────
          SizedBox(
            height: 14,
            child: (hasMsg || hasReq)
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 3,
                    children: [
                      if (hasMsg)
                        _BadgePill(
                          count: msgs,
                          color: const Color(0xFFE85D5D),
                        ),
                      if (hasReq)
                        _BadgePill(
                          count: requests,
                          color: TabuColors.rosaPrincipal,
                          icon: Icons.person_add_rounded,
                        ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),

          const SizedBox(height: 2),

          // ── Ícone (sem Stack, sem Positioned) ──────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              isActive ? item.activeIcon : item.icon,
              key: ValueKey(isActive),
              color: isActive ? TabuColors.rosaPrincipal : TabuColors.subtle,
              size: 24,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            item.label,
            style: TextStyle(
              fontFamily:    TabuTypography.bodyFont,
              fontSize:      10,
              fontWeight:    FontWeight.w700,
              letterSpacing: 2,
              color: isActive ? TabuColors.rosaPrincipal : TabuColors.subtle,
            ),
          ),

          const SizedBox(height: 2),

          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            height: 2,
            width:  isActive ? 24 : 0,
            decoration: BoxDecoration(
              color: TabuColors.rosaPrincipal,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pílula de badge reutilizável ──────────────────────────────────────────────
class _BadgePill extends StatelessWidget {
  const _BadgePill({
    required this.count,
    required this.color,
    this.icon,
  });

  final int       count;
  final Color     color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: TabuColors.bg, width: 1.5),
      ),
      child: icon != null && count == 0
          // Mostra só o ícone quando count == 0 (nunca acontece, mas defensivo)
          ? Icon(icon, size: 9, color: Colors.white)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 8, color: Colors.white),
                  const SizedBox(width: 2),
                ],
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily:  TabuTypography.bodyFont,
                    fontSize:    8,
                    fontWeight:  FontWeight.w700,
                    color:       Colors.white,
                    height:      1.4,
                  ),
                ),
              ],
            ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  NAV ITEM MODEL
// ════════════════════════════════════════════════════════════════════════════
class _NavItem {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
  final IconData icon;
  final IconData activeIcon;
  final String   label;
}

// ════════════════════════════════════════════════════════════════════════════
//  NAV BUTTON (genérico, sem badge especial)
// ════════════════════════════════════════════════════════════════════════════
class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.isActive,
    required this.badge,
    required this.onTap,
  });

  final _NavItem     item;
  final bool         isActive;
  final int          badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(clipBehavior: Clip.none, children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isActive ? item.activeIcon : item.icon,
                key: ValueKey(isActive),
                color: isActive ? TabuColors.rosaPrincipal : TabuColors.subtle,
                size: 24,
              ),
            ),
            if (badge > 0)
              Positioned(
                top: -4, right: -6,
                child: _BadgePill(count: badge, color: const Color(0xFFE85D5D)),
              ),
          ]),

          const SizedBox(height: 4),

          Text(
            item.label,
            style: TextStyle(
              fontFamily:    TabuTypography.bodyFont,
              fontSize:      10,
              fontWeight:    FontWeight.w700,
              letterSpacing: 2,
              color: isActive ? TabuColors.rosaPrincipal : TabuColors.subtle,
            ),
          ),

          const SizedBox(height: 2),

          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            height: 2,
            width:  isActive ? 24 : 0,
            decoration: BoxDecoration(
              color: TabuColors.rosaPrincipal,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }
}
