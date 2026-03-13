import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/screens/screens_home/home_screen/home_screen.dart';

// ─── Placeholders — substitua pelas suas telas reais ───────────────────────
// import 'package:tabuapp/screens/screens_home/festa_screen/festa_screen.dart';
// import 'package:tabuapp/screens/screens_home/chat_screen/chat_screen.dart';
// import 'package:tabuapp/screens/screens_home/perfil_screen/perfil_screen.dart';
// ───────────────────────────────────────────────────────────────────────────

class TabuShell extends StatefulWidget {
  final Map<String, dynamic> userData;
  const TabuShell({super.key, required this.userData});

  @override
  State<TabuShell> createState() => _TabuShellState();
}

class _TabuShellState extends State<TabuShell> {
  int _currentIndex = 0;
  int _chatBadge = 4; // substitua por valor real do backend

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(userData: widget.userData),   // Feed
      const _FestaPlaceholder(),               // Festas  ← troque pelo import real
      const _ChatPlaceholder(),                // Chat    ← troque pelo import real
      const _PerfilPlaceholder(),              // Perfil  ← troque pelo import real
    ];
  }

  void _onTabTapped(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      _currentIndex = index;
      if (index == 2) _chatBadge = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TabuColors.bg,
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _TabuNavBar(
        currentIndex: _currentIndex,
        chatBadge: _chatBadge,
        onTap: _onTabTapped,
      ),
    );
  }
}

// ════════════════════════════════════════════
//  BOTTOM NAV BAR
// ════════════════════════════════════════════
class _TabuNavBar extends StatelessWidget {
  const _TabuNavBar({
    required this.currentIndex,
    required this.chatBadge,
    required this.onTap,
  });

  final int currentIndex;
  final int chatBadge;
  final ValueChanged<int> onTap;

  static const _items = [
    _NavItem(icon: Icons.home_outlined,                  activeIcon: Icons.home,                 label: 'FEED'),
    _NavItem(icon: Icons.local_fire_department_outlined, activeIcon: Icons.local_fire_department, label: 'FESTAS'),
    _NavItem(icon: Icons.chat_bubble_outline,            activeIcon: Icons.chat_bubble,           label: 'CHAT'),
    _NavItem(icon: Icons.person_outline,                 activeIcon: Icons.person,                label: 'PERFIL'),
  ];

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
              return Expanded(
                child: _NavButton(
                  item: _items[i],
                  isActive: i == currentIndex,
                  badge: (i == 2 && chatBadge > 0) ? chatBadge : 0,
                  onTap: () => onTap(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.isActive,
    required this.badge,
    required this.onTap,
  });

  final _NavItem item;
  final bool isActive;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Ícone + badge
          Stack(
            clipBehavior: Clip.none,
            children: [
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
                      color: TabuColors.rosaPrincipal,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: TabuColors.bg, width: 1.5),
                    ),
                    child: Text(
                      '$badge',
                      style: const TextStyle(
                        fontFamily: TabuTypography.bodyFont,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: TabuColors.branco,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 4),

          // Label
          Text(
            item.label,
            style: TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: isActive ? TabuColors.rosaPrincipal : TabuColors.subtle,
            ),
          ),

          const SizedBox(height: 2),

          // Indicador ativo animado
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            height: 2,
            width: isActive ? 24 : 0,
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

// ════════════════════════════════════════════
//  PLACEHOLDERS (remova ao criar as telas)
// ════════════════════════════════════════════
class _FestaPlaceholder extends StatelessWidget {
  const _FestaPlaceholder();
  @override
  Widget build(BuildContext context) => _PlaceholderScreen(label: 'FESTAS', icon: Icons.local_fire_department);
}

class _ChatPlaceholder extends StatelessWidget {
  const _ChatPlaceholder();
  @override
  Widget build(BuildContext context) => _PlaceholderScreen(label: 'CHAT', icon: Icons.chat_bubble_outline);
}

class _PerfilPlaceholder extends StatelessWidget {
  const _PerfilPlaceholder();
  @override
  Widget build(BuildContext context) => _PlaceholderScreen(label: 'PERFIL', icon: Icons.person_outline);
}

class _PlaceholderScreen extends StatelessWidget {
  final String label;
  final IconData icon;
  const _PlaceholderScreen({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TabuColors.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: TabuColors.border, size: 40),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontFamily: TabuTypography.displayFont,
                fontSize: 24,
                letterSpacing: 6,
                color: TabuColors.border,
              ),
            ),
          ],
        ),
      ),
    );
  }
}