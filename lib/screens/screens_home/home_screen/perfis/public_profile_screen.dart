// lib/screens/screens_home/home_screen/perfis/public_profile_screen.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:tabuapp/controllers/controllers_app/tabu_chat_controller.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/models/gallery_item_model.dart';
import 'package:tabuapp/screens/screens_administrative/chat_screen/chat_screen.dart';
import 'package:tabuapp/screens/screens_administrative/reports_screens/report_user_screen/report_user_screen.dart';
import 'package:tabuapp/screens/screens_home/home_screen/home/full_screen_image.dart';
import 'package:tabuapp/screens/screens_home/home_screen/home/full_screen_video.dart';
import 'package:tabuapp/services/services_app/cached_avatar.dart';
import 'package:tabuapp/services/services_app/chat_request_service.dart';
import 'package:tabuapp/services/services_app/gallery_service.dart';
import 'package:tabuapp/services/services_app/user_data_notifier.dart';
import 'package:tabuapp/models/post_model.dart';
import 'package:tabuapp/models/story_model.dart';
import 'package:tabuapp/models/chat_request_model.dart';
import 'package:tabuapp/screens/screens_home/home_screen/posts/comments_screen.dart';
import 'package:tabuapp/screens/screens_home/home_screen/posts/story_viewer_screen.dart';
import 'package:tabuapp/services/services_app/follow_service.dart';
import 'package:tabuapp/services/services_app/post_service.dart';
import 'package:tabuapp/services/services_app/story_service.dart';
import 'package:tabuapp/services/services_app/video_preload_service.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String? userAvatar;

  const PublicProfileScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.userAvatar,
  });

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen>
    with TickerProviderStateMixin {

  // ── Tabs ───────────────────────────────────────────────────────────────────
  late TabController _tabController;

  // ── Posts ──────────────────────────────────────────────────────────────────
  List<PostModel> _posts = [];
  bool _loading = true;

  // ── Follow / VIP ──────────────────────────────────────────────────────────
  bool _seguindo = false;
  bool _loadingFollow = false;
  bool _vip = false;
  bool _loadingVip = false;

  // ── Chat request ───────────────────────────────────────────────────────────
  ChatRequest? _chatRequest;
  bool _loadingChat = false;

  // ── Stories ────────────────────────────────────────────────────────────────
  List<StoryModel> _userStories = [];
  bool _hasUnviewedStory = false;
  bool _loadingStories = true;

  // ── User data ──────────────────────────────────────────────────────────────
  String _bio = '';
  String _cidade = '';
  String _estado = '';
  int _partys = 0;
  int _followers = 0;
  int _following = 0;
  bool _loadingUser = true;

  // ── Galeria pública ────────────────────────────────────────────────────────
  List<GalleryItem> _galleryItems = [];
  bool _loadingGallery = true;
  bool _hasGallery = false;

  // ── Animations ────────────────────────────────────────────────────────────
  late AnimationController _entryCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';
  bool get _isMe => widget.userId == _myUid;

  // ── Chat helpers ──────────────────────────────────────────────────────────
  String? get _requestStatus => _chatRequest?.status;
  bool get _isPending => _requestStatus == 'pending';
  bool get _isAccepted => _requestStatus == 'accepted';
  bool get _iSent => _chatRequest?.fromUid == _myUid;
  bool get _iReceived => _chatRequest?.toUid == _myUid;

  _ChatBtnConfig get _chatBtnConfig {
    if (_isAccepted) {
      return _ChatBtnConfig(
          icon: Icons.chat_bubble_rounded,
          label: 'MENSAGEM',
          color: TabuColors.rosaPrincipal,
          active: true);
    }
    if (_isPending && _iSent) {
      return _ChatBtnConfig(
          icon: Icons.schedule_rounded,
          label: 'SOLICITADO',
          color: TabuColors.subtle,
          active: false);
    }
    if (_isPending && _iReceived) {
      return _ChatBtnConfig(
          icon: Icons.mark_chat_unread_rounded,
          label: 'ACEITAR',
          color: const Color(0xFF22C55E),
          active: true);
    }
    return _ChatBtnConfig(
        icon: Icons.send_rounded,
        label: 'MENSAGEM',
        color: TabuColors.rosaPrincipal,
        active: true);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: TabuColors.bgAlt,
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
      content: Text(msg,
          style: const TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 11,
              letterSpacing: 0.5,
              color: TabuColors.dim)),
    ));
  }

  void _abrirMenuOpcoes() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (_) => _OptionsSheet(
        userName: widget.userName,
        onDenunciar: () {
          Navigator.pop(context);
          showReportUserScreen(context,
              reportedUserId: widget.userId,
              reportedUserName: widget.userName,
              reporterUid: _myUid);
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_tabController.index == 1) {
            _carregarGaleria();
          }
        });
      }
    });

    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(
            CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    _carregarPosts();
    _carregarDadosUsuario();
    _carregarStories();
    _carregarGaleria();
    _verificarSeSeguindo();
    _verificarSeVip();
    _verificarSolicitacaoChat();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _entryCtrl.dispose();
    // Libera preloads de vídeos da galeria pública
    for (final item in _galleryItems) {
      if (item.type == 'video') {
        VideoPreloadService.instance.evict(item.id);
      }
    }
    super.dispose();
  }

  // ── Chat ──────────────────────────────────────────────────────────────────
  Future<void> _verificarSolicitacaoChat() async {
    if (_myUid.isEmpty || _isMe) return;
    try {
      final req =
          await ChatRequestService().getRequestBetween(_myUid, widget.userId);
      if (mounted) setState(() => _chatRequest = req);
    } catch (_) {
      if (mounted) setState(() => _chatRequest = null);
    }
  }

  Future<void> _handleChatButton() async {
    if (_loadingChat || _myUid.isEmpty) return;
    HapticFeedback.selectionClick();

    if (_isAccepted) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, animation, __) => ChangeNotifierProvider(
            create: (_) => TabuChatController(),
            child: ChatRoomScreen(
              myUid: _myUid,
              otherUid: widget.userId,
              otherName: widget.userName,
              otherAvatar: widget.userAvatar,
            ),
          ),
          transitionsBuilder: (_, animation, __, child) => SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(CurvedAnimation(
                    parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 280),
        ),
      );
      return;
    }

    if (_isPending && _iReceived) {
      setState(() => _loadingChat = true);
      try {
        await ChatRequestService()
            .acceptRequest(_chatRequest!.id, _myUid)
            .timeout(const Duration(seconds: 10));
        await _verificarSolicitacaoChat();
      } on TimeoutException {
        _showSnack('Tempo esgotado. Verifique sua conexão.');
      } catch (_) {
        _showSnack('Erro ao aceitar. Tente novamente.');
      } finally {
        if (mounted) setState(() => _loadingChat = false);
      }
      if (_isAccepted && mounted) _handleChatButton();
      return;
    }

    if (_isPending && _iSent) {
      _showSnack('Solicitação já enviada. Aguarde a resposta.');
      return;
    }

    setState(() => _loadingChat = true);
    try {
      final myName = UserDataNotifier.instance.name;
      final myAvatar = UserDataNotifier.instance.avatar;
      final result = await ChatRequestService()
          .sendRequest(
              fromUid: _myUid,
              toUid: widget.userId,
              fromName: myName,
              fromAvatar: myAvatar)
          .timeout(const Duration(seconds: 10));

      if (mounted && result == 'sent') {
        setState(() {
          _chatRequest = ChatRequest(
            id: ChatRequestService.buildKey(_myUid, widget.userId),
            fromUid: _myUid,
            toUid: widget.userId,
            fromName: myName,
            fromAvatar: myAvatar,
            status: 'pending',
            createdAt: DateTime.now().millisecondsSinceEpoch,
            seen: false,
          );
        });
      }

      switch (result) {
        case 'sent':
          _showSnack('Solicitação enviada! 🎉');
          break;
        case 'exists':
          _showSnack('Solicitação já enviada.');
          await _verificarSolicitacaoChat();
          break;
        case 'accepted':
          await _verificarSolicitacaoChat();
          if (mounted) _handleChatButton();
          break;
      }
    } on TimeoutException {
      _showSnack('Tempo esgotado. Verifique sua conexão.');
    } catch (_) {
      _showSnack('Erro ao enviar. Tente novamente.');
    } finally {
      if (mounted) setState(() => _loadingChat = false);
    }
  }

  // ── Posts ─────────────────────────────────────────────────────────────────
  Future<void> _carregarPosts() async {
    setState(() => _loading = true);
    
    try {
      final posts = await PostService.instance.fetchPostsByUser(widget.userId);
      if (mounted) setState(() { _posts = posts; _loading = false; });
      // No final de _carregarPosts(), após setState:
      for (final p in _posts) {
        if (p.tipo == 'video' && p.mediaUrl != null) {
          VideoPreloadService.instance.preload(p.id, p.mediaUrl!);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Stories ───────────────────────────────────────────────────────────────
  Future<void> _carregarStories() async {
    setState(() => _loadingStories = true);
    try {
      final allStories =
          await StoryService.instance.fetchStoriesByUser(widget.userId);

      final myFollowingSnap = await FirebaseDatabase.instance
          .ref('Users/$_myUid/following/${widget.userId}')
          .get();
      final iFollow =
          myFollowingSnap.exists && myFollowingSnap.value == true;

      final imVipSnap = await FirebaseDatabase.instance
          .ref('Users/${widget.userId}/vip_friends/$_myUid')
          .get();
      final imVip = imVipSnap.exists && imVipSnap.value == true;

      final isMe = widget.userId == _myUid;

      final visible = allStories.where((s) {
        if (isMe) return true;
        switch (s.visibilidade) {
          case 'publico':    return true;
          case 'seguidores': return iFollow;
          case 'vip':        return imVip;
          default:           return true;
        }
      }).toList();

      if (visible.isEmpty) {
        if (mounted) setState(() {
          _userStories = [];
          _hasUnviewedStory = false;
          _loadingStories = false;
        });
        return;
      }

      bool hasUnviewed = false;
      for (final s in visible) {
        final seen = await StoryService.instance.hasViewed(s.id, _myUid);
        if (!seen) { hasUnviewed = true; break; }
      }

      if (mounted) setState(() {
        _userStories = visible;
        _hasUnviewedStory = hasUnviewed;
        _loadingStories = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingStories = false);
    }
  }

  void _abrirStories() {
    if (_userStories.isEmpty) return;
    HapticFeedback.selectionClick();
    Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, animation, __) => StoryViewerScreen(
            storiesByUser: {widget.userId: _userStories},
            initialUserId: widget.userId,
            myUid: _myUid,
            onStoriesChanged: _carregarStories,
          ),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(
              opacity:
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
              child: child),
          transitionDuration: const Duration(milliseconds: 200),
        ));
  }

  // ── Dados do usuário ──────────────────────────────────────────────────────
  Future<void> _carregarDadosUsuario() async {
    setState(() => _loadingUser = true);
    try {
      final results = await Future.wait([
        FirebaseDatabase.instance.ref('Users/${widget.userId}').get(),
        FirebaseDatabase.instance
            .ref('Users/${widget.userId}/followers')
            .get(),
        FirebaseDatabase.instance
            .ref('Users/${widget.userId}/following')
            .get(),
      ]);

      if (results[0].exists && results[0].value != null) {
        final data =
            Map<String, dynamic>.from(results[0].value as Map);
        if (mounted) setState(() {
          _bio = (data['bio'] as String? ?? '').trim();
          _cidade = data['city'] as String? ?? '';
          _estado = data['state'] as String? ?? '';
          _partys = (data['partys'] as num? ?? 0).toInt();
        });
      }

      int fc = 0, fg = 0;
      if (results[1].exists && results[1].value is Map)
        fc = (results[1].value as Map).length;
      if (results[2].exists && results[2].value is Map)
        fg = (results[2].value as Map).length;

      if (mounted) setState(() {
        _followers = fc;
        _following = fg;
        _loadingUser = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingUser = false);
    }
  }

  // ── Galeria pública ────────────────────────────────────────────────────────
  Future<void> _carregarGaleria() async {
    setState(() => _loadingGallery = true);
    try {
      final items =
          await GalleryService.instance.fetchItems(widget.userId);
      debugPrint('🎨 GALERIA PÚBLICA [${widget.userId}]: ${items.length} itens');

      if (mounted) {
        // Evict preloads antigos
        for (final old in _galleryItems) {
          if (old.type == 'video') {
            VideoPreloadService.instance.evict(old.id);
          }
        }

        setState(() {
          _galleryItems = items;
          _hasGallery = items.isNotEmpty;
          _loadingGallery = false;
        });

        // Dispara preload dos vídeos
        for (final item in items) {
          if (item.type == 'video') {
            VideoPreloadService.instance.preload(item.id, item.mediaUrl);
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Erro galeria pública: $e');
      if (mounted) setState(() { _loadingGallery = false; _hasGallery = false; });
    }
  }

  void _abrirGalleryItem(GalleryItem item) {
    HapticFeedback.selectionClick();
    if (item.type == 'video') {
      Navigator.push(
        context,
        FullscreenVideoScreen.route(
          postId: item.id,
          videoUrl: item.mediaUrl,
          thumbUrl: item.thumbUrl,
          userName: widget.userName,
          titulo: 'Galeria',
          duration: item.videoDuration,
        ),
      );
    } else {
      Navigator.push(
        context,
        FullscreenImageScreen.route(
          imageUrl: item.mediaUrl,
          userName: widget.userName,
          titulo: 'Galeria',
        ),
      );
    }
  }

  // ── Follow ────────────────────────────────────────────────────────────────
  Future<void> _verificarSeSeguindo() async {
    if (_myUid.isEmpty || _isMe) return;
    final jaSeguindo =
        await FollowService.instance.isSeguindo(_myUid, widget.userId);
    if (mounted) setState(() => _seguindo = jaSeguindo);
  }

  Future<void> _toggleSeguir() async {
    if (_loadingFollow || _myUid.isEmpty) return;
    setState(() => _loadingFollow = true);
    HapticFeedback.mediumImpact();
    try {
      final novoEstado =
          await FollowService.instance.toggle(_myUid, widget.userId);
      if (mounted) setState(() {
        _seguindo = novoEstado;
        _followers =
            novoEstado ? _followers + 1 : (_followers - 1).clamp(0, 99999);
        _loadingFollow = false;
        if (!novoEstado) _vip = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingFollow = false);
      _showSnack('Erro ao atualizar. Tente novamente.');
    }
  }

  // ── VIP ───────────────────────────────────────────────────────────────────
  Future<void> _verificarSeVip() async {
    if (_myUid.isEmpty || _isMe) return;
    final jaVip =
        await FollowService.instance.isVip(_myUid, widget.userId);
    if (mounted) setState(() => _vip = jaVip);
  }

  Future<void> _toggleVip() async {
    if (_loadingVip || _myUid.isEmpty) return;
    if (!_seguindo && !_vip) {
      _showSnack('Siga o usuário primeiro para adicioná-lo como VIP.');
      return;
    }
    setState(() => _loadingVip = true);
    HapticFeedback.mediumImpact();
    try {
      final novoEstado =
          await FollowService.instance.toggleVip(_myUid, widget.userId);
      if (mounted) setState(() { _vip = novoEstado; _loadingVip = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingVip = false);
    }
  }

  // ── Helpers visuais ───────────────────────────────────────────────────────
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

  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final gradient = _gradientForUser(widget.userId);

    return Scaffold(
      backgroundColor: TabuColors.bg,
      body: Stack(children: [
        Positioned.fill(
            child: CustomPaint(
                painter: _AtmospherePainter(gradient: gradient))),
        Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
                height: 1.5,
                decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [
                  Colors.transparent,
                  TabuColors.rosaDeep,
                  TabuColors.rosaPrincipal,
                  TabuColors.rosaClaro,
                  TabuColors.rosaPrincipal,
                  TabuColors.rosaDeep,
                  Colors.transparent,
                ])))),
        SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildAppBar()),
                  SliverToBoxAdapter(
                      child: _buildHeroSection(gradient)),
                  SliverToBoxAdapter(child: _buildStatsBar()),
                  SliverToBoxAdapter(child: _buildActions()),

                  // ── TABS PUBLICAÇÕES / GALERIA ──────────────────────────
                  SliverToBoxAdapter(child: _buildTabBar()),

                  // ── CONTEÚDO DAS TABS ───────────────────────────────────
                  if (_tabController.index == 0) ...[
                    // PUBLICAÇÕES
                    if (_loading)
                      const _GridSkeleton()
                    else if (_posts.isEmpty)
                      _buildVazioSliver()
                    else
                      _buildPostGrid(),
                  ] else ...[
                    // GALERIA
                    if (_loadingGallery)
                      const _GridSkeleton()
                    else if (!_hasGallery || _galleryItems.isEmpty)
                      _buildGaleriaVaziaSliver()
                    else
                      _buildGalleryGrid(),
                  ],

                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ── App Bar ───────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 16, 0),
      child: Row(children: [
        IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: TabuColors.dim, size: 16),
            onPressed: () => Navigator.pop(context)),
        const Spacer(),
        if (!_isMe)
          GestureDetector(
            onTap: _abrirMenuOpcoes,
            child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                    border:
                        Border.all(color: TabuColors.border, width: 0.8)),
                child: const Icon(Icons.more_horiz,
                    color: TabuColors.subtle, size: 15)),
          )
        else
          Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  border:
                      Border.all(color: TabuColors.border, width: 0.8)),
              child: const Icon(Icons.more_horiz,
                  color: TabuColors.subtle, size: 15)),
      ]),
    );
  }

  // ── Hero ──────────────────────────────────────────────────────────────────
  Widget _buildHeroSection(List<Color> gradient) {
    final localizacao =
        [_cidade, _estado].where((s) => s.isNotEmpty).join(', ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      child: Column(children: [
        GestureDetector(
          onTap: _userStories.isNotEmpty ? _abrirStories : null,
          child: Stack(alignment: Alignment.center, children: [
            if (_userStories.isNotEmpty)
              Container(
                  width: 122,
                  height: 122,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _hasUnviewedStory
                        ? (_vip
                            ? const LinearGradient(
                                colors: [
                                  Color(0xFF6B4A00),
                                  Color(0xFFD4AF37),
                                  Color(0xFFFFE066),
                                  Color(0xFFD4AF37)
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight)
                            : const LinearGradient(
                                colors: [
                                  TabuColors.rosaDeep,
                                  TabuColors.rosaPrincipal,
                                  TabuColors.rosaClaro
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight))
                        : null,
                    color: _userStories.isNotEmpty && !_hasUnviewedStory
                        ? const Color(0xFF3A3A4A)
                        : null,
                    boxShadow: _hasUnviewedStory
                        ? [
                            BoxShadow(
                                color: _vip
                                    ? const Color(0xFFD4AF37)
                                        .withOpacity(0.4)
                                    : TabuColors.glow.withOpacity(0.5),
                                blurRadius: 18,
                                spreadRadius: 2)
                          ]
                        : null,
                  ))
            else
              Container(
                  width: 118,
                  height: 118,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(colors: [
                        TabuColors.rosaDeep.withOpacity(0.0),
                        TabuColors.rosaPrincipal.withOpacity(0.55),
                        TabuColors.rosaClaro.withOpacity(0.25),
                        TabuColors.rosaPrincipal.withOpacity(0.55),
                        TabuColors.rosaDeep.withOpacity(0.0),
                      ]))),
            Container(
                width: _userStories.isNotEmpty ? 114 : 110,
                height: _userStories.isNotEmpty ? 114 : 110,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: TabuColors.bg)),
            CachedAvatar(
                uid: widget.userId,
                name: widget.userName,
                size: 102,
                radius: 51,
                gradient: gradient),
            if (_userStories.isNotEmpty)
              Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _hasUnviewedStory
                            ? (_vip
                                ? const Color(0xFFD4AF37)
                                : TabuColors.rosaPrincipal)
                            : const Color(0xFF3A3A4A),
                        border: Border.all(
                            color: TabuColors.bg, width: 2),
                        boxShadow: _hasUnviewedStory
                            ? [
                                BoxShadow(
                                    color: (_vip
                                            ? const Color(0xFFD4AF37)
                                            : TabuColors.glow)
                                        .withOpacity(0.5),
                                    blurRadius: 8)
                              ]
                            : null,
                      ),
                      child: Icon(
                          _hasUnviewedStory
                              ? Icons.play_arrow_rounded
                              : Icons.check_rounded,
                          color: Colors.white,
                          size: 13))),
            if (_userStories.isEmpty)
              Positioned(
                  bottom: 4,
                  child: Container(
                      width: 40,
                      height: 1,
                      decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [
                        Colors.transparent,
                        TabuColors.rosaPrincipal,
                        Colors.transparent,
                      ])))),
            if (_vip)
              Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1A0A00),
                        border: Border.all(
                            color: const Color(0xFFD4AF37), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFFD4AF37)
                                  .withOpacity(0.4),
                              blurRadius: 8,
                              spreadRadius: 1)
                        ],
                      ),
                      child: const Icon(Icons.star_rounded,
                          color: Color(0xFFD4AF37), size: 13))),
          ]),
        ),
        if (_userStories.isNotEmpty) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _abrirStories,
            child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _hasUnviewedStory
                      ? (_vip
                          ? const Color(0xFF1A0A00)
                          : TabuColors.rosaPrincipal.withOpacity(0.15))
                      : TabuColors.bgCard,
                  border: Border.all(
                    color: _hasUnviewedStory
                        ? (_vip
                            ? const Color(0xFFD4AF37).withOpacity(0.7)
                            : TabuColors.rosaPrincipal.withOpacity(0.5))
                        : const Color(0xFF3A3A4A),
                    width: 0.8,
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                      _hasUnviewedStory
                          ? Icons.auto_awesome_rounded
                          : Icons.visibility_outlined,
                      size: 9,
                      color: _hasUnviewedStory
                          ? (_vip
                              ? const Color(0xFFD4AF37)
                              : TabuColors.rosaPrincipal)
                          : const Color(0xFF3A3A4A)),
                  const SizedBox(width: 5),
                  Text(
                    _hasUnviewedStory ? 'VER STORY' : 'STORY VISTO',
                    style: TextStyle(
                        fontFamily: TabuTypography.bodyFont,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: _hasUnviewedStory
                            ? (_vip
                                ? const Color(0xFFD4AF37)
                                : TabuColors.rosaPrincipal)
                            : const Color(0xFF3A3A4A)),
                  ),
                ])),
          ),
        ] else
          const SizedBox(height: 18),
        Text(
          widget.userName.toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(
              fontFamily: TabuTypography.displayFont,
              fontSize: 27,
              letterSpacing: 8,
              fontWeight: FontWeight.w300,
              color: TabuColors.branco,
              shadows: [
                Shadow(
                    color: TabuColors.rosaPrincipal.withOpacity(0.35),
                    blurRadius: 28)
              ]),
        ),
        if (_vip) ...[
          const SizedBox(height: 8),
          Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1A0A00),
                border: Border.all(
                    color: const Color(0xFFD4AF37).withOpacity(0.5),
                    width: 0.8),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFFD4AF37).withOpacity(0.15),
                      blurRadius: 10)
                ],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.star_rounded,
                    color: Color(0xFFD4AF37), size: 10),
                const SizedBox(width: 6),
                const Text('AMIGO VIP',
                    style: TextStyle(
                        fontFamily: TabuTypography.bodyFont,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.5,
                        color: Color(0xFFD4AF37))),
              ])),
        ],
        const SizedBox(height: 10),
        if (!_loadingUser && localizacao.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(children: [
              Expanded(
                  child: Container(
                      height: 0.5,
                      decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [
                        Colors.transparent,
                        TabuColors.border
                      ])))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.location_on_outlined,
                      color: TabuColors.rosaPrincipal, size: 9),
                  const SizedBox(width: 5),
                  Text(localizacao.toUpperCase(),
                      style: const TextStyle(
                          fontFamily: TabuTypography.bodyFont,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2.5,
                          color: TabuColors.rosaPrincipal)),
                ]),
              ),
              Expanded(
                  child: Container(
                      height: 0.5,
                      decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [
                        TabuColors.border,
                        Colors.transparent
                      ])))),
            ]),
          ),
        if (!_loadingUser && _bio.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(40, 14, 40, 0),
            child: Text(
              _bio,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 13,
                  letterSpacing: 0.3,
                  color: TabuColors.dim.withOpacity(0.8),
                  height: 1.65,
                  fontStyle: FontStyle.italic),
            ),
          ),
        const SizedBox(height: 28),
      ]),
    );
  }

  // ── Stats Bar ─────────────────────────────────────────────────────────────
  Widget _buildStatsBar() {
    if (_loadingUser) {
      return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _MetricsSkeleton());
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: TabuColors.bgCard,
          border: Border.all(
              color: TabuColors.border.withOpacity(0.6), width: 0.8),
        ),
        child: IntrinsicHeight(
          child: Row(children: [
            _StatCell(
                value: _loading ? '—' : '${_posts.length}',
                label: 'POSTS',
                icon: Icons.grid_view_rounded),
            _VertDivider(),
            _StatCell(
                value: '$_followers',
                label: 'SEGUIDORES',
                icon: Icons.people_outline_rounded),
            _VertDivider(),
            _StatCell(
                value: '$_following',
                label: 'SEGUINDO',
                icon: Icons.person_add_outlined),
            _VertDivider(),
            _StatCell(
                value: '$_partys',
                label: 'FESTAS',
                icon: Icons.local_fire_department_outlined,
                accent: true),
          ]),
        ),
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────
  Widget _buildActions() {
    if (_isMe) return const SizedBox(height: 20);
    final cfg = _chatBtnConfig;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Column(children: [
        Row(children: [
          // SEGUIR
          Expanded(
            child: GestureDetector(
              onTap: _toggleSeguir,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                height: 48,
                decoration: BoxDecoration(
                  gradient: _seguindo
                      ? null
                      : const LinearGradient(
                          colors: [
                            TabuColors.rosaDeep,
                            TabuColors.rosaPrincipal
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight),
                  color: _seguindo ? TabuColors.bgCard : null,
                  border: Border.all(
                    color: _seguindo
                        ? TabuColors.border
                        : TabuColors.rosaPrincipal.withOpacity(0.3),
                    width: 0.8,
                  ),
                  boxShadow: _seguindo
                      ? null
                      : [
                          BoxShadow(
                              color: TabuColors.glow.withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 4))
                        ],
                ),
                child: Center(
                  child: _loadingFollow
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              color: _seguindo
                                  ? TabuColors.subtle
                                  : Colors.white,
                              strokeWidth: 1.5))
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                                _seguindo
                                    ? Icons.check_rounded
                                    : Icons.add_rounded,
                                size: 13,
                                color: _seguindo
                                    ? TabuColors.subtle
                                    : TabuColors.branco),
                            const SizedBox(width: 8),
                            Text(_seguindo ? 'SEGUINDO' : 'SEGUIR',
                                style: TextStyle(
                                    fontFamily: TabuTypography.bodyFont,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 3,
                                    color: _seguindo
                                        ? TabuColors.subtle
                                        : TabuColors.branco)),
                          ]),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // CHAT
          Expanded(
            child: GestureDetector(
              onTap: _handleChatButton,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                height: 48,
                decoration: BoxDecoration(
                  gradient: cfg.active &&
                          !_isAccepted &&
                          !(_isPending && _iReceived)
                      ? LinearGradient(colors: [
                          cfg.color.withOpacity(0.15),
                          cfg.color.withOpacity(0.05),
                        ])
                      : null,
                  color: _isAccepted
                      ? cfg.color.withOpacity(0.12)
                      : (_isPending && _iReceived)
                          ? cfg.color.withOpacity(0.10)
                          : !cfg.active
                              ? TabuColors.bgCard
                              : null,
                  border: Border.all(
                    color: cfg.active
                        ? cfg.color.withOpacity(0.5)
                        : TabuColors.border,
                    width: cfg.active ? 1.0 : 0.8,
                  ),
                  boxShadow: cfg.active
                      ? [
                          BoxShadow(
                              color: cfg.color.withOpacity(0.18),
                              blurRadius: 14,
                              offset: const Offset(0, 4))
                        ]
                      : null,
                ),
                child: Center(
                  child: _loadingChat
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              color: cfg.color, strokeWidth: 1.5))
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(cfg.icon, color: cfg.color, size: 13),
                            const SizedBox(width: 8),
                            Text(cfg.label,
                                style: TextStyle(
                                    fontFamily: TabuTypography.bodyFont,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 3,
                                    color: cfg.color)),
                          ]),
                ),
              ),
            ),
          ),
        ]),
        if (!_loadingChat && _chatRequest != null) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                _isPending && _iSent
                    ? 'aguardando resposta...'
                    : _isPending && _iReceived
                        ? 'quer conversar com você'
                        : _isAccepted
                            ? 'conversa ativa'
                            : '',
                style: TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 9,
                    letterSpacing: 0.5,
                    color: _isAccepted
                        ? TabuColors.rosaPrincipal.withOpacity(0.7)
                        : TabuColors.subtle),
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        // VIP
        GestureDetector(
          onTap: _toggleVip,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            height: 44,
            decoration: BoxDecoration(
              color:
                  _vip ? const Color(0xFF1A0A00) : TabuColors.bgCard,
              border: Border.all(
                color: _vip
                    ? const Color(0xFFD4AF37).withOpacity(0.6)
                    : _seguindo
                        ? TabuColors.border
                        : TabuColors.border.withOpacity(0.4),
                width: _vip ? 1 : 0.8,
              ),
              boxShadow: _vip
                  ? [
                      BoxShadow(
                          color: const Color(0xFFD4AF37).withOpacity(0.2),
                          blurRadius: 14,
                          offset: const Offset(0, 3))
                    ]
                  : null,
            ),
            child: Center(
              child: _loadingVip
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          color: Color(0xFFD4AF37), strokeWidth: 1.5))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                          _vip
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          size: 14,
                          color: _vip
                              ? const Color(0xFFD4AF37)
                              : _seguindo
                                  ? TabuColors.subtle
                                  : TabuColors.border),
                      const SizedBox(width: 8),
                      Text(
                          _vip
                              ? 'AMIGO VIP'
                              : 'ADICIONAR COMO VIP',
                          style: TextStyle(
                              fontFamily: TabuTypography.bodyFont,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.5,
                              color: _vip
                                  ? const Color(0xFFD4AF37)
                                  : _seguindo
                                      ? TabuColors.subtle
                                      : TabuColors.border)),
                      if (!_seguindo && !_vip) ...[
                        const SizedBox(width: 8),
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                                border: Border.all(
                                    color:
                                        TabuColors.border.withOpacity(0.4),
                                    width: 0.6)),
                            child: const Text('SIGA PRIMEIRO',
                                style: TextStyle(
                                    fontFamily: TabuTypography.bodyFont,
                                    fontSize: 7,
                                    letterSpacing: 1.5,
                                    color: TabuColors.border))),
                      ],
                    ]),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Tab bar ───────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: TabuColors.bgCard,
          border: Border.all(color: TabuColors.border, width: 0.8),
        ),
        child: TabBar(
          controller: _tabController,
          indicatorColor: TabuColors.rosaPrincipal,
          indicatorWeight: 2,
          labelColor: TabuColors.rosaPrincipal,
          unselectedLabelColor: TabuColors.subtle,
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(
            fontFamily: TabuTypography.bodyFont,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.5,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: TabuTypography.bodyFont,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.5,
          ),
          tabs: [
            Tab(
              icon: const Icon(Icons.grid_view_rounded, size: 14),
              text:
                  'PUBLICAÇÕES${_loading ? '' : ' · ${_posts.length}'}',
            ),
            Tab(
              icon: const Icon(Icons.photo_library_outlined, size: 14),
              text:
                  'GALERIA${_loadingGallery ? '' : _hasGallery ? ' · ${_galleryItems.length}' : ''}',
            ),
          ],
        ),
      ),
    );
  }

  // ── Grids ─────────────────────────────────────────────────────────────────
  Widget _buildPostGrid() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (_, i) => _PostGridTile(post: _posts[i], myUid: _myUid),
          childCount: _posts.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 1.5,
          mainAxisSpacing: 1.5,
          childAspectRatio: 1,
        ),
      ),
    );
  }

  Widget _buildGalleryGrid() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (_, i) {
            final item = _galleryItems[i];
            return _PublicGalleryGridTile(
              item: item,
              isPreloaded:
                  VideoPreloadService.instance.isReady(item.id),
              onTap: () => _abrirGalleryItem(item),
            );
          },
          childCount: _galleryItems.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 1.5,
          mainAxisSpacing: 1.5,
          childAspectRatio: 1,
        ),
      ),
    );
  }

  Widget _buildVazioSliver() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                    border:
                        Border.all(color: TabuColors.border, width: 0.8),
                    color: TabuColors.bgCard),
                child: const Icon(Icons.photo_library_outlined,
                    color: TabuColors.border, size: 20)),
            const SizedBox(height: 16),
            const Text('SEM PUBLICAÇÕES',
                style: TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4,
                    color: TabuColors.subtle)),
          ]),
        ),
      ),
    );
  }

  Widget _buildGaleriaVaziaSliver() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                    border:
                        Border.all(color: TabuColors.border, width: 0.8),
                    color: TabuColors.bgCard),
                child: const Icon(Icons.photo_library_outlined,
                    color: TabuColors.border, size: 20)),
            const SizedBox(height: 16),
            const Text('SEM GALERIA',
                style: TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4,
                    color: TabuColors.subtle)),
            const SizedBox(height: 6),
            const Text('Este usuário ainda não criou uma galeria',
                style: TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 11,
                    color: TabuColors.subtle)),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  PUBLIC GALLERY GRID TILE (somente leitura — sem delete)
