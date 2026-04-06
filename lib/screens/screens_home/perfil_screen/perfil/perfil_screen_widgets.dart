// lib/screens/screens_home/perfil_screen/perfil/perfil_screen_widgets.dart
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/services/services_app/cached_avatar.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  PERFIL BACKGROUND
// ══════════════════════════════════════════════════════════════════════════════
class PerfilBg extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF0A0014),
          Color(0xFF1A0020),
          Color(0xFF0A0014),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Adicionar alguns efeitos de brilho sutil
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.8, -0.5),
        radius: 1.5,
        colors: [
          TabuColors.glow.withOpacity(0.03),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ══════════════════════════════════════════════════════════════════════════════
//  AVATAR
// ══════════════════════════════════════════════════════════════════════════════
class Avatar extends StatelessWidget {
  final String avatarUrl;
  final bool showCamera;

  const Avatar({
    super.key,
    required this.avatarUrl,
    this.showCamera = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 86,
          height: 86,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: TabuColors.bgCard,
            border: Border.all(color: TabuColors.border, width: 0.8),
          ),
          child: ClipOval(
            child: avatarUrl.isNotEmpty
                ? Image.network(
                    avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.person_outline,
                      color: TabuColors.subtle,
                      size: 36,
                    ),
                  )
                : const Icon(
                    Icons.person_outline,
                    color: TabuColors.subtle,
                    size: 36,
                  ),
          ),
        ),
        if (showCamera)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TabuColors.rosaPrincipal,
                border: Border.all(color: TabuColors.bg, width: 2),
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  STAT CARD
// ══════════════════════════════════════════════════════════════════════════════
class StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool highlight;

  const StatCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: highlight
                ? const Color(0xFFD4AF37).withOpacity(0.05)
                : TabuColors.bgCard,
            border: Border.all(
              color: highlight
                  ? const Color(0xFFD4AF37).withOpacity(0.3)
                  : TabuColors.border,
              width: 0.8,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: highlight
                    ? const Color(0xFFD4AF37)
                    : TabuColors.rosaPrincipal,
                size: 20,
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontFamily: TabuTypography.displayFont,
                  fontSize: 16,
                  letterSpacing: 2,
                  color:
                      highlight ? const Color(0xFFD4AF37) : TabuColors.branco,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: highlight
                      ? const Color(0xFFD4AF37).withOpacity(0.7)
                      : TabuColors.dim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  VIP FRIENDS BADGE
// ══════════════════════════════════════════════════════════════════════════════
class VipFriendsBadge extends StatelessWidget {
  final int count;

  const VipFriendsBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFD4AF37).withOpacity(0.1),
        border: Border.all(
          color: const Color(0xFFD4AF37).withOpacity(0.3),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.star_rounded,
            color: Color(0xFFD4AF37),
            size: 14,
          ),
          const SizedBox(width: 8),
          Text(
            '$count AMIGO${count == 1 ? '' : 'S'} VIP',
            style: const TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: Color(0xFFD4AF37),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  GALERIA SKELETON
// ══════════════════════════════════════════════════════════════════════════════
class GaleriaSkeleton extends StatelessWidget {
  const GaleriaSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 1.5,
          mainAxisSpacing: 1.5,
          childAspectRatio: 1.0,
          mainAxisExtent: 120.0,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, i) => Padding(
            padding: const EdgeInsets.all(0.75),
            child: Container(
              decoration: BoxDecoration(
                color: TabuColors.bgCard,
                border: Border.all(color: TabuColors.border, width: 0.8),
              ),
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: TabuColors.rosaPrincipal,
                    strokeWidth: 1.5,
                  ),
                ),
              ),
            ),
          ),
          childCount: 9,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  POST DETAIL SHEET
// ══════════════════════════════════════════════════════════════════════════════
class PostDetailSheet extends StatelessWidget {
  final dynamic post;
  final String myUid;

