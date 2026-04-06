// lib/widgets/user_name_text.dart
import 'package:flutter/material.dart';
import 'package:tabuapp/services/services_app/user_profile_cache.dart';
import 'package:tabuapp/services/services_app/user_data_notifier.dart';

class UserNameText extends StatefulWidget {
  final String uid;
  final String fallback;        // user_name do post (exibido enquanto carrega)
  final TextStyle? style;
  final bool isOwnUid;

  const UserNameText({
    super.key,
    required this.uid,
    required this.fallback,
    this.style,
    this.isOwnUid = false,
  });

  @override
  State<UserNameText> createState() => _UserNameTextState();
}

class _UserNameTextState extends State<UserNameText> {
  String _name = '';

  @override
  void initState() {
    super.initState();
    // Se é o próprio usuário, usa o notifier (já tem em memória e atualiza live)
    if (widget.isOwnUid && UserDataNotifier.instance.name.isNotEmpty) {
      _name = UserDataNotifier.instance.nameUpper;
      return;
    }
    // Tenta o cache síncrono primeiro (sem rebuild)
    final cached = UserProfileCache.instance.getCached(widget.uid);
    if (cached != null) {
      _name = cached.name.isNotEmpty ? cached.name : widget.fallback;
    } else {
      _name = widget.fallback; // mostra o snapshot enquanto busca
      _load();
    }
  }

  Future<void> _load() async {
    final profile = await UserProfileCache.instance.fetch(widget.uid);
    if (mounted && profile.name.isNotEmpty) {
      setState(() => _name = profile.name);
    }
  }

  @override
  Widget build(BuildContext context) => Text(_name.isNotEmpty ? _name : widget.fallback, style: widget.style);
}