// ══════════════════════════════════════════════════════════════════════════════
class _PublicGalleryGridTile extends StatelessWidget {
  final GalleryItem item;
  final VoidCallback onTap;
  final bool isPreloaded;

  const _PublicGalleryGridTile({
    required this.item,
    required this.onTap,
    this.isPreloaded = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: TabuColors.bgCard,
        child: Stack(fit: StackFit.expand, children: [
          if (item.type == 'video' && item.thumbUrl != null)
            Image.network(item.thumbUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fundo())
          else if (item.type == 'foto')
            Image.network(item.mediaUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fundo())
          else
            _fundo(),

          if (item.type == 'video') ...[
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.88,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.25),
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.6),
                  border: Border.all(
                    color: isPreloaded
                        ? const Color(0xFF22C55E)
                        : TabuColors.rosaPrincipal,
                    width: 1.2,
                  ),
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
            if (item.videoDuration != null)
              Positioned(
                bottom: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    _formatDuration(item.videoDuration!),
                    style: const TextStyle(
                        fontFamily: TabuTypography.bodyFont,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                ),
              ),
            // Indicador de pré-carregado
            if (isPreloaded)
              Positioned(
                top: 5,
                left: 5,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF22C55E).withOpacity(0.85),
                  ),
                  child: const Icon(Icons.bolt_rounded,
                      color: Colors.white, size: 11),
                ),
              ),
          ] else
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: const Icon(Icons.photo_outlined,
                    color: Colors.white, size: 12),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _fundo() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2D0010), Color(0xFF7A0028)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      );

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  OPTIONS SHEET
// ══════════════════════════════════════════════════════════════════════════════
class _OptionsSheet extends StatelessWidget {
  final String userName;
  final VoidCallback onDenunciar;