  const PostDetailSheet({
    super.key,
    required this.post,
    required this.myUid,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TabuColors.bgAlt,
        border: Border.all(color: TabuColors.border, width: 0.8),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 3,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(
                color: TabuColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.titulo?.toUpperCase() ?? 'POST',
                    style: const TextStyle(
                      fontFamily: TabuTypography.displayFont,
                      fontSize: 14,
                      letterSpacing: 4,
                      color: TabuColors.branco,
                    ),
                  ),
                  if (post.descricao?.isNotEmpty == true) ...[
                    const SizedBox(height: 12),
                    Text(
                      post.descricao!,
                      style: const TextStyle(
                        fontFamily: TabuTypography.bodyFont,
                        fontSize: 12,
                        color: TabuColors.subtle,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  CONFIG MENU
// ══════════════════════════════════════════════════════════════════════════════
class ConfigMenu extends StatelessWidget {
  final bool isAdmin;
  final VoidCallback onSignOut;
  final VoidCallback onAbrirAdmin;

  const ConfigMenu({
    super.key,
    required this.isAdmin,
    required this.onSignOut,
    required this.onAbrirAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TabuColors.bgAlt,
        border: Border.all(color: TabuColors.border, width: 0.8),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 3,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(
                color: TabuColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (isAdmin)
              PDSMenuTile(
                icon: Icons.shield_rounded,
                label: 'PAINEL ADMINISTRATIVO',
                sublabel: 'Acessar ferramentas admin',
                onTap: () {
                  Navigator.pop(context);
                  onAbrirAdmin();
                },
              ),
            PDSMenuTile(
              icon: Icons.logout_rounded,
              label: 'SAIR DO APP',
              sublabel: 'Encerrar sessão',
              danger: true,
              onTap: () {
                Navigator.pop(context);
                onSignOut();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  PDS MENU TILE
// ══════════════════════════════════════════════════════════════════════════════
class PDSMenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sublabel;
  final bool danger;
  final VoidCallback onTap;

  const PDSMenuTile({
    super.key,
    required this.icon,
    required this.label,
    this.sublabel,
    this.danger = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: danger
              ? const Color(0xFFE85D5D).withOpacity(0.05)
              : TabuColors.bgCard,
          border: Border.all(
            color: danger
                ? const Color(0xFFE85D5D).withOpacity(0.3)
                : TabuColors.border,
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color:
                  danger ? const Color(0xFFE85D5D) : TabuColors.rosaPrincipal,
              size: 20,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color:
                          danger ? const Color(0xFFE85D5D) : TabuColors.branco,
                    ),
                  ),
                  if (sublabel != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      sublabel!,
                      style: const TextStyle(
                        fontFamily: TabuTypography.bodyFont,
                        fontSize: 10,
                        color: TabuColors.subtle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: danger ? const Color(0xFFE85D5D) : TabuColors.dim,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SIGN OUT SHEET
// ══════════════════════════════════════════════════════════════════════════════
class SignOutSheet extends StatelessWidget {
  const SignOutSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TabuColors.bgAlt,
        borderRadius: BorderRadius.circular(0),
        border: Border.all(color: TabuColors.border, width: 0.8),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 3,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(
                color: TabuColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Icon(Icons.logout_rounded,
                color: Color(0xFFE85D5D), size: 28),
            const SizedBox(height: 16),
            const Text(
              'SAIR DO APP?',
              style: TextStyle(
                fontFamily: TabuTypography.displayFont,
                fontSize: 14,
                letterSpacing: 4,
                color: TabuColors.branco,
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Tem certeza que deseja sair?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 12,
                  color: TabuColors.subtle,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, false),
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: TabuColors.bgCard,
                          border: Border.all(
                              color: TabuColors.borderMid, width: 0.8),
                        ),
                        child: const Center(
                          child: Text(
                            'CANCELAR',
                            style: TextStyle(
                              fontFamily: TabuTypography.bodyFont,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 3,
                              color: TabuColors.subtle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, true),
                      child: Container(
                        height: 46,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE85D5D),
                        ),
                        child: const Center(
                          child: Text(
                            'SAIR',
                            style: TextStyle(
                              fontFamily: TabuTypography.bodyFont,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 3,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  METRIC SHEET (Seguidores / VIP)
// ══════════════════════════════════════════════════════════════════════════════
class MetricSheet extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final Widget content;

  const MetricSheet({
    super.key,
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TabuColors.bgAlt,
        border: Border.all(color: TabuColors.border, width: 0.8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: TabuColors.border, width: 0.8),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.15),
                    border: Border.all(
                        color: accentColor.withOpacity(0.3), width: 0.8),
                  ),
                  child: Icon(icon, color: accentColor, size: 18),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontFamily: TabuTypography.displayFont,
                      fontSize: 14,
                      letterSpacing: 4,
                      color: TabuColors.branco,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: TabuColors.bgCard,
                      border: Border.all(color: TabuColors.border, width: 0.8),
                    ),
                    child: const Icon(Icons.close,
                        color: TabuColors.subtle, size: 18),
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: content,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  USER TILE (Item da lista de usuários)
// ══════════════════════════════════════════════════════════════════════════════
class UserTile extends StatefulWidget {
  final String uid;
  final bool isVip;
  final void Function(String uid, String name) onTap; // ← Mudança aqui
  
  const UserTile({
    super.key,
    required this.uid,
    required this.onTap,
    this.isVip = false,
  });

  @override
  State<UserTile> createState() => _UserTileState();
}

class _UserTileState extends State<UserTile> {
  Map<String, dynamic>? _userData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final snapshot =
          await FirebaseDatabase.instance.ref('Users/${widget.uid}').get();

      if (snapshot.exists && mounted) {
        setState(() {
          _userData = Map<String, dynamic>.from(snapshot.value as Map);
          _loading = false;
        });
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar usuário ${widget.uid}: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: TabuColors.bgCard,
                border: Border.all(color: TabuColors.border, width: 0.8),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 12,
                    width: 120,
                    decoration: BoxDecoration(
                      color: TabuColors.bgCard,
                      border: Border.all(color: TabuColors.border, width: 0.8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 10,
                    width: 80,
                    decoration: BoxDecoration(
                      color: TabuColors.bgCard,
                      border: Border.all(color: TabuColors.border, width: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_userData == null) {
      return const SizedBox.shrink();
    }

    final name = (_userData!['name'] as String? ?? 'Usuário').toUpperCase();
    final bio = (_userData!['bio'] as String? ?? '').trim();

    return GestureDetector(
      onTap: () {
        debugPrint('👆 Tap em usuário: ${widget.uid}');
        widget.onTap(widget.uid, name); // ← Passa uid E name
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        color: Colors.transparent,
        child: Row(
          children: [
            // Avatar usando CachedAvatar
            CachedAvatar(
              uid: widget.uid,
              name: name,
              size: 48,
              radius: 0,
            ),
            const SizedBox(width: 16),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: TabuTypography.bodyFont,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                            color: TabuColors.branco,
                          ),
                        ),
                      ),
                      if (widget.isVip) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFD4AF37),
                          size: 14,
                        ),
                      ],
                    ],
                  ),
                  if (bio.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      bio,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: TabuTypography.bodyFont,
                        fontSize: 11,
                        color: TabuColors.subtle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Arrow
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: TabuColors.dim,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}