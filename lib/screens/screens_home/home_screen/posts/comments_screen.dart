// lib/screens/screens_home/home_screen/posts/comments_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tabuapp/services/services_app/follow_service.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:tabuapp/services/services_app/cached_avatar.dart';
import 'package:tabuapp/services/services_app/user_data_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/models/comment_model.dart';
import 'package:tabuapp/models/post_model.dart';
import 'package:tabuapp/services/services_app/post_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  COMMENTS SCREEN — abre como bottom sheet modal
//
//  Uso:
//    showCommentsSheet(context, post: post, userData: userData);
// ══════════════════════════════════════════════════════════════════════════════

Future<int?> showCommentsSheet(
  BuildContext context, {
  required PostModel post,
  required Map<String, dynamic> userData,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.6),
    builder: (_) => _CommentsSheet(post: post, userData: userData),
  );
}

class _CommentsSheet extends StatefulWidget {
  final PostModel              post;
  final Map<String, dynamic>   userData;
  const _CommentsSheet({required this.post, required this.userData});

  // ID do criador do post — para marcar badge AUTOR nos comentários
  String get postOwnerId => post.userId;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _textCtrl    = TextEditingController();
  final _focusNode   = FocusNode();
  final _scrollCtrl  = ScrollController();
  bool  _enviando    = false;

  String get _uid =>
      FirebaseAuth.instance.currentUser?.uid
      ?? (widget.userData['uid'] as String? ?? '')
      ?? '';
  // Usa notifier para pegar nome/avatar sempre frescos (reflete edições de perfil)
  String get _userName {
    final n = UserDataNotifier.instance.nameUpper;
    return n.isNotEmpty ? n : (widget.userData['name'] as String? ?? 'Anônimo').toUpperCase();
  }
  String? get _userAvatar {
    final a = UserDataNotifier.instance.avatar;
    return a.isNotEmpty ? a : widget.userData['avatar'] as String?;
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _focusNode.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviarComentario() async {
    final txt = _textCtrl.text.trim();
    if (txt.isEmpty || _enviando || _uid.isEmpty) return;

    setState(() => _enviando = true);
    HapticFeedback.mediumImpact();
    _textCtrl.clear();

    try {
      await PostService.instance.addComment(
        postId:     widget.post.id,
        userId:     _uid,
        userName:   _userName,
        userAvatar: _userAvatar,
        texto:      txt,
      );
      // Scroll para o fim após enviar
      await Future.delayed(const Duration(milliseconds: 120));
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) _snack('Erro ao comentar. Tente novamente.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: const Color(0xFF3D0A0A),
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
      content: Text(msg, style: const TextStyle(
          fontFamily: TabuTypography.bodyFont, fontSize: 12,
          fontWeight: FontWeight.w700, letterSpacing: 1.5,
          color: TabuColors.branco)),
    ));
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: TabuColors.bgAlt,
        borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
      ),
      child: Column(children: [

        // ── Linha neon topo ──────────────────────────────────────────────
        Container(height: 2,
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [
            TabuColors.rosaDeep, TabuColors.rosaPrincipal,
            TabuColors.rosaClaro, TabuColors.rosaPrincipal, TabuColors.rosaDeep,
          ]))),