  const _OptionsSheet(
      {required this.userName, required this.onDenunciar});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: TabuColors.bgAlt),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 32,
              height: 2,
              margin: const EdgeInsets.only(top: 14),
              decoration: BoxDecoration(
                  color: TabuColors.border,
                  borderRadius: BorderRadius.circular(1))),
          Container(
              height: 1.5,
              margin: const EdgeInsets.only(top: 12),
              decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [
                Colors.transparent,
                TabuColors.rosaDeep,
                TabuColors.rosaPrincipal,
                TabuColors.rosaClaro,
                TabuColors.rosaPrincipal,
                TabuColors.rosaDeep,
                Colors.transparent,
              ]))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(children: [
              const Icon(Icons.more_horiz,
                  color: TabuColors.subtle, size: 14),
              const SizedBox(width: 10),
              Text(userName.toUpperCase(),
                  style: const TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.5,
                      color: TabuColors.subtle)),
            ]),
          ),
          Container(
              height: 0.5,
              margin:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [
                Colors.transparent,
                TabuColors.border,
                Colors.transparent,
              ]))),
          GestureDetector(
            onTap: onDenunciar,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF3D0A0A).withOpacity(0.5),
                border: Border.all(
                    color: const Color(0xFFE85D5D).withOpacity(0.25),
                    width: 0.7),
              ),
              child: Row(children: [
                Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3D0A0A),
                      border: Border.all(
                          color: const Color(0xFFE85D5D).withOpacity(0.4),
                          width: 0.7),
                    ),
                    child: const Icon(Icons.flag_outlined,
                        color: Color(0xFFE85D5D), size: 13)),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text('DENUNCIAR USUÁRIO',
                          style: TextStyle(
                              fontFamily: TabuTypography.bodyFont,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                              color: Color(0xFFE85D5D))),
                      const SizedBox(height: 2),
                      const Text('Reportar comportamento inadequado',
                          style: TextStyle(
                              fontFamily: TabuTypography.bodyFont,
                              fontSize: 9,
                              letterSpacing: 0.5,
                              color: TabuColors.subtle)),
                    ])),
                const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFFE85D5D), size: 16),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              height: 44,
              decoration: BoxDecoration(
                  color: TabuColors.bgCard,
                  border:
                      Border.all(color: TabuColors.border, width: 0.8)),
              child: const Center(
                  child: Text('CANCELAR',
                      style: TextStyle(
                          fontFamily: TabuTypography.bodyFont,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.5,
                          color: TabuColors.subtle))),
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  CHAT BTN CONFIG
// ══════════════════════════════════════════════════════════════════════════════
class _ChatBtnConfig {
  final IconData icon;
  final String label;
  final Color color;
  final bool active;
  const _ChatBtnConfig(
      {required this.icon,
      required this.label,
      required this.color,
      required this.active});
}

