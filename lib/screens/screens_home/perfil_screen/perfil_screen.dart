// lib/screens/screens_home/perfil_screen/perfil_screen.dart
import 'package:flutter/material.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/screens/screens_home/perfil_screen/edit_perfil.dart';
import 'package:tabuapp/services/services_app/auth_service.dart';


class PerfilScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const PerfilScreen({super.key, required this.userData});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Map<String, dynamic> _localUserData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _localUserData = Map<String, dynamic>.from(widget.userData);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── helpers ────────────────────────────────────────────────────────────────
  List<String> _parseList(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [];
  }

  Future<void> _openEdit() async {
    final updated = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => EditPerfilScreen(
          userData: _localUserData,
          onSaved: (data) => setState(() {
            // Spread: preserva partys, reservations, vip_lists, historical
            // e sobrescreve apenas name, bio, avatar
            _localUserData = {..._localUserData, ...data};
          }),
        ),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _localUserData = {..._localUserData, ...updated});
    }
  }

    @override
  Widget build(BuildContext context) {
    final String name      = (_localUserData['name']  as String? ?? 'Usuário').toUpperCase();
    final String email     =  _localUserData['email'] as String? ?? '';
    // Após edição salva como 'bio'. Cadastro original usa 'bio ' (com espaço).
    final String bio = ((_localUserData['bio'] as String?)
                     ?? (_localUserData['bio '] as String?)
                     ?? '').trim();
    final String avatarUrl =  _localUserData['avatar'] as String? ?? '';
    final int partys       = (_localUserData['partys']       as num? ?? 0).toInt();
    final int reservations = (_localUserData['reservations'] as num? ?? 0).toInt();
    final int vipLists     = (_localUserData['vip_lists']    as num? ?? 0).toInt();

    final Map<String, dynamic> historical = () {
      final raw = _localUserData['historical'];
      if (raw == null) return <String, dynamic>{};
      if (raw is Map<String, dynamic>) return raw;
      return Map<String, dynamic>.from(raw as Map);
    }();

    final List<String> histPartys       = _parseList(historical['partys']);
    final List<String> histReservations = _parseList(historical['reservations']);
    final List<String> histVipList      = _parseList(historical['vip_list']);

    return Scaffold(
      backgroundColor: TabuColors.bg,
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _PerfilBg())),

          // Linha neon no topo
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: 3,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [
                  TabuColors.rosaDeep,
                  TabuColors.rosaPrincipal,
                  TabuColors.rosaClaro,
                  TabuColors.rosaPrincipal,
                  TabuColors.rosaDeep,
                ]),
              ),
            ),
          ),

          SafeArea(
            child: NestedScrollView(
              headerSliverBuilder: (context, _) => [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 32),

                        // Avatar — toque abre edição
                        GestureDetector(
                          onTap: _openEdit,
                          child: _Avatar(avatarUrl: avatarUrl),
                        ),
                        const SizedBox(height: 16),

                        // Nome
                        Text(
                          name,
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontSize: 30,
                            letterSpacing: 6,
                            color: TabuColors.branco,
                            fontWeight: FontWeight.w400,
                            shadows: [Shadow(color: TabuColors.glow, blurRadius: 20)],
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Email
                        Text(
                          email,
                          style: const TextStyle(
                            fontFamily: TabuTypography.bodyFont,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.5,
                            color: TabuColors.dim,
                          ),
                        ),

                        if (bio.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            bio,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: TabuTypography.bodyFont,
                              fontSize: 13,
                              letterSpacing: 0.5,
                              color: TabuColors.dim,
                              height: 1.5,
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),
                        Container(height: 0.5, color: TabuColors.border),
                        const SizedBox(height: 20),

                        // Stats
                        Row(
                          children: [
                            _StatCard(value: '$partys',       label: 'FESTAS',     icon: Icons.local_fire_department_outlined),
                            const SizedBox(width: 10),
                            _StatCard(value: '$reservations', label: 'RESERVAS',   icon: Icons.table_restaurant_outlined),
                            const SizedBox(width: 10),
                            _StatCard(value: '$vipLists',     label: 'LISTAS VIP', icon: Icons.star_border_rounded, highlight: true),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Badge VIP
                        _VipBadge(vipLists: vipLists),

                        const SizedBox(height: 16),

                        // Botão editar perfil
                        GestureDetector(
                          onTap: _openEdit,
                          child: Container(
                            width: double.infinity,
                            height: 46,
                            decoration: BoxDecoration(
                              color: TabuColors.bgCard,
                              border: Border.all(color: TabuColors.borderMid, width: 0.8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.edit_outlined, color: TabuColors.rosaPrincipal, size: 15),
                                SizedBox(width: 10),
                                Text(
                                  'EDITAR PERFIL',
                                  style: TextStyle(
                                    fontFamily: TabuTypography.bodyFont,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 3,
                                    color: TabuColors.rosaPrincipal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),
                        Container(height: 0.5, color: TabuColors.border),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),

                // Tab bar fixa abaixo do header
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickyTabBar(controller: _tabController),
                ),
              ],
              body: TabBarView(
                controller: _tabController,
                children: [
                  // ── Festas ──────────────────────────────────────
                  _HistoryTab(
                    items: histPartys,
                    emptyLabel: 'Nenhuma festa registrada',
                    icon: Icons.local_fire_department_outlined,
                    itemIcon: Icons.local_fire_department,
                    accentColor: TabuColors.rosaPrincipal,
                  ),
                  // ── Reservas ────────────────────────────────────
                  _HistoryTab(
                    items: histReservations,
                    emptyLabel: 'Nenhuma reserva registrada',
                    icon: Icons.table_restaurant_outlined,
                    itemIcon: Icons.table_restaurant,
                    accentColor: TabuColors.rosaClaro,
                  ),
                  // ── Lista VIP ───────────────────────────────────
                  _HistoryTab(
                    items: histVipList,
                    emptyLabel: 'Nenhuma lista VIP registrada',
                    icon: Icons.star_border_rounded,
                    itemIcon: Icons.star_rounded,
                    accentColor: TabuColors.rosaPrincipal,
                    isVip: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      // Botão logout no rodapé
      bottomSheet: _BottomActions(),
    );
  }
}

// ════════════════════════════════════════════
//  STICKY TAB BAR DELEGATE
// ════════════════════════════════════════════
class _StickyTabBar extends SliverPersistentHeaderDelegate {
  final TabController controller;
  const _StickyTabBar({required this.controller});

  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: TabuColors.bg,
      child: TabBar(
        controller: controller,
        indicatorColor: TabuColors.rosaPrincipal,
        indicatorWeight: 2,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: TabuColors.rosaPrincipal,
        unselectedLabelColor: TabuColors.subtle,
        labelStyle: const TextStyle(
          fontFamily: TabuTypography.bodyFont,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.5,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: TabuTypography.bodyFont,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 2.5,
        ),
        dividerColor: TabuColors.border,
        tabs: const [
          Tab(text: 'FESTAS'),
          Tab(text: 'RESERVAS'),
          Tab(text: 'LISTA VIP'),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_StickyTabBar old) => false;
}

// ════════════════════════════════════════════
//  HISTORY TAB
// ════════════════════════════════════════════
class _HistoryTab extends StatelessWidget {
  final List<String> items;
  final String emptyLabel;
  final IconData icon;
  final IconData itemIcon;
  final Color accentColor;
  final bool isVip;

  const _HistoryTab({
    required this.items,
    required this.emptyLabel,
    required this.icon,
    required this.itemIcon,
    required this.accentColor,
    this.isVip = false,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: TabuColors.border, size: 36),
            const SizedBox(height: 12),
            Text(
              emptyLabel.toUpperCase(),
              style: const TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 11,
                letterSpacing: 2.5,
                color: TabuColors.subtle,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _HistoryTile(
        index: i + 1,
        name: items[i],
        itemIcon: itemIcon,
        accentColor: accentColor,
        isVip: isVip,
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final int index;
  final String name;
  final IconData itemIcon;
  final Color accentColor;
  final bool isVip;

  const _HistoryTile({
    required this.index,
    required this.name,
    required this.itemIcon,
    required this.accentColor,
    required this.isVip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: TabuColors.bgCard,
        border: Border.all(color: TabuColors.border, width: 0.8),
      ),
      child: Row(
        children: [
          // Número / índice
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              border: Border.all(color: accentColor.withOpacity(0.4), width: 0.8),
            ),
            child: Center(
              child: Text(
                '$index',
                style: TextStyle(
                  fontFamily: TabuTypography.displayFont,
                  fontSize: 13,
                  color: accentColor,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Ícone
          Icon(itemIcon, color: accentColor, size: 16),
          const SizedBox(width: 10),

          // Nome
          Expanded(
            child: Text(
              name.toUpperCase(),
              style: const TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
                color: TabuColors.branco,
              ),
            ),
          ),

          // Badge VIP se aplicável
          if (isVip)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: TabuColors.rosaPrincipal.withOpacity(0.15),
                border: Border.all(color: TabuColors.borderMid, width: 0.8),
              ),
              child: const Text(
                'VIP',
                style: TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: TabuColors.rosaPrincipal,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════
//  BOTTOM ACTIONS (logout)
// ════════════════════════════════════════════
class _BottomActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    return Container(
      decoration: const BoxDecoration(
        color: TabuColors.nav,
        border: Border(top: BorderSide(color: TabuColors.border, width: 0.5)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      child: GestureDetector(
        onTap: () async => await authService.signOut(),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: TabuColors.bgCard,
            border: Border.all(color: TabuColors.border, width: 0.8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.logout, color: TabuColors.subtle, size: 16),
              const SizedBox(width: 10),
              const Text(
                'SAIR',
                style: TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 5,
                  color: TabuColors.subtle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════
//  AVATAR
// ════════════════════════════════════════════
class _Avatar extends StatelessWidget {
  final String avatarUrl;
  const _Avatar({required this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 96, height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: TabuColors.glow, blurRadius: 28, spreadRadius: 4)],
            gradient: const LinearGradient(
              colors: [TabuColors.rosaDeep, TabuColors.rosaPrincipal],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Container(
          width: 90, height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: TabuColors.bg, width: 3),
          ),
          child: ClipOval(
            child: avatarUrl.isNotEmpty
                ? Image.network(
                    avatarUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: TabuColors.bgAlt,
                        child: const Center(
                          child: SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                              color: TabuColors.rosaPrincipal,
                              strokeWidth: 1.5,
                            ),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => Container(
                      color: TabuColors.bgAlt,
                      child: const Icon(Icons.person_outline, color: TabuColors.rosaPrincipal, size: 36),
                    ),
                  )
                : Container(
                    color: TabuColors.bgAlt,
                    child: const Icon(Icons.person_outline, color: TabuColors.rosaPrincipal, size: 36),
                  ),
          ),
        ),
        Positioned(
          bottom: 0, right: 0,
          child: Container(
            width: 26, height: 26,
            decoration: BoxDecoration(
              color: TabuColors.rosaPrincipal,
              shape: BoxShape.circle,
              border: Border.all(color: TabuColors.bg, width: 2),
            ),
            child: const Icon(Icons.photo_camera, color: TabuColors.branco, size: 12),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════
//  STAT CARD
// ════════════════════════════════════════════
class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final bool highlight;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: highlight
              ? TabuColors.rosaPrincipal.withOpacity(0.08)
              : TabuColors.bgCard,
          border: Border.all(
            color: highlight ? TabuColors.borderMid : TabuColors.border,
            width: highlight ? 1 : 0.8,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: highlight ? TabuColors.rosaPrincipal : TabuColors.dim, size: 18),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontFamily: TabuTypography.displayFont,
                fontSize: 26,
                letterSpacing: 1,
                color: highlight ? TabuColors.rosaPrincipal : TabuColors.branco,
                shadows: highlight ? [Shadow(color: TabuColors.glow, blurRadius: 10)] : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: highlight ? TabuColors.rosaPrincipal : TabuColors.subtle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════
//  VIP BADGE
// ════════════════════════════════════════════
class _VipBadge extends StatelessWidget {
  final int vipLists;
  const _VipBadge({required this.vipLists});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [TabuColors.rosaDeep, Color(0xFF2A0518)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border.all(color: TabuColors.borderMid, width: 0.8),
      ),
      child: Row(
        children: [
          const Icon(Icons.star_rounded, color: TabuColors.rosaPrincipal, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MEMBRO VIP',
                  style: TextStyle(
                    fontFamily: TabuTypography.displayFont,
                    fontSize: 14,
                    letterSpacing: 4,
                    color: TabuColors.branco,
                  ),
                ),
                Text(
                  '$vipLists listas confirmadas',
                  style: const TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 11,
                    letterSpacing: 1,
                    color: TabuColors.rosaClaro,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            color: TabuColors.rosaPrincipal,
            child: const Text(
              'ATIVO',
              style: TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: TabuColors.branco,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════
//  BACKGROUND PAINTER
// ════════════════════════════════════════════
class _PerfilBg extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = TabuColors.bg,
    );
    canvas.drawCircle(
      Offset(size.width * 0.15, size.height * 0.15),
      size.width * 0.7,
      Paint()
        ..shader = RadialGradient(
          colors: [TabuColors.rosaPrincipal.withOpacity(0.08), Colors.transparent],
        ).createShader(Rect.fromCircle(
          center: Offset(size.width * 0.15, size.height * 0.15),
          radius: size.width * 0.7,
        )),
    );
    canvas.drawCircle(
      Offset(size.width * 0.9, size.height * 0.85),
      size.width * 0.5,
      Paint()
        ..shader = RadialGradient(
          colors: [TabuColors.bgAlt.withOpacity(0.9), Colors.transparent],
        ).createShader(Rect.fromCircle(
          center: Offset(size.width * 0.9, size.height * 0.85),
          radius: size.width * 0.5,
        )),
    );
  }

  @override
  bool shouldRepaint(_PerfilBg old) => false;
}