// lib/services/services_app/cached_avatar.dart
//
// Widget de avatar que SEMPRE busca a URL atual do RTDB via UserAvatarService.
// Não confia na URL salva em posts/comentários (tokens podem estar expirados).
//
// Uso simples:
//   CachedAvatar(uid: comment.userId, name: comment.userName, size: 34, radius: 8)

import 'package:flutter/material.dart';
import 'package:tabuapp/services/services_app/user_data_notifier.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/services/services_app/user_avatar_service.dart';

class CachedAvatar extends StatefulWidget {
  final String  uid;
  final String  name;
  final double  size;
  final double  radius;
  final bool    isOwn;        // se true, usa o notifier diretamente (sem fetch)
  final bool    glowRing;     // anel gradiente rosa (para posts próprios)
  final List<Color>? gradient; // gradiente do placeholder (baseado no userId)

  const CachedAvatar({
    super.key,
    required this.uid,
    required this.name,
    required this.size,
    required this.radius,
    this.isOwn    = false,
    this.glowRing = false,
    this.gradient,
  });

  @override
  State<CachedAvatar> createState() => _CachedAvatarState();
}

class _CachedAvatarState extends State<CachedAvatar> {
  String? _avatarUrl;
  bool    _loaded = false;

  List<Color> get _gradient {
    if (widget.gradient != null) return widget.gradient!;
    final palettes = [
      [const Color(0xFF3D0018), const Color(0xFF6B0030)],
      [const Color(0xFF1A0030), const Color(0xFF4B005A)],
      [const Color(0xFF2D0010), const Color(0xFF7A0028)],
      [const Color(0xFF0D0020), const Color(0xFF3B0050)],
      [const Color(0xFF2A0012), const Color(0xFFCC0044)],
    ];
    final idx = widget.uid.codeUnits.fold(0, (a, b) => a + b) % palettes.length;
    return palettes[idx];
  }

  @override
  void initState() {
    super.initState();
    // Ouve o notifier para reconstruir quando o avatar do usuário logado mudar
    UserDataNotifier.instance.addListener(_onNotifierChanged);
    _resolve();
  }

  @override
  void dispose() {
    UserDataNotifier.instance.removeListener(_onNotifierChanged);
    super.dispose();
  }

  void _onNotifierChanged() {
    if (!widget.isOwn || !mounted) return;
    final url = UserDataNotifier.instance.avatar;
    if (url != _avatarUrl) setState(() => _avatarUrl = url);
  }

  @override
  void didUpdateWidget(CachedAvatar old) {
    super.didUpdateWidget(old);
    if (old.uid != widget.uid) _resolve();
  }

  Future<void> _resolve() async {
    // Usuário logado: lê do notifier (sempre atualizado)
    if (widget.isOwn) {
      final url = UserDataNotifier.instance.avatar;
      if (mounted) setState(() { _avatarUrl = url; _loaded = true; });
      return;
    }
    // Outros usuários: busca do RTDB com cache em memória
    final url = await UserAvatarService.instance.getAvatar(widget.uid);
    if (mounted) setState(() { _avatarUrl = url; _loaded = true; });
  }

  @override
  Widget build(BuildContext context) {
    final ringSize = widget.size;
    final padding  = widget.glowRing ? 2.0 : 1.5;
    final innerSize = ringSize - padding * 2;

    return Container(
      width: ringSize, height: ringSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        gradient: widget.glowRing
            ? const LinearGradient(
                colors: [TabuColors.rosaDeep, TabuColors.rosaPrincipal, TabuColors.rosaClaro],
                begin: Alignment.topLeft, end: Alignment.bottomRight)
            : LinearGradient(colors: [TabuColors.borderMid, TabuColors.borderMid]),
        boxShadow: widget.glowRing
            ? [BoxShadow(color: TabuColors.glow.withOpacity(0.5), blurRadius: 10, spreadRadius: 1)]
            : null),
      padding: EdgeInsets.all(padding),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius - padding),
        child: _buildImage(),
      ),
    );
  }

  Widget _buildImage() {
    final url = _avatarUrl;
    if (!_loaded) {
      // Skeleton enquanto carrega
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: _gradient,
              begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: Center(child: SizedBox(
          width: widget.size * 0.28, height: widget.size * 0.28,
          child: CircularProgressIndicator(
              color: Colors.white.withOpacity(0.4), strokeWidth: 1.5))));
    }
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: _gradient,
          begin: Alignment.topLeft, end: Alignment.bottomRight)),
    child: Center(child: Text(
        widget.name.isNotEmpty ? widget.name.substring(0, 1).toUpperCase() : '?',
        style: TextStyle(
            fontFamily: TabuTypography.displayFont,
            fontSize: widget.size * 0.36,
            color: Colors.white))));
}