// ══════════════════════════════════════════════════════════════════════════════
//  STAT CELL / DIVIDERS / SKELETONS
// ══════════════════════════════════════════════════════════════════════════════
class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final bool accent;
  const _StatCell(
      {required this.value,
      required this.label,
      required this.icon,
      this.accent = false});

  @override
  Widget build(BuildContext context) {
    final color = accent ? TabuColors.rosaPrincipal : TabuColors.branco;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(children: [
          Icon(icon,
              size: 12,
              color: accent ? TabuColors.rosaPrincipal : TabuColors.subtle),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontFamily: TabuTypography.displayFont,
                  fontSize: 20,
                  letterSpacing: 1,
                  color: color,
                  shadows: accent
                      ? [Shadow(color: TabuColors.glow, blurRadius: 12)]
                      : null)),
          const SizedBox(height: 3),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 7,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                  color: accent
                      ? TabuColors.rosaPrincipal.withOpacity(0.7)
                      : TabuColors.subtle)),
        ]),
      ),
    );
  }
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 0.5, color: TabuColors.border);
}

class _MetricsSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      decoration: BoxDecoration(
          color: TabuColors.bgCard,
          border: Border.all(
              color: TabuColors.border.withOpacity(0.6), width: 0.8)),
      child: Row(
          children: List.generate(7, (i) {
        if (i.isOdd)
          return Container(width: 0.5, color: TabuColors.border);
        return Expanded(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
              Container(
                  width: 20,
                  height: 8,
                  decoration: BoxDecoration(
                      color: TabuColors.border.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 5),
              Container(
                  width: 28,
                  height: 16,
                  decoration: BoxDecoration(
                      color: TabuColors.border.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(3))),
              const SizedBox(height: 4),
              Container(
                  width: 22,
                  height: 6,
                  decoration: BoxDecoration(
                      color: TabuColors.border.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2))),
            ]));
      })),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  POST GRID TILE
