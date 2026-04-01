// lib/screens/screens_home/perfil_screen/perfil_screen_widgets.dart
// 
// WIDGETS COMPLEMENTARES DO PERFIL SCREEN
// Este arquivo contém todos os widgets auxiliares usados no perfil_screen.dart
//
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/models/post_model.dart';
import 'package:tabuapp/services/services_app/cached_avatar.dart';
import 'package:tabuapp/services/services_app/user_data_notifier.dart';
import 'package:tabuapp/services/services_app/post_service.dart';
import 'package:tabuapp/screens/screens_home/home_screen/posts/comments_screen.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  USER LIST
// ══════════════════════════════════════════════════════════════════════════════
class UserList extends StatelessWidget {
  final List<String> uids;
  final String emptyLabel;
  final void Function(String uid) onTap;
  final bool isVip;
  const UserList({
    super.key,
    required this.uids,
    required this.emptyLabel,
    required this.onTap,
    this.isVip = false,
  });

  @override
  Widget build(BuildContext context) {
    if (uids.isEmpty) {
      return Padding(padding: const EdgeInsets.all(48),
        child: Center(child: Text(emptyLabel.toUpperCase(),
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: TabuTypography.bodyFont,
              fontSize: 10, letterSpacing: 2.5, color: TabuColors.subtle))));
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      itemCount: uids.length,
      separatorBuilder: (_, __) => Container(height: 0.5, color: TabuColors.border),
      itemBuilder: (_, i) => UserTile(uid: uids[i], isVip: isVip,
          onTap: () => onTap(uids[i])));
  }
}

class UserTile extends StatelessWidget {
  final String uid; final bool isVip; final VoidCallback onTap;
  const UserTile({super.key, required this.uid, required this.onTap, this.isVip = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(children: [
          CachedAvatar(uid: uid, name: '', size: 40, radius: 10),
          const SizedBox(width: 14),
          Expanded(child: Text(uid, style: const TextStyle(
              fontFamily: TabuTypography.bodyFont, fontSize: 12,
              fontWeight: FontWeight.w600, letterSpacing: 1, color: TabuColors.dim))),
          if (isVip) Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFF1A0A00),
              border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.6), width: 0.8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: const [
              Icon(Icons.star_rounded, color: Color(0xFFD4AF37), size: 9),
              SizedBox(width: 4),
              Text('VIP', style: TextStyle(fontFamily: TabuTypography.bodyFont,
                  fontSize: 8, fontWeight: FontWeight.w700,
                  letterSpacing: 1.5, color: Color(0xFFD4AF37))),
            ])),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: TabuColors.border, size: 16),
        ])));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  METRIC SHEET
// ══════════════════════════════════════════════════════════════════════════════
class MetricSheet extends StatelessWidget {
  final String title; final IconData icon;
  final Color accentColor; final Widget content;
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
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.72),
      decoration: BoxDecoration(color: TabuColors.bgAlt,
          border: Border(top: BorderSide(color: accentColor, width: 1.5))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.fromLTRB(24, 16, 24, 0), child:
          Column(children: [
            Center(child: Container(width: 36, height: 3,
              decoration: BoxDecoration(color: TabuColors.border,
                  borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(children: [
              Icon(icon, color: accentColor, size: 18),
              const SizedBox(width: 10),
              Text(title, style: TextStyle(fontFamily: TabuTypography.displayFont,
                  fontSize: 18, letterSpacing: 5, color: TabuColors.branco)),
            ]),
          ])),
        const SizedBox(height: 12),
        Container(height: 0.5, color: TabuColors.border),
        Flexible(child: SingleChildScrollView(child: content)),
      ]));
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
      padding: const EdgeInsets.symmetric(horizontal: 1),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (_, i) => Container(color: TabuColors.bgCard,
            child: Opacity(opacity: 1.0 - (i * 0.07).clamp(0.0, 0.55),
              child: Container(color: TabuColors.border.withOpacity(0.12)))),
          childCount: 9),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, crossAxisSpacing: 1.5,
          mainAxisSpacing: 1.5, childAspectRatio: 1)));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  BOTTOM ACTIONS
