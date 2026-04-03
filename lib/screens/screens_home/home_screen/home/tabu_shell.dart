// lib/widgets/main_navigation.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/services/services_app/user_data_notifier.dart';
import 'package:tabuapp/services/services_app/user_avatar_service.dart';

// ── Telas compartilhadas ───────────────────────────────────────────────────
import 'package:tabuapp/screens/screens_home/home_screen/home/home_screen.dart' show HomeScreen;
import 'package:tabuapp/screens/screens_home/search_screen/search/search_screen.dart';
import 'package:tabuapp/screens/screens_administrative/chat_screen/chat_list_screen.dart';
import 'package:tabuapp/screens/screens_home/perfil_screen/perfil/perfil_screen.dart';

// ── Tela exclusiva do admin ────────────────────────────────────────────────
import 'package:tabuapp/screens/screens_administrative/home_screen/home_screen.dart' show HomeScreenAdministrative;

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

class _TabuShellState extends State<TabuShell> {
  int _currentIndex = 0;

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    UserDataNotifier.instance.init(widget.userData);
    final uid = widget.userData['uid'] as String?
             ?? widget.userData['id']  as String? ?? '';
    if (uid.isNotEmpty) UserAvatarService.instance.invalidate(uid);

    // Admin:   Feed | Festas          | Search | Chat | Perfil
    // Usuário: Feed | Search          | Chat   | Perfil
    if (widget.isAdmin) {
      _screens = [
        HomeScreen(userData: widget.userData, isAdmin: true),
        HomeScreenAdministrative(userData: widget.userData),
        const SearchScreenPaginated(),
        const ChatListScreen(),
        PerfilScreen(userData: widget.userData),
      ];
    } else {
      _screens = [
        HomeScreen(userData: widget.userData, isAdmin: false),
        const SearchScreenPaginated(),
        const ChatListScreen(),
        PerfilScreen(userData: widget.userData),
      ];
    }
  }

  void _onTabTapped(int index) {
    HapticFeedback.lightImpact();
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
        isAdmin:      widget.isAdmin,
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
    required this.isAdmin,
    required this.myUid,
    required this.onTap,
  });

  final int    currentIndex;
  final bool   isAdmin;
  final String myUid;
  final ValueChanged<int> onTap;

  // Itens do admin: Feed | Festas | Search | Chat | Perfil
  static const _adminItems = [
    _NavItem(icon: Icons.home_outlined,                   activeIcon: Icons.home,                  label: 'FEED'),
    _NavItem(icon: Icons.local_fire_department_outlined,  activeIcon: Icons.local_fire_department,  label: 'FESTAS'),
    _NavItem(icon: Icons.search,                          activeIcon: Icons.search,                 label: 'SEARCH'),
    _NavItem(icon: Icons.chat_bubble_outline,             activeIcon: Icons.chat_bubble,            label: 'CHAT'),
    _NavItem(icon: Icons.person_outline,                  activeIcon: Icons.person,                 label: 'PERFIL'),
  ];

  // Itens do usuário normal: Feed | Search | Chat | Perfil
  static const _userItems = [
    _NavItem(icon: Icons.home_outlined,       activeIcon: Icons.home,        label: 'FEED'),
    _NavItem(icon: Icons.search,              activeIcon: Icons.search,      label: 'SEARCH'),
    _NavItem(icon: Icons.chat_bubble_outline, activeIcon: Icons.chat_bubble, label: 'CHAT'),
    _NavItem(icon: Icons.person_outline,      activeIcon: Icons.person,      label: 'PERFIL'),
  ];

  // Índice do ícone de chat em cada lista
  int get _chatIndex => isAdmin ? 3 : 2;

  Stream<int> _chatBadgeStream() {
    if (myUid.isEmpty) return const Stream.empty();
    return FirebaseDatabase.instance
        .ref('Users/$myUid/unreadChatsCount')
        .onValue
        .map((e) => (e.snapshot.value as int?) ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final items = isAdmin ? _adminItems : _userItems;

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
            children: List.generate(items.length, (i) {
              // Badge de chat via stream
              if (i == _chatIndex) {
                return Expanded(
                  child: StreamBuilder<int>(
                    stream: _chatBadgeStream(),
                    initialData: 0,
                    builder: (_, snap) => _NavButton(
                      item:     items[i],
                      isActive: i == currentIndex,
                      badge:    snap.data ?? 0,
                      onTap:    () => onTap(i),
                    ),
                  ),
                );
              }

              return Expanded(
                child: _NavButton(
                  item:     items[i],
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
//  NAV BUTTON
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
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  decoration: BoxDecoration(
                    color:  TabuColors.rosaPrincipal,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: TabuColors.bg, width: 1.5),
                  ),
                  child: Text(
                    badge > 99 ? '99+' : '$badge',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily:  TabuTypography.bodyFont,
                      fontSize:    9,
                      fontWeight:  FontWeight.w700,
                      color:       TabuColors.branco,
                      height:      1.4,
                    ),
                  ),
                ),
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