// ══════════════════════════════════════════════════════════════════════════════
class _PostGridTile extends StatelessWidget {
  final PostModel post;
  final String myUid;
  const _PostGridTile({required this.post, required this.myUid});

  List<Color> _gradient() {
    final p = [
      [const Color(0xFF3D0018), const Color(0xFF6B0030)],
      [const Color(0xFF1A0030), const Color(0xFF4B005A)],
      [const Color(0xFF2D0010), const Color(0xFF7A0028)],
      [const Color(0xFF0D0020), const Color(0xFF3B0050)],
      [const Color(0xFF2A0012), const Color(0xFFCC0044)],
    ];
    return p[post.userId.codeUnits.fold(0, (a, b) => a + b) % p.length];
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _abrir(BuildContext context) {
    HapticFeedback.selectionClick();

    // ── Vídeo → tela cheia com player ────────────────────────────────────
    if (post.tipo == 'video' && post.mediaUrl != null) {
      Navigator.push(
        context,
        FullscreenVideoScreen.route(
          postId:   post.id,
          videoUrl: post.mediaUrl!,
          thumbUrl: post.thumbUrl,
          userName: post.userName,
          titulo:   post.titulo,
          duration: post.videoDuration,
        ),
      );
      return;
    }

    // ── Foto → tela cheia com zoom ────────────────────────────────────────
    if (post.tipo == 'foto' && post.mediaUrl != null) {
      Navigator.push(
        context,
        FullscreenImageScreen.route(
          imageUrl: post.mediaUrl!,
          userName: post.userName,
          titulo:   post.titulo,
        ),
      );
      return;
    }

    // ── Emoji / Texto → bottom sheet de detalhe ───────────────────────────
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (_) => _PostDetailSheet(post: post, myUid: myUid),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _abrir(context),
      child: Container(
        color: TabuColors.bgCard,
        child: Stack(fit: StackFit.expand, children: [

          // ── Thumbnail / background ───────────────────────────────────────
          if (post.tipo == 'foto' && post.mediaUrl != null)
            Image.network(post.mediaUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fundoGradiente())
          else if (post.tipo == 'video' && post.thumbUrl != null)
            Image.network(post.thumbUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fundoGradiente())
          else
            _fundoGradiente(),

          // ── Overlay do vídeo ─────────────────────────────────────────────
          if (post.tipo == 'video') ...[
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.88,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.3),
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.6),
                  border: Border.all(
                      color: TabuColors.rosaPrincipal, width: 1.2),
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
            if (post.videoDuration != null)
              Positioned(
                bottom: 6,
                right: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    _formatDuration(post.videoDuration!),
                    style: const TextStyle(
                        fontFamily: TabuTypography.bodyFont,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                ),
              ),
          ],

          // ── Emoji centralizado ───────────────────────────────────────────
          if (post.tipo == 'emoji' && post.emoji != null)
            Center(
                child: Text(post.emoji!,
                    style: const TextStyle(fontSize: 30))),

          // ── Texto centralizado ───────────────────────────────────────────
          if (post.tipo == 'texto')
            Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  post.titulo,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.5,
                      height: 1.4),
                ),
              ),
            ),

          // ── Ícone de foto ────────────────────────────────────────────────
          if (post.tipo == 'foto')
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: const Icon(Icons.photo_outlined,
                    color: Colors.white, size: 12),
              ),
            ),

          // ── Vinheta global ───────────────────────────────────────────────
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.88,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.18),
                  ],
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _fundoGradiente() {
    final g = _gradient();
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: g,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
      ),
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();
  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (_, i) => Container(
              color: TabuColors.bgCard,
              child: Opacity(
                  opacity: 1.0 - (i * 0.07).clamp(0.0, 0.55),
                  child: Container(
                      color: TabuColors.border.withOpacity(0.12)))),
          childCount: 9,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 1.5,
          mainAxisSpacing: 1.5,
          childAspectRatio: 1,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  POST DETAIL SHEET