// ══════════════════════════════════════════════════════════════════════════════
class BottomActions extends StatelessWidget {
  final VoidCallback onSignOut;
  const BottomActions({super.key, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: TabuColors.nav,
          border: Border(top: BorderSide(color: TabuColors.border, width: 0.5))),
      padding: EdgeInsets.only(left: 24, right: 24, top: 12,
          bottom: MediaQuery.of(context).padding.bottom + 12),
      child: GestureDetector(
        onTap: onSignOut,
        child: Container(height: 48,
          decoration: BoxDecoration(color: TabuColors.bgCard,
              border: Border.all(color: TabuColors.border, width: 0.8)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
            Icon(Icons.logout, color: TabuColors.subtle, size: 16),
            SizedBox(width: 10),
            Text('SAIR', style: TextStyle(fontFamily: TabuTypography.bodyFont,
                fontSize: 12, fontWeight: FontWeight.w700,
                letterSpacing: 5, color: TabuColors.subtle)),
          ]))));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  AVATAR
// ══════════════════════════════════════════════════════════════════════════════
class Avatar extends StatelessWidget {
  final String avatarUrl; final bool showCamera;
  const Avatar({super.key, required this.avatarUrl, this.showCamera = true});

  @override
  Widget build(BuildContext context) {
    return Stack(alignment: Alignment.center, children: [
      Container(width: 86, height: 86,
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: ClipOval(child: avatarUrl.isNotEmpty
            ? Image.network(avatarUrl, fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) => progress == null ? child
                    : Container(color: TabuColors.bgAlt,
                        child: const Center(child: SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              color: TabuColors.rosaPrincipal, strokeWidth: 1.5)))),
                errorBuilder: (_, __, ___) => Container(color: TabuColors.bgAlt,
                    child: const Icon(Icons.person_outline,
                        color: TabuColors.rosaPrincipal, size: 36)))
            : Container(color: TabuColors.bgAlt,
                child: const Icon(Icons.person_outline,
                    color: TabuColors.rosaPrincipal, size: 36)))),
      if (showCamera)
        Positioned(bottom: 0, right: 0,
          child: Container(width: 26, height: 26,
            decoration: BoxDecoration(color: TabuColors.rosaPrincipal,
                shape: BoxShape.circle,
                border: Border.all(color: TabuColors.bg, width: 2)),
            child: const Icon(Icons.photo_camera, color: TabuColors.branco, size: 12))),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  STAT CARD
// ══════════════════════════════════════════════════════════════════════════════
class StatCard extends StatelessWidget {
  final String value; final String label; final IconData icon;
  final bool highlight; final VoidCallback onTap;
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
    final gold = const Color(0xFFD4AF37);
    return Expanded(child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: highlight ? const Color(0xFF1A0A00) : TabuColors.bgCard,
          border: Border.all(
            color: highlight ? gold.withOpacity(0.5) : TabuColors.border,
            width: 0.8)),
        child: Column(children: [
          Icon(icon, color: highlight ? gold : TabuColors.dim, size: 18),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontFamily: TabuTypography.displayFont,
              fontSize: 26, letterSpacing: 1,
              color: highlight ? gold : TabuColors.branco,
              shadows: highlight ? [Shadow(color: gold, blurRadius: 10)] : null)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontFamily: TabuTypography.bodyFont,
              fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1.5,
              color: highlight ? gold.withOpacity(0.8) : TabuColors.subtle)),
        ]))));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  VIP BADGE
// ══════════════════════════════════════════════════════════════════════════════
class VipFriendsBadge extends StatelessWidget {
  final int count;
  const VipFriendsBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0A00),
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.45), width: 0.8),
        boxShadow: [
          BoxShadow(color: const Color(0xFFD4AF37).withOpacity(0.08), blurRadius: 16),
        ]),
      child: Row(children: [
        const Icon(Icons.star_rounded, color: Color(0xFFD4AF37), size: 20),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('AMIGOS VIP', style: TextStyle(
              fontFamily: TabuTypography.displayFont,
              fontSize: 14, letterSpacing: 4,
              color: Color(0xFFD4AF37))),
          Text(
            count == 1 ? '1 amigo próximo' : '$count amigos próximos',
            style: TextStyle(fontFamily: TabuTypography.bodyFont,
                fontSize: 11, letterSpacing: 1,
                color: const Color(0xFFD4AF37).withOpacity(0.6))),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFD4AF37).withOpacity(0.15),
            border: Border.all(
                color: const Color(0xFFD4AF37).withOpacity(0.5), width: 0.8)),
          child: const Text('★ VIP', style: TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 9, fontWeight: FontWeight.w700,
              letterSpacing: 2, color: Color(0xFFD4AF37)))),
      ]));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  CONFIG MENU
