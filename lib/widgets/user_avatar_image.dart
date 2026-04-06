// lib/widgets/user_avatar_image.dart
import 'package:flutter/material.dart';
import 'package:tabuapp/services/services_app/user_profile_cache.dart';
import 'package:tabuapp/services/services_app/user_data_notifier.dart';

class UserAvatarImage extends StatefulWidget {
  final String uid;
  final String fallbackUrl;   // user_avatar do post (exibido enquanto carrega)
  final double size;
  final double radius;
  final bool isOwn;

  const UserAvatarImage({
    super.key,
    required this.uid,
    required this.fallbackUrl,
    required this.size,
    required this.radius,
    this.isOwn = false,
  });

  @override
  State<UserAvatarImage> createState() => _UserAvatarImageState();
}

class _UserAvatarImageState extends State<UserAvatarImage> {
  String _avatarUrl = '';

  @override
  void initState() {
    super.initState();
    if (widget.isOwn && UserDataNotifier.instance.avatar.isNotEmpty) {
      _avatarUrl = UserDataNotifier.instance.avatar;
      return;
    }
    final cached = UserProfileCache.instance.getCached(widget.uid);
    if (cached != null) {
      _avatarUrl = cached.avatar.isNotEmpty ? cached.avatar : widget.fallbackUrl;
    } else {
      _avatarUrl = widget.fallbackUrl;
      _load();
    }
  }

  Future<void> _load() async {
    final profile = await UserProfileCache.instance.fetch(widget.uid);
    if (mounted && profile.avatar.isNotEmpty) {
      setState(() => _avatarUrl = profile.avatar);
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _avatarUrl.isNotEmpty ? _avatarUrl : widget.fallbackUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: url.isNotEmpty
          ? Image.network(url, width: widget.size, height: widget.size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder())
          : _placeholder(),
    );
  }

  Widget _placeholder() => Container(
    width: widget.size, height: widget.size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(widget.radius),
      color: Colors.grey[800],
    ),
    child: const Icon(Icons.person_outline, color: Colors.white38),
  );
}