// ══════════════════════════════════════════════════════════════════════════════
class _PostDetailSheet extends StatefulWidget {
  final PostModel post;
  final String myUid;
  const _PostDetailSheet({required this.post, required this.myUid});
  @override
  State<_PostDetailSheet> createState() => _PostDetailSheetState();
}

class _PostDetailSheetState extends State<_PostDetailSheet> {
  late int _likes;
  late int _commentCount;
  bool _liked = false;
  bool _loadingLike = false;
  bool _isVip = false;
  bool get _isOwn => widget.post.userId == widget.myUid;

  @override
  void initState() {
    super.initState();
    _likes = widget.post.likes;
    _commentCount = widget.post.commentCount;
    _checkLike();
    _checkVip();
  }

  Future<void> _checkVip() async {
    if (widget.myUid.isEmpty || _isOwn) return;
    final vip = await FollowService.instance
        .isVip(widget.myUid, widget.post.userId);
    if (mounted) setState(() => _isVip = vip);
  }

  Future<void> _checkLike() async {
    if (widget.myUid.isEmpty) return;
    final liked = await PostService.instance
        .isLikedBy(widget.post.id, widget.myUid);
    if (mounted) setState(() => _liked = liked);
  }

  Future<void> _toggleLike() async {
    if (_loadingLike || widget.myUid.isEmpty) return;
    setState(() => _loadingLike = true);
    HapticFeedback.selectionClick();
    try {
      final nowLiked = await PostService.instance
          .toggleLike(widget.post.id, widget.myUid);
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
    final userData = {
      ...UserDataNotifier.instance.value,
      'uid': widget.myUid
    };
    final newCount = await showCommentsSheet(context,
        post: widget.post, userData: userData);
    if (newCount != null && mounted)
      setState(() => _commentCount = newCount);
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
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final gradient = _gradient();
    final temMidia =
        (post.tipo == 'foto' && post.mediaUrl != null) ||
            post.tipo == 'emoji';
    final displayName =
        _isOwn && UserDataNotifier.instance.name.isNotEmpty
            ? UserDataNotifier.instance.nameUpper
            : post.userName;

    return Container(
      decoration: const BoxDecoration(color: TabuColors.bgAlt),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 32,
            height: 2,
            margin: const EdgeInsets.only(top: 14),
            decoration: BoxDecoration(
                color: TabuColors.border,
                borderRadius: BorderRadius.circular(1))),
        Container(
            height: 1.5,
            margin: const EdgeInsets.only(top: 12),
            decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [
              Colors.transparent,
              TabuColors.rosaDeep,
              TabuColors.rosaPrincipal,
              TabuColors.rosaClaro,
              TabuColors.rosaPrincipal,
              TabuColors.rosaDeep,
              Colors.transparent,
            ]))),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Stack(children: [
              CachedAvatar(
                  uid: post.userId,
                  name: displayName,
                  size: 40,
                  radius: 10,
                  isOwn: _isOwn,
                  glowRing: _isOwn),
              if (_isVip)
                Positioned.fill(
                    child: Container(
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: const Color(0xFFD4AF37)
                                    .withOpacity(0.7),
                                width: 1.5)))),
            ]),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Text(displayName,
                        style: const TextStyle(
                            fontFamily: TabuTypography.bodyFont,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            color: TabuColors.branco)),
                    if (_isOwn) ...[
                      const SizedBox(width: 8),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: TabuColors.rosaPrincipal
                                .withOpacity(0.12),
                            border: Border.all(
                                color: TabuColors.rosaPrincipal
                                    .withOpacity(0.4),
                                width: 0.6),
                          ),
                          child: const Text('VOCÊ',
                              style: TextStyle(
                                  fontFamily: TabuTypography.bodyFont,
                                  fontSize: 7,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2,
                                  color: TabuColors.rosaPrincipal))),
                    ],
                    if (_isVip) ...[
                      const SizedBox(width: 7),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A0A00),
                            border: Border.all(
                                color: const Color(0xFFD4AF37)
                                    .withOpacity(0.6),
                                width: 0.8),
                            boxShadow: [
                              BoxShadow(
                                  color: const Color(0xFFD4AF37)
                                      .withOpacity(0.2),
                                  blurRadius: 6)
                            ],
                          ),
                          child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded,
                                    color: Color(0xFFD4AF37), size: 8),
                                const SizedBox(width: 3),
                                const Text('VIP',
                                    style: TextStyle(
                                        fontFamily:
                                            TabuTypography.bodyFont,
                                        fontSize: 7,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.5,
                                        color: Color(0xFFD4AF37))),
                              ])),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  Text(_formatTime(post.createdAt),
                      style: const TextStyle(
                          fontFamily: TabuTypography.bodyFont,
                          fontSize: 9,
                          letterSpacing: 0.5,
                          color: TabuColors.subtle)),
                ])),
            GestureDetector(
                onTap: () {},
                child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: const Icon(Icons.more_horiz,
                        color: TabuColors.subtle, size: 16))),
          ]),
        ),
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text(post.titulo,
                style: const TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    color: TabuColors.branco,
                    height: 1.4))),
        if (temMidia) _buildMidia(post, gradient),
        if (post.descricao != null && post.descricao!.isNotEmpty)
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Text(post.descricao!,
                  style: TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 13,
                      letterSpacing: 0.2,
                      color: TabuColors.dim.withOpacity(0.9),
                      height: 1.5))),
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Container(
                height: 0.5,
                decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [
                  Colors.transparent,
                  TabuColors.border,
                  Colors.transparent
                ])))),
        Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Row(children: [
              _ActionBtn(
                  icon: _liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  label: '$_likes',
                  color: _liked
                      ? TabuColors.rosaPrincipal
                      : TabuColors.subtle,
                  onTap: _toggleLike),
              _ActionBtn(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: _commentCount > 0
                      ? '$_commentCount'
                      : 'COMENTAR',
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
          height: 200,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            border: Border.all(
                color: TabuColors.border.withOpacity(0.4), width: 0.5),
          ),
          child: Center(
              child: Text(post.emoji!,
                  style: const TextStyle(fontSize: 80))));
    }
    if (post.mediaUrl != null) {
      return SizedBox(
          height: 280,
          width: double.infinity,
          child: Image.network(post.mediaUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                  height: 180,
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight)),
                  child: const Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: TabuColors.subtle, size: 28)))));
    }
    return const SizedBox.shrink();
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
            onTap: onTap,
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: color, size: 16),
                      const SizedBox(width: 6),
                      Text(label,
                          style: TextStyle(
                              fontFamily: TabuTypography.bodyFont,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2,
                              color: color)),
                    ]))),
      );
}