        // ── Header ───────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
          child: Row(children: [
            Container(width: 4, height: 16,
              color: TabuColors.rosaPrincipal,
              margin: const EdgeInsets.only(right: 10)),
            const Text('COMENTÁRIOS',
                style: TextStyle(fontFamily: TabuTypography.displayFont,
                    fontSize: 16, letterSpacing: 4, color: TabuColors.branco)),
            const Spacer(),
            // Contador
            StreamBuilder<List<CommentModel>>(
              stream: PostService.instance.streamComments(widget.post.id),
              builder: (_, snap) {
                final count = snap.data?.length ?? widget.post.commentCount;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: TabuColors.rosaPrincipal.withOpacity(0.12),
                    border: Border.all(
                        color: TabuColors.rosaPrincipal.withOpacity(0.3), width: 0.8)),
                  child: Text('$count',
                      style: const TextStyle(fontFamily: TabuTypography.bodyFont,
                          fontSize: 12, fontWeight: FontWeight.w700,
                          letterSpacing: 1, color: TabuColors.rosaPrincipal)));
              }),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: TabuColors.bgCard,
                  border: Border.all(color: TabuColors.border, width: 0.8)),
                child: const Icon(Icons.close, color: TabuColors.dim, size: 16))),
          ])),

        Container(height: 0.5, color: TabuColors.border),

        // ── Preview do post ──────────────────────────────────────────────
        _PostPreview(post: widget.post),
        Container(height: 0.5, color: TabuColors.border),

        // ── Lista de comentários ─────────────────────────────────────────
        Expanded(
          child: StreamBuilder<List<CommentModel>>(
            stream: PostService.instance.streamComments(widget.post.id),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return const Center(
                  child: SizedBox(width: 24, height: 24,
                    child: CircularProgressIndicator(
                        color: TabuColors.rosaPrincipal, strokeWidth: 2)));
              }

              final comments = snap.data ?? [];

              if (comments.isEmpty) {
                return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.chat_bubble_outline_rounded,
                        color: TabuColors.border, size: 40),
                    const SizedBox(height: 12),
                    const Text('NENHUM COMENTÁRIO',
                        style: TextStyle(fontFamily: TabuTypography.bodyFont,
                            fontSize: 10, fontWeight: FontWeight.w700,
                            letterSpacing: 3, color: TabuColors.subtle)),
                    const SizedBox(height: 6),
                    const Text('Seja o primeiro a comentar!',
                        style: TextStyle(fontFamily: TabuTypography.bodyFont,
                            fontSize: 12, color: TabuColors.subtle)),
                  ]));
              }

              return ListView.separated(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                separatorBuilder: (_, __) =>
                    Container(height: 0.5, color: TabuColors.border,
                        margin: const EdgeInsets.symmetric(horizontal: 16)),
                itemCount: comments.length,
                itemBuilder: (_, i) => _CommentTile(
                  comment:      comments[i],
                  myUid:        _uid,
                  isOwn:        comments[i].userId == _uid,
                  isPostOwner:  comments[i].userId == widget.postOwnerId,
                  onDelete:     comments[i].userId == _uid
                      ? () => PostService.instance.deleteComment(
                            widget.post.id, comments[i].id)
                      : null,
                ),
              );
            }),
        ),

        // ── Input de comentário ──────────────────────────────────────────
        Container(height: 0.5, color: TabuColors.border),
        AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.fromLTRB(16, 10, 16,
              bottom > 0 ? bottom + 8 : 16),
          child: Row(children: [
            // Avatar mini do usuário logado — usa notifier (sem fetch)
            CachedAvatar(
              uid:    _uid,
              name:   _userName,
              size:   36,
              radius: 9,
              isOwn:  true),
            const SizedBox(width: 10),
            // Campo de texto
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 100),
                decoration: BoxDecoration(
                  color: TabuColors.bgCard,
                  border: Border.all(
                    color: _focusNode.hasFocus
                        ? TabuColors.rosaPrincipal.withOpacity(0.5)
                        : TabuColors.border,
                    width: _focusNode.hasFocus ? 1 : 0.8)),
                child: TextField(
                  controller: _textCtrl,
                  focusNode:  _focusNode,
                  maxLines: 4,
                  minLines: 1,
                  maxLength: 300,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _enviarComentario(),
                  style: const TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 13, color: TabuColors.branco,
                      letterSpacing: 0.2, height: 1.45),
                  decoration: InputDecoration(
                    hintText: 'Adicione um comentário...',
                    hintStyle: TextStyle(fontFamily: TabuTypography.bodyFont,
                        fontSize: 13,
                        color: TabuColors.subtle.withOpacity(0.5)),
                    border: InputBorder.none,
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10)),
                ),
              )),
            const SizedBox(width: 10),
            // Botão enviar
            GestureDetector(
              onTap: (_textCtrl.text.trim().isNotEmpty && !_enviando)
                  ? _enviarComentario : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: _textCtrl.text.trim().isNotEmpty
                      ? TabuColors.rosaPrincipal
                      : TabuColors.bgCard,
                  border: Border.all(
                    color: _textCtrl.text.trim().isNotEmpty
                        ? TabuColors.rosaPrincipal
                        : TabuColors.border,
                    width: 0.8),
                  boxShadow: _textCtrl.text.trim().isNotEmpty
                      ? [BoxShadow(color: TabuColors.glow.withOpacity(0.4),
                          blurRadius: 12)] : null),
                child: _enviando
                    ? const Center(child: SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2)))
                    : Icon(Icons.send_rounded,
                        color: _textCtrl.text.trim().isNotEmpty
                            ? Colors.white : TabuColors.subtle,
                        size: 18))),
          ]),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  PREVIEW DO POST no topo do sheet