// ══════════════════════════════════════════════════════════════════════════════
class ConfigMenu extends StatelessWidget {
  final bool         isAdmin;
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
      decoration: const BoxDecoration(color: TabuColors.bgAlt,
          border: Border(top: BorderSide(color: TabuColors.rosaPrincipal, width: 1.5))),
      child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 3,
          margin: const EdgeInsets.only(top: 12, bottom: 8),
          decoration: BoxDecoration(color: TabuColors.border,
              borderRadius: BorderRadius.circular(2))),
        Padding(padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
          child: Row(children: [
            Container(width: 3, height: 14, color: TabuColors.rosaPrincipal,
                margin: const EdgeInsets.only(right: 10)),
            const Text('CONFIGURAÇÕES', style: TextStyle(fontFamily: TabuTypography.displayFont,
                fontSize: 14, letterSpacing: 4, color: TabuColors.branco)),
          ])),
        const SizedBox(height: 8),
        Container(height: 0.5, color: TabuColors.border),

        if (isAdmin) ...[
          ConfigTile(
            icon:       Icons.shield_rounded,
            label:      'PAINEL PROFISSIONAL',
            sublabel:   'Moderação, denúncias e usuários',
            accent:     false,
            adminStyle: true,
            onTap: () { Navigator.pop(context); onAbrirAdmin(); }),
          Container(height: 0.5, color: TabuColors.border),
        ],

        ConfigTile(icon: Icons.edit_outlined, label: 'EDITAR PERFIL',
            sublabel: 'Nome, foto, bio e localização',
            onTap: () => Navigator.pop(context)),
        Container(height: 0.5, color: TabuColors.border),
        ConfigTile(icon: Icons.notifications_outlined, label: 'NOTIFICAÇÕES',
            sublabel: 'Em breve', onTap: () => Navigator.pop(context), disabled: true),
        Container(height: 0.5, color: TabuColors.border),
        ConfigTile(icon: Icons.lock_outline_rounded, label: 'PRIVACIDADE',
            sublabel: 'Em breve', onTap: () => Navigator.pop(context), disabled: true),
        Container(height: 0.5, color: TabuColors.border),
        ConfigTile(icon: Icons.logout_rounded, label: 'SAIR DA CONTA',
            sublabel: 'Encerrar sessão', accent: true,
            onTap: () { Navigator.pop(context); onSignOut(); }),
        const SizedBox(height: 8),
      ])));
  }
}

class ConfigTile extends StatelessWidget {
  final IconData icon; final String label; final String sublabel;
  final VoidCallback onTap; final bool accent; final bool disabled;
  final bool adminStyle;

  const ConfigTile({
    super.key,
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.onTap,
    this.accent = false,
    this.disabled = false,
    this.adminStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = disabled    ? TabuColors.border
        : adminStyle          ? TabuColors.rosaPrincipal
        : accent              ? const Color(0xFFE85D5D)
        :                       TabuColors.branco;

    return InkWell(onTap: disabled ? null : onTap,
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(children: [
          Container(width: 38, height: 38,
            decoration: BoxDecoration(color: color.withOpacity(0.08),
                border: Border.all(color: color.withOpacity(0.25), width: 0.8)),
            child: Icon(icon, color: color, size: 17)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontFamily: TabuTypography.bodyFont,
                fontSize: 12, fontWeight: FontWeight.w700,
                letterSpacing: 2, color: color)),
            Text(sublabel, style: const TextStyle(fontFamily: TabuTypography.bodyFont,
                fontSize: 10, letterSpacing: 0.5, color: TabuColors.subtle)),
          ])),
          if (!disabled) Icon(Icons.chevron_right_rounded,
              color: color.withOpacity(0.4), size: 16),
        ])));
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
      decoration: const BoxDecoration(color: TabuColors.bgAlt,
          border: Border(top: BorderSide(color: Color(0xFFE85D5D), width: 1.5))),
      child: SafeArea(top: false,
        child: Padding(padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Center(child: Container(width: 36, height: 3,
              decoration: BoxDecoration(color: TabuColors.border,
                  borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Container(width: 52, height: 52,
              decoration: BoxDecoration(color: const Color(0xFFE85D5D).withOpacity(0.1),
                  border: Border.all(color: const Color(0xFFE85D5D).withOpacity(0.3), width: 0.8)),
              child: const Icon(Icons.logout_rounded, color: Color(0xFFE85D5D), size: 22)),
            const SizedBox(height: 16),
            const Text('SAIR DA CONTA?', style: TextStyle(
                fontFamily: TabuTypography.displayFont, fontSize: 16,
                letterSpacing: 4, color: TabuColors.branco)),
            const SizedBox(height: 8),
            const Text('Você será redirecionado para a tela de acesso.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: TabuTypography.bodyFont,
                  fontSize: 12, height: 1.6, letterSpacing: 0.3, color: TabuColors.subtle)),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(context, false),
                child: Container(height: 46,
                  decoration: BoxDecoration(color: TabuColors.bgCard,
                      border: Border.all(color: TabuColors.border, width: 0.8)),
                  child: const Center(child: Text('CANCELAR', style: TextStyle(
                      fontFamily: TabuTypography.bodyFont, fontSize: 11,
                      fontWeight: FontWeight.w700, letterSpacing: 2.5,
                      color: TabuColors.dim)))))),
              const SizedBox(width: 12),
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(context, true),
                child: Container(height: 46,
                  decoration: const BoxDecoration(color: Color(0xFFE85D5D)),
                  child: const Center(child: Text('SAIR', style: TextStyle(
                      fontFamily: TabuTypography.bodyFont, fontSize: 11,
                      fontWeight: FontWeight.w700, letterSpacing: 2.5,
                      color: Colors.white)))))),
            ]),
          ]))));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  POST DETAIL SHEET