// ══ Painters ═════════════════════════════════════════════════════════════════
class _AtmospherePainter extends CustomPainter {
  final List<Color> gradient;
  const _AtmospherePainter({required this.gradient});
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = TabuColors.bg);
    canvas.drawCircle(
        Offset(size.width * 0.5, -size.height * 0.06),
        size.width * 1.05,
        Paint()
          ..shader = RadialGradient(colors: [
            gradient[1].withOpacity(0.2),
            gradient[1].withOpacity(0.07),
            Colors.transparent,
          ], stops: const [
            0.0,
            0.35,
            1.0
          ]).createShader(Rect.fromCircle(
              center: Offset(size.width * 0.5, -size.height * 0.06),
              radius: size.width * 1.05)));
    canvas.drawCircle(
        Offset(size.width * 0.9, size.height * 0.07),
        size.width * 0.42,
        Paint()
          ..shader = RadialGradient(colors: [
            TabuColors.rosaPrincipal.withOpacity(0.07),
            Colors.transparent,
          ]).createShader(Rect.fromCircle(
              center: Offset(size.width * 0.9, size.height * 0.07),
              radius: size.width * 0.42)));
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()
          ..shader = LinearGradient(colors: [
            Colors.black.withOpacity(0.25),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withOpacity(0.25),
          ], stops: const [
            0.0,
            0.18,
            0.82,
            1.0
          ]).createShader(
              Rect.fromLTWH(0, 0, size.width, size.height)));
  }

  @override
  bool shouldRepaint(_AtmospherePainter old) => false;
}

class _NoisePainter extends CustomPainter {
  final int seed;
  const _NoisePainter({required this.seed});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.03);
    for (int i = 0; i < 50; i++) {
      final x =
          ((seed * 37 + i * 71) % math.max(size.width.toInt(), 1))
              .toDouble();
      final y =
          ((seed * 53 + i * 43) % math.max(size.height.toInt(), 1))
              .toDouble();
      canvas.drawCircle(Offset(x, y), 1.0, paint);
    }
  }

  @override
  bool shouldRepaint(_NoisePainter old) => false;
}

class _VignettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()
          ..shader = RadialGradient(
            center: Alignment.center,
            radius: 0.88,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.22)
            ],
          ).createShader(
              Rect.fromLTWH(0, 0, size.width, size.height)));
  }

  @override
  bool shouldRepaint(_VignettePainter old) => false;
}