// ══════════════════════════════════════════════════════════════════════════════
class _PostPreview extends StatelessWidget {
  final PostModel post;
  const _PostPreview({required this.post});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      color: TabuColors.bg,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Avatar — busca sempre do RTDB via CachedAvatar
        CachedAvatar(
          uid:    post.userId,
          name:   post.userName,
          size:   36,
          radius: 8,
          gradient: _gradientForUser(post.userId)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(post.userName,
                style: const TextStyle(fontFamily: TabuTypography.bodyFont,
                    fontSize: 11, fontWeight: FontWeight.w700,
                    letterSpacing: 1.5, color: TabuColors.branco)),
            const SizedBox(height: 3),
            Text(post.titulo,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: TabuTypography.bodyFont,
                    fontSize: 12, letterSpacing: 0.2,
                    color: TabuColors.subtle, height: 1.4)),
          ])),
      ]),
    );
  }

  Widget _avatarFallback() => Container(
    decoration: BoxDecoration(gradient: LinearGradient(
        colors: _gradientForUser(post.userId),
        begin: Alignment.topLeft, end: Alignment.bottomRight)),
    child: Center(child: Text(
        post.userName.isNotEmpty ? post.userName.substring(0, 1) : '?',
        style: const TextStyle(fontFamily: TabuTypography.displayFont,
            fontSize: 14, color: Colors.white))));

  List<Color> _gradientForUser(String id) {
    final p = [
      [const Color(0xFF3D0018), const Color(0xFF6B0030)],
      [const Color(0xFF1A0030), const Color(0xFF4B005A)],
      [const Color(0xFF2D0010), const Color(0xFF7A0028)],
      [const Color(0xFF0D0020), const Color(0xFF3B0050)],
      [const Color(0xFF2A0012), const Color(0xFFCC0044)],
    ];
    return p[id.codeUnits.fold(0, (a, b) => a + b) % p.length];
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  TILE DE COMENTÁRIO
// ══════════════════════════════════════════════════════════════════════════════
class _CommentTile extends StatefulWidget {
  final CommentModel   comment;
  final String         myUid;
  final bool           isOwn;
  final bool           isPostOwner;
  final VoidCallback?  onDelete;
  const _CommentTile({
      required this.comment, required this.myUid, required this.isOwn,
      this.isPostOwner = false, this.onDelete});

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  bool _isVip = false;

  @override
  void initState() {
    super.initState();
    _checkVip();
  }

  Future<void> _checkVip() async {
    // Não verifica para comentários próprios ou do autor do post que já tem badge
    if (widget.myUid.isEmpty || widget.isOwn || widget.isPostOwner) return;
    final vip = await FollowService.instance.isVip(widget.myUid, widget.comment.userId);
    if (mounted) setState(() => _isVip = vip);
  }

  @override
  Widget build(BuildContext context) {
    final comment     = widget.comment;
    final isOwn       = widget.isOwn;
    final isPostOwner = widget.isPostOwner;

    final displayName = isOwn && UserDataNotifier.instance.nameUpper.isNotEmpty
        ? UserDataNotifier.instance.nameUpper
        : comment.userName;

    return Container(
      decoration: isPostOwner ? BoxDecoration(
        border: Border(left: BorderSide(
            color: TabuColors.rosaPrincipal.withOpacity(0.5), width: 2)),
        color: TabuColors.rosaPrincipal.withOpacity(0.04)) : null,
      child: Padding(
      padding: EdgeInsets.fromLTRB(isPostOwner ? 14 : 16, 12, 16, 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Avatar com anel VIP dourado se aplicável
        Stack(children: [
          CachedAvatar(
            uid:    comment.userId,
            name:   displayName,
            size:   34,
            radius: 8,
            isOwn:  isOwn),
          if (_isVip)
            Positioned.fill(child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFFD4AF37).withOpacity(0.7), width: 1.2)),
            )),
        ]),
        const SizedBox(width: 10),
        // Conteúdo
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(comment.userName,
                  style: const TextStyle(fontFamily: TabuTypography.bodyFont,
                      fontSize: 11, fontWeight: FontWeight.w700,
                      letterSpacing: 1.5, color: TabuColors.branco)),
              const SizedBox(width: 8),
              Text(_formatTime(comment.createdAt),
                  style: const TextStyle(fontFamily: TabuTypography.bodyFont,
                      fontSize: 9, letterSpacing: 0.5, color: TabuColors.subtle)),
              // Badge AUTOR — criador do post comentou
              if (isPostOwner) ...[
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [TabuColors.rosaDeep, TabuColors.rosaPrincipal],
                        begin: Alignment.centerLeft, end: Alignment.centerRight),
                    borderRadius: BorderRadius.circular(2)),
                  child: const Text('AUTOR',
                      style: TextStyle(fontFamily: TabuTypography.bodyFont,
                          fontSize: 7, fontWeight: FontWeight.w700,
                          letterSpacing: 1.5, color: Colors.white))),
              ] else if (isOwn) ...[
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: TabuColors.rosaPrincipal.withOpacity(0.12),
                    border: Border.all(color: TabuColors.rosaPrincipal.withOpacity(0.4), width: 0.7)),
                  child: const Text('VOCÊ',
                      style: TextStyle(fontFamily: TabuTypography.bodyFont,
                          fontSize: 7, fontWeight: FontWeight.w700,
                          letterSpacing: 1.5, color: TabuColors.rosaPrincipal))),
              ],
              if (_isVip) ...[
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A0A00),
                    border: Border.all(
                        color: const Color(0xFFD4AF37).withOpacity(0.6), width: 0.8),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFD4AF37).withOpacity(0.2),
                          blurRadius: 5),
                    ]),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.star_rounded,
                        color: Color(0xFFD4AF37), size: 8),
                    const SizedBox(width: 3),
                    const Text('VIP',
                        style: TextStyle(
                          fontFamily: TabuTypography.bodyFont,
                          fontSize: 7, fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: Color(0xFFD4AF37))),
                  ])),
              ],
            ]),
            const SizedBox(height: 5),
            Text(comment.texto,
                style: const TextStyle(fontFamily: TabuTypography.bodyFont,
                    fontSize: 13, letterSpacing: 0.2,
                    color: TabuColors.branco, height: 1.45)),
          ])),
        // Botão deletar (só comentário próprio)
        if (widget.onDelete != null)
          GestureDetector(
            onTap: () => _confirmDelete(context),
            child: Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Icon(Icons.delete_outline,
                  color: TabuColors.subtle.withOpacity(0.5), size: 15))),
      ]),
      ));
  }

  void _confirmDelete(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: TabuColors.bgAlt,
      shape: const RoundedRectangleBorder(),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 3,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(color: TabuColors.border,
                  borderRadius: BorderRadius.circular(2))),
          const Text('EXCLUIR COMENTÁRIO?',
              style: TextStyle(fontFamily: TabuTypography.displayFont,
                  fontSize: 14, letterSpacing: 4, color: TabuColors.branco)),
          const SizedBox(height: 8),
          const Text('Esta ação não pode ser desfeita.',
              style: TextStyle(fontFamily: TabuTypography.bodyFont,
                  fontSize: 12, color: TabuColors.subtle)),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(height: 46,
                  decoration: BoxDecoration(
                    color: TabuColors.bgCard,
                    border: Border.all(color: TabuColors.border, width: 0.8)),
                  child: const Center(child: Text('CANCELAR',
                      style: TextStyle(fontFamily: TabuTypography.bodyFont,
                          fontSize: 11, fontWeight: FontWeight.w700,
                          letterSpacing: 2.5, color: TabuColors.dim)))))),
              const SizedBox(width: 12),
              Expanded(child: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  widget.onDelete?.call();
                  HapticFeedback.mediumImpact();
                },
                child: Container(height: 46,
                  decoration: const BoxDecoration(color: Color(0xFFE85D5D)),
                  child: const Center(child: Text('EXCLUIR',
                      style: TextStyle(fontFamily: TabuTypography.bodyFont,
                          fontSize: 11, fontWeight: FontWeight.w700,
                          letterSpacing: 2.5, color: Colors.white)))))),
            ])),
          const SizedBox(height: 20),
        ])));
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24)   return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  MINI AVATAR
// ══════════════════════════════════════════════════════════════════════════════
class _MiniAvatar extends StatelessWidget {
  final String avatarUrl;
  final String name;
  final double size;
  const _MiniAvatar({required this.avatarUrl, required this.name, required this.size});

  List<Color> get _gradient {
    final palettes = [
      [const Color(0xFF3D0018), const Color(0xFF8B003A)],
      [const Color(0xFF1A0030), const Color(0xFF9B0060)],
      [const Color(0xFF0D0020), const Color(0xFF4B0070)],
    ];
    final idx = name.codeUnits.fold(0, (a, b) => a + b) % palettes.length;
    return palettes[idx];
  }

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.25;
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(colors: _gradient,
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        border: Border.all(color: TabuColors.borderMid, width: 0.8)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 1),
        child: avatarUrl.isNotEmpty
            ? Image.network(avatarUrl, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback())
            : _fallback()),
    );
  }

  Widget _fallback() => Container(
    decoration: BoxDecoration(gradient: LinearGradient(
        colors: _gradient,
        begin: Alignment.topLeft, end: Alignment.bottomRight)),
    child: Center(child: Text(
        name.isNotEmpty ? name.substring(0, 1) : '?',
        style: TextStyle(fontFamily: TabuTypography.displayFont,
            fontSize: size * 0.38, color: Colors.white))));
}