// ══════════════════════════════════════════════════════════════════════════════
class PostDetailSheet extends StatefulWidget {
  final PostModel post;
  final String    myUid;
  const PostDetailSheet({super.key, required this.post, required this.myUid});

  @override
  State<PostDetailSheet> createState() => _PostDetailSheetState();
}

class _PostDetailSheetState extends State<PostDetailSheet> {
  late int _likes;
  late int _commentCount;
  bool     _liked       = false;
  bool     _loadingLike = false;

  bool get _isOwn => widget.post.userId == widget.myUid;

  @override
  void initState() {
    super.initState();
    _likes        = widget.post.likes;
    _commentCount = widget.post.commentCount;
    _checkLike();
  }

  Future<void> _checkLike() async {
    if (widget.myUid.isEmpty) return;
    final liked = await PostService.instance.isLikedBy(widget.post.id, widget.myUid);
    if (mounted) setState(() => _liked = liked);
  }

  Future<void> _toggleLike() async {
    if (_loadingLike || widget.myUid.isEmpty) return;
    setState(() => _loadingLike = true);
    HapticFeedback.selectionClick();
    try {
      final nowLiked = await PostService.instance.toggleLike(widget.post.id, widget.myUid);
      if (mounted) setState(() {
        _liked = nowLiked;
        _likes += nowLiked ? 1 : -1;
        _loadingLike = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingLike = false);
    }
  }

  Future<void> _abrirComentarios() async {
    HapticFeedback.selectionClick();
    final userData = {...UserDataNotifier.instance.value, 'uid': widget.myUid};
    final newCount = await showCommentsSheet(
        context, post: widget.post, userData: userData);
    if (newCount != null && mounted) setState(() => _commentCount = newCount);
  }

  void _mostrarMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: TabuColors.bgAlt,
      shape: const RoundedRectangleBorder(),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 32, height: 2,
            margin: const EdgeInsets.only(top: 14, bottom: 20),
            decoration: BoxDecoration(color: TabuColors.border,
                borderRadius: BorderRadius.circular(1))),
        if (_isOwn) ...[
          PDSMenuTile(icon: Icons.delete_outline_rounded, label: 'EXCLUIR',
              sublabel: 'Remove permanentemente', danger: true,
              onTap: () { Navigator.pop(context); _confirmarDelete(); }),
          Container(height: 0.5, color: TabuColors.border),
        ],
        PDSMenuTile(icon: Icons.flag_outlined, label: 'DENUNCIAR',
            sublabel: 'Reportar este conteúdo',
            onTap: () => Navigator.pop(context)),
        const SizedBox(height: 12),
      ])));
  }

  void _confirmarDelete() {
    showModalBottomSheet(
      context: context,
      backgroundColor: TabuColors.bgAlt,
      shape: const RoundedRectangleBorder(),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 32, height: 2,
            margin: const EdgeInsets.only(top: 14, bottom: 20),
            decoration: BoxDecoration(color: TabuColors.border,
                borderRadius: BorderRadius.circular(1))),
        const Text('EXCLUIR PUBLICAÇÃO?',
            style: TextStyle(fontFamily: TabuTypography.displayFont,
                fontSize: 13, letterSpacing: 4, color: TabuColors.branco)),
        const SizedBox(height: 8),
        const Text('Esta ação é irreversível.',
            style: TextStyle(fontFamily: TabuTypography.bodyFont,
                fontSize: 11, letterSpacing: 0.5, color: TabuColors.subtle)),
        const SizedBox(height: 24),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(height: 44,
                decoration: BoxDecoration(color: TabuColors.bgCard,
                    border: Border.all(color: TabuColors.border, width: 0.8)),
                child: const Center(child: Text('CANCELAR',
                    style: TextStyle(fontFamily: TabuTypography.bodyFont,
                        fontSize: 10, fontWeight: FontWeight.w700,
                        letterSpacing: 3, color: TabuColors.dim)))))),
            const SizedBox(width: 10),
            Expanded(child: GestureDetector(
              onTap: () async {
                Navigator.pop(context);
                Navigator.pop(context);
                HapticFeedback.mediumImpact();
                await PostService.instance.deletePost(widget.post.id);
              },
              child: Container(height: 44,
                decoration: const BoxDecoration(color: Color(0xFFE85D5D)),
                child: const Center(child: Text('EXCLUIR',
                    style: TextStyle(fontFamily: TabuTypography.bodyFont,
                        fontSize: 10, fontWeight: FontWeight.w700,
                        letterSpacing: 3, color: Colors.white)))))),
          ])),
        const SizedBox(height: 20),
      ])));
  }

  List<Color> _gradient() {
    final p = [
      [const Color(0xFF3D0018), const Color(0xFF6B0030)],
      [const Color(0xFF1A0030), const Color(0xFF4B005A)],
      [const Color(0xFF2D0010), const Color(0xFF7A0028)],
      [const Color(0xFF0D0020), const Color(0xFF3B0050)],
      [const Color(0xFF2A0012), const Color(0xFFCC0044)],
    ];
    return p[widget.post.userId.codeUnits.fold(0, (a, b) => a + b) % p.length];
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24)   return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    final post      = widget.post;
    final gradient  = _gradient();
    final temMidia  = (post.tipo == 'foto' && post.mediaUrl != null) || post.tipo == 'emoji';
    final displayName = _isOwn && UserDataNotifier.instance.name.isNotEmpty
        ? UserDataNotifier.instance.nameUpper : post.userName;

    return Container(
      decoration: const BoxDecoration(color: TabuColors.bgAlt),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 32, height: 2,
            margin: const EdgeInsets.only(top: 14),
            decoration: BoxDecoration(color: TabuColors.border,
                borderRadius: BorderRadius.circular(1))),
        Container(height: 1.5, margin: const EdgeInsets.only(top: 12),
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [
            Colors.transparent, TabuColors.rosaDeep, TabuColors.rosaPrincipal,
            TabuColors.rosaClaro, TabuColors.rosaPrincipal, TabuColors.rosaDeep,
            Colors.transparent,
          ]))),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            CachedAvatar(uid: post.userId, name: displayName,
                size: 40, radius: 10, isOwn: _isOwn, glowRing: _isOwn),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(displayName,
                    style: const TextStyle(fontFamily: TabuTypography.bodyFont,
                        fontSize: 13, fontWeight: FontWeight.w700,
                        letterSpacing: 1.5, color: TabuColors.branco)),
                if (_isOwn) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: TabuColors.rosaPrincipal.withOpacity(0.12),
                      border: Border.all(
                          color: TabuColors.rosaPrincipal.withOpacity(0.4), width: 0.6)),
                    child: const Text('VOCÊ', style: TextStyle(
                        fontFamily: TabuTypography.bodyFont, fontSize: 7,
                        fontWeight: FontWeight.w700, letterSpacing: 2,
                        color: TabuColors.rosaPrincipal))),
                ],
              ]),
              const SizedBox(height: 2),
              Text(_formatTime(post.createdAt),
                  style: const TextStyle(fontFamily: TabuTypography.bodyFont,
                      fontSize: 9, letterSpacing: 0.5, color: TabuColors.subtle)),
            ])),
            GestureDetector(
              onTap: _mostrarMenu,
              child: Padding(padding: const EdgeInsets.all(4),
                child: const Icon(Icons.more_horiz, color: TabuColors.subtle, size: 16))),
          ])),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Text(post.titulo,
              style: const TextStyle(fontFamily: TabuTypography.bodyFont,
                  fontSize: 15, fontWeight: FontWeight.w600,
                  letterSpacing: 0.2, color: TabuColors.branco, height: 1.4))),
        if (temMidia) _buildMidia(post, gradient),
        if (post.descricao != null && post.descricao!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(post.descricao!,
                style: TextStyle(fontFamily: TabuTypography.bodyFont,
                    fontSize: 13, letterSpacing: 0.2,
                    color: TabuColors.dim.withOpacity(0.9), height: 1.5))),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Container(height: 0.5,
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [
                Colors.transparent, TabuColors.border, Colors.transparent])))),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Row(children: [
            PDSActionBtn(
              icon: _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              label: '$_likes',
              color: _liked ? TabuColors.rosaPrincipal : TabuColors.subtle,
              onTap: _toggleLike),
            PDSActionBtn(
              icon: Icons.chat_bubble_outline_rounded,
              label: _commentCount > 0 ? '$_commentCount' : 'COMENTAR',
              color: TabuColors.subtle,
              onTap: _abrirComentarios),
          ])),
        SizedBox(height: MediaQuery.of(context).padding.bottom),
      ]),
    );
  }

  Widget _buildMidia(PostModel post, List<Color> gradient) {
    if (post.tipo == 'emoji' && post.emoji != null) {
      return Container(
        height: 200, margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient,
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          border: Border.all(color: TabuColors.border.withOpacity(0.4), width: 0.5)),
        child: Center(child: Text(post.emoji!, style: const TextStyle(fontSize: 80))));
    }
    if (post.mediaUrl != null) {
      return SizedBox(height: 280, width: double.infinity,
        child: Image.network(post.mediaUrl!, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(height: 180,
              decoration: BoxDecoration(gradient: LinearGradient(
                  colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight)),
              child: const Center(child: Icon(Icons.broken_image_outlined,
                  color: TabuColors.subtle, size: 28)))));
    }
    return const SizedBox.shrink();
  }
}

class PDSMenuTile extends StatelessWidget {
  final IconData icon; final String label; final String sublabel;
  final bool danger; final VoidCallback onTap;
  const PDSMenuTile({
    super.key,
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFE85D5D) : TabuColors.branco;
    return InkWell(onTap: onTap,
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(color: color.withOpacity(0.08),
                border: Border.all(color: color.withOpacity(0.2), width: 0.8)),
            child: Icon(icon, color: color, size: 16)),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontFamily: TabuTypography.bodyFont,
                fontSize: 12, fontWeight: FontWeight.w700,
                letterSpacing: 2.5, color: color)),
            Text(sublabel, style: const TextStyle(fontFamily: TabuTypography.bodyFont,
                fontSize: 9, letterSpacing: 0.5, color: TabuColors.subtle)),
          ]),
        ])));
  }
}

class PDSActionBtn extends StatelessWidget {
  final IconData icon; final String label;
  final Color color; final VoidCallback onTap;
  const PDSActionBtn({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(onTap: onTap,
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontFamily: TabuTypography.bodyFont,
              fontSize: 10, fontWeight: FontWeight.w600,
              letterSpacing: 2, color: color)),
        ]))));
}

// ══════════════════════════════════════════════════════════════════════════════
//  BACKGROUND
// ══════════════════════════════════════════════════════════════════════════════
class PerfilBg extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = TabuColors.bg);
    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.15), size.width * 0.7,
      Paint()..shader = RadialGradient(colors: [
        TabuColors.rosaPrincipal.withOpacity(0.08), Colors.transparent])
          .createShader(Rect.fromCircle(center: Offset(size.width * 0.15, size.height * 0.15),
              radius: size.width * 0.7)));
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.85), size.width * 0.5,
      Paint()..shader = RadialGradient(colors: [TabuColors.bgAlt.withOpacity(0.9),
        Colors.transparent]).createShader(Rect.fromCircle(
            center: Offset(size.width * 0.9, size.height * 0.85), radius: size.width * 0.5)));
  }
  @override
  bool shouldRepaint(PerfilBg old) => false;
}