// lib/screens/screens_home/home_screen/home/home_screen.dart
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tabuapp/screens/screens_home/home_screen/home/full_screen_image.dart';
import 'package:tabuapp/screens/screens_home/home_screen/home/full_screen_video.dart';
import 'package:tabuapp/screens/screens_home/home_screen/posts/create_gallery_screen.dart';
import 'package:tabuapp/services/services_app/video_preload_service.dart';
import 'package:video_player/video_player.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/models/post_model.dart';
import 'package:tabuapp/models/story_model.dart';
import 'package:tabuapp/models/party_model.dart';
import 'package:tabuapp/screens/screens_administrative/reports_screens/report_post_screen.dart/report_post_screen.dart';
import 'package:tabuapp/screens/screens_home/home_screen/home/edit_party_screen.dart';
import 'package:tabuapp/screens/screens_home/home_screen/posts/comments_screen.dart';
import 'package:tabuapp/screens/screens_home/home_screen/posts/create_post_screen.dart';
import 'package:tabuapp/screens/screens_home/home_screen/posts/create_story_screen.dart';
import 'package:tabuapp/screens/screens_home/home_screen/posts/story_viewer_screen.dart';
import 'package:tabuapp/screens/screens_home/home_screen/perfis/public_profile_screen.dart';
import 'package:tabuapp/screens/screens_administrative/home_screen/create_party_screen.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:tabuapp/services/services_administrative/location_service.dart';
import 'package:tabuapp/services/services_app/post_service.dart';
import 'package:tabuapp/services/services_app/story_service.dart';
import 'package:tabuapp/services/services_app/follow_service.dart';
import 'package:tabuapp/services/services_app/cached_avatar.dart';
import 'package:tabuapp/services/services_app/user_data_notifier.dart';
import 'package:tabuapp/services/services_administrative/party_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  FEED SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final bool isAdmin;
  const HomeScreen({super.key, required this.userData, this.isAdmin = false});

  @override
  State<HomeScreen> createState() => _HomeScreen();
}

class _HomeScreen extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _createMenuController;
  late Animation<double> _createMenuAnim;
  bool _menuOpen = false;

  List<PostModel> _posts = [];
  List<PartyModel> _festas = [];
  Map<String, List<StoryModel>> _stories = {};
  Set<String> _viewedStoryUserIds = {};
  Set<String> _vipUserIds = {};

  ({double latitude, double longitude})? _homeCoords;

  bool _loadingPosts = true;
  bool _loadingStories = true;
  bool _loadingFestas = true;

  // Paginação
  final _scrollController = ScrollController();
  bool _loadingMore = false;

  String get _uid =>
      FirebaseAuth.instance.currentUser?.uid ??
      (widget.userData['uid'] as String? ?? '') ??
      (widget.userData['id'] as String? ?? '');

  @override
  void initState() {
    super.initState();
    UserDataNotifier.instance.init(widget.userData);
    _createMenuController = AnimationController(
      duration: const Duration(milliseconds: 260),
      vsync: this,
    );
    _createMenuAnim = CurvedAnimation(
      parent: _createMenuController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _scrollController.addListener(_onScroll);
    _carregarDados();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _createMenuController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore || _loadingPosts) return;

    final max = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;

    // Carregar mais quando estiver a 300px do fim
    if (current >= max - 300) {
      _carregarMaisPosts();
    }
  }

  Future<void> _carregarMaisPosts() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);

    try {
      final novos = await PostService.instance.fetchPosts(
        limit: 5,
        startAfter: _posts.isNotEmpty ? _posts.last.createdAt : null,
      );

      if (mounted)
        setState(() {
          if (novos.isNotEmpty) {
            _posts.addAll(novos);
          }
          _loadingMore = false;
        });
    } catch (e) {
      debugPrint('_carregarMaisPosts error: $e');
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _carregarDados() async {
    await Future.wait([
      _carregarPosts(),
      _carregarStories(),
      _carregarFestas(),
    ]);
  }

  Future<void> _carregarFestas() async {
    setState(() => _loadingFestas = true);
    try {
      final results = await Future.wait([
        LocationService.instance.getUserHomeCoords(_uid),
        PartyService.instance.fetchFestas(),
      ]);

      final home = results[0] as ({double latitude, double longitude})?;
      var festas = results[1] as List<PartyModel>;

      final now = DateTime.now();
      festas.sort((a, b) {
        final diffA = a.dataInicio.difference(now).abs();
        final diffB = b.dataInicio.difference(now).abs();
        return diffA.compareTo(diffB);
      });

      if (mounted)
        setState(() {
          _homeCoords = home;
          _festas = festas;
          _loadingFestas = false;
        });
    } catch (e) {
      debugPrint('_carregarFestas error: $e');
      if (mounted) setState(() => _loadingFestas = false);
    }
  }

  Future<void> _carregarPosts() async {
    setState(() => _loadingPosts = true);
    try {
      final posts = await PostService.instance.fetchPosts(limit: 30);
      if (mounted)
        setState(() {
          _posts = posts;
          _loadingPosts = false;
        });
    } catch (e) {
      debugPrint('_carregarPosts error: $e');
      if (mounted) setState(() => _loadingPosts = false);
    }
  }

  Future<void> _carregarStories() async {
    setState(() => _loadingStories = true);
    try {
      final followingIds = await FollowService.instance.getFollowing(_uid);
      final vipIds = <String>[];
      await Future.wait(
        followingIds.map((uid) async {
          final snap = await FirebaseDatabase.instance
              .ref('Users/$uid/vip_friends/$_uid')
              .get();
          if (snap.exists && snap.value == true) vipIds.add(uid);
        }),
      );
 
      final grouped = await StoryService.instance.fetchStoriesForUser(
        myUid: _uid,
        followingIds: followingIds,
        vipIds: vipIds,
      );
 
      final viewedUsers = <String>{};
      for (final entry in grouped.entries) {
        bool allViewed = true;
        for (final story in entry.value) {
          final hasSeen = await StoryService.instance.hasViewed(story.id, _uid);
          if (!hasSeen) {
            allViewed = false;
            break;
          }
        }
        if (allViewed) viewedUsers.add(entry.key);
      }
 
      final myVipIds = await FollowService.instance.getVipFriends(_uid);
      if (mounted) {
        setState(() {
          _stories = grouped;
          _viewedStoryUserIds = viewedUsers;
          _vipUserIds = Set<String>.from(myVipIds);
          _loadingStories = false;
        });
      }
 
      // ── PRELOAD: aquece o primeiro vídeo story de cada usuário ─────────
      // Roda em background sem await para não bloquear a UI
      _preloadStoryVideos(grouped);
 
    } catch (e) {
      debugPrint('_carregarStories error: $e');
      if (mounted) setState(() => _loadingStories = false);
    }
  }
 
  void _preloadStoryVideos(Map<String, List<StoryModel>> grouped) {
    for (final stories in grouped.values) {
      for (final story in stories) {
        if (story.isVideo && story.mediaUrl != null) {
          // Apenas o primeiro vídeo de cada usuário (o mais provável de ser aberto)
          VideoPreloadService.instance.preload(story.id, story.mediaUrl!);
          break;
        }
      }
    }
  }

  void _toggleMenu() {
    setState(() => _menuOpen = !_menuOpen);
    _menuOpen
        ? _createMenuController.forward()
        : _createMenuController.reverse();
  }

  void _closeMenu() {
    if (!_menuOpen) return;
    setState(() => _menuOpen = false);
    _createMenuController.reverse();
  }

  void _onCreatePost() {
    _closeMenu();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreatePostScreen(userData: widget.userData),
      ),
    ).then((ok) {
      if (ok == true) _carregarPosts();
    });
  }

  void _onCreateStory() {
    _closeMenu();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) =>
            CreateStoryScreen(userData: widget.userData),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
            ),
            child: child,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 340),
      ),
    ).then((ok) {
      if (ok == true) _carregarStories();
    });
  }

  void _onCreateGallery() {
    _closeMenu();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateGalleryItemScreen(userData: widget.userData),
      ),
    );
  }

  void _onCreateFesta() {
    _closeMenu();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) =>
            CreatePartyScreen(userData: widget.userData),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 250),
      ),
    ).then((ok) {
      if (ok == true) _carregarFestas();
    });
  }

  void _abrirStoryViewer(String userId) {
    final userStories = _stories[userId];
    if (userStories == null || userStories.isEmpty) return;
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => StoryViewerScreen(
          storiesByUser: _stories,
          initialUserId: userId,
          myUid: _uid,
          onStoriesChanged: _carregarStories,
        ),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final name = (widget.userData['name'] as String? ?? 'Você').toUpperCase();
    final avatarUrl = widget.userData['avatar'] as String? ?? '';

    return Scaffold(
      backgroundColor: TabuColors.bg,
      body: GestureDetector(
        onTap: _closeMenu,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _FeedBg())),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 3,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      TabuColors.rosaDeep,
                      TabuColors.rosaPrincipal,
                      TabuColors.rosaClaro,
                      TabuColors.rosaPrincipal,
                      TabuColors.rosaDeep,
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: RefreshIndicator(
                color: TabuColors.rosaPrincipal,
                backgroundColor: TabuColors.bgAlt,
                onRefresh: _carregarDados,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildAppBar(name, avatarUrl)),
                    SliverToBoxAdapter(child: _buildCreateBox(avatarUrl)),
                    SliverToBoxAdapter(child: _buildFestasSection()),
                    SliverToBoxAdapter(child: _buildStoriesSection()),
                    SliverToBoxAdapter(
                      child: Container(
                        height: 0.5,
                        color: TabuColors.border,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),

                    if (_loadingPosts)
                      const SliverToBoxAdapter(child: _PostsSkeleton())
                    else if (_posts.isEmpty)
                      SliverToBoxAdapter(child: _buildPostsVazio())
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => _PostCard(
                            post: _posts[i],
                            uid: _uid,
                            userData: widget.userData,
                          ),
                          childCount: _posts.length,
                        ),
                      ),

                    // Indicador de carregamento no final
                    if (_loadingMore)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color:
                                    TabuColors.rosaPrincipal.withOpacity(0.5),
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),
            ),
            if (_menuOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _closeMenu,
                  child: Container(color: Colors.black.withOpacity(0.45)),
                ),
              ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 52,
              right: 16,
              child: IgnorePointer(
                ignoring: !_menuOpen,   // ← desliga hit-test quando menu fechado
                child: _buildCreateMenu(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(String name, String avatarUrl) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 8),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [TabuColors.rosaPrincipal, TabuColors.rosaClaro],
            ).createShader(b),
            child: const Text(
              'TABU',
              style: TextStyle(
                fontFamily: TabuTypography.displayFont,
                fontSize: 28,
                letterSpacing: 6,
                color: Colors.white,
              ),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _toggleMenu,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _menuOpen ? TabuColors.rosaPrincipal : TabuColors.bgCard,
                border: Border.all(
                  color: _menuOpen
                      ? TabuColors.rosaPrincipal
                      : TabuColors.borderMid,
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedRotation(
                    turns: _menuOpen ? 0.125 : 0,
                    duration: const Duration(milliseconds: 260),
                    child: const Icon(
                      Icons.add,
                      color: TabuColors.branco,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'CRIAR',
                    style: TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.5,
                      color: TabuColors.branco,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          _SquircleAvatar(
            size: 36,
            radius: 8,
            avatarUrl: avatarUrl,
            gradient: const [TabuColors.rosaDeep, TabuColors.rosaPrincipal],
            ringColor: TabuColors.borderMid,
          ),
        ],
      ),
    );
  }

  Widget _buildCreateMenu() {
    return AnimatedBuilder(
      animation: _createMenuAnim,
      builder: (_, __) {
        final v = _createMenuAnim.value;
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, -12 * (1 - v)),
            child: Container(
              width: 180,
              decoration: BoxDecoration(
                color: TabuColors.bgAlt,
                border: Border.all(color: TabuColors.borderMid, width: 0.8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: TabuColors.glow.withOpacity(0.15),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 2,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          TabuColors.rosaDeep,
                          TabuColors.rosaPrincipal,
                          TabuColors.rosaDeep,
                        ],
                      ),
                    ),
                  ),
                  _MenuOption(
                    icon: Icons.grid_view_rounded,
                    label: 'POST',
                    sublabel: 'Foto, vídeo ou texto',
                    onTap: _onCreatePost,
                  ),
                  Container(height: 0.5, color: TabuColors.border),
                  _MenuOption(
                    icon: Icons.auto_awesome_rounded,
                    label: 'STORY',
                    sublabel: 'Desaparece em 24h',
                    onTap: _onCreateStory,
                    accent: true,
                  ),
                  Container(height: 0.5, color: TabuColors.border),
                  _MenuOption(
                    icon: Icons.photo_library_outlined,
                    label: 'GALERIA',
                    sublabel: 'Apenas no seu perfil',
                    onTap: _onCreateGallery,
                  ),
                  if (widget.isAdmin) ...[
                    Container(height: 0.5, color: TabuColors.border),
                    _MenuOption(
                      icon: Icons.local_fire_department_rounded,
                      label: 'FESTA',
                      sublabel: 'Evento para todos',
                      onTap: _onCreateFesta,
                      accent: true,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCreateBox(String avatarUrl) {
    return GestureDetector(
      onTap: _onCreatePost,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: TabuColors.bgCard,
          border: Border.all(color: TabuColors.border, width: 0.8),
        ),
        child: Row(
          children: [
            _SquircleAvatar(
              size: 40,
              radius: 9,
              avatarUrl: avatarUrl,
              gradient: const [TabuColors.rosaDeep, TabuColors.rosaPrincipal],
              ringColor: TabuColors.border,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: TabuColors.bgAlt,
                  border: Border.all(color: TabuColors.border, width: 0.8),
                ),
                alignment: Alignment.centerLeft,
                child: const Text(
                  'O que está rolando?',
                  style: TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 13,
                    color: TabuColors.subtle,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _onCreateStory,
              child: const Icon(
                Icons.photo_camera_outlined,
                color: TabuColors.rosaPrincipal,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Festas ─────────────────────────────────────────────────────────────────
  Widget _buildFestasSection() {
    // Dentro de _buildFestasSection()
    final festasVisiveis = _festas;
    

    if (!_loadingFestas && festasVisiveis.isEmpty)
      return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                color: TabuColors.rosaPrincipal,
                size: 12,
              ),
              const SizedBox(width: 8),
              const Text(
                'FESTAS',
                style: TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                  color: TabuColors.rosaPrincipal,
                ),
              ),
              const SizedBox(width: 8),
              if (!_loadingFestas &&
                  _homeCoords != null &&
                  festasVisiveis.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: TabuColors.rosaPrincipal.withOpacity(0.12),
                    border: Border.all(
                      color: TabuColors.rosaPrincipal.withOpacity(0.4),
                      width: 0.6,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.near_me_rounded,
                        color: TabuColors.rosaPrincipal,
                        size: 8,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${festasVisiveis.length} PRÓXIMAS',
                        style: const TextStyle(
                          fontFamily: TabuTypography.bodyFont,
                          fontSize: 7,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: TabuColors.rosaPrincipal,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 8),
              Expanded(child: Container(height: 0.5, color: TabuColors.border)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_loadingFestas)
          SizedBox(
            height: 190,
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: TabuColors.rosaPrincipal.withOpacity(0.5),
                  strokeWidth: 1.5,
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemCount: festasVisiveis.length,
              itemBuilder: (_, i) => _FestaCard(
                festa: festasVisiveis[i],
                myUid: _uid,
                isAdmin: widget.isAdmin,
                userData: widget.userData,
                homeCoords: _homeCoords,
                onRefresh: _carregarFestas,
              ),
            ),
          ),
        const SizedBox(height: 8),
        Container(height: 0.5, color: TabuColors.border),
      ],
    );
  }

  Widget _buildStoriesSection() {
    final otherUserIds = _stories.keys.where((id) => id != _uid).toList();
    final temMeuStory = _stories.containsKey(_uid);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: TabuColors.rosaPrincipal,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'STORIES',
                style: TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                  color: TabuColors.rosaPrincipal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Container(height: 0.5, color: TabuColors.border)),
            ],
          ),
        ),
        SizedBox(
          height: 102,
          child: _loadingStories
              ? const _StoriesSkeleton()
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemCount: 1 + otherUserIds.length,
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      // ✅ PRIMEIRO BUBBLE (SEU) - SEMPRE abre visualizador
                      return _StoryBubble(
                        uid: _uid,
                        userData: widget.userData,
                        name: UserDataNotifier.instance.nameUpper.isNotEmpty
                            ? UserDataNotifier.instance.nameUpper
                            : (widget.userData['name'] as String? ?? 'EU')
                                .toUpperCase(),
                        avatarUrl: UserDataNotifier.instance.avatar.isNotEmpty
                            ? UserDataNotifier.instance.avatar
                            : (widget.userData['avatar'] as String? ?? ''),
                        isOwn: true,
                        hasNew: temMeuStory,
                        viewed: _viewedStoryUserIds.contains(_uid),
                        isVip: false,
                        onTap: () => _abrirStoryViewer(_uid), // ✅ CORRIGIDO
                      );
                    }
                    final userId = otherUserIds[i - 1];
                    final firstStory = _stories[userId]!.first;
                    return _StoryBubble(
                      uid: userId,
                      userData: widget.userData,
                      name: firstStory.userName.toUpperCase(),
                      avatarUrl: firstStory.userAvatar ?? '',
                      isOwn: false,
                      hasNew: true,
                      viewed: _viewedStoryUserIds.contains(userId),
                      isVip: _vipUserIds.contains(userId),
                      onTap: () => _abrirStoryViewer(userId),
                    );
                  },
                ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _buildPostsVazio() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.dynamic_feed_rounded,
              color: TabuColors.border,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'NENHUM POST AINDA',
              style: TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
                color: TabuColors.subtle,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Seja o primeiro a publicar!',
              style: TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 12,
                color: TabuColors.subtle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  FESTA CARD  (sem alterações)
// ══════════════════════════════════════════════════════════════════════════════
class _FestaCard extends StatelessWidget {
  final PartyModel festa;
  final String myUid;
  final bool isAdmin;
  final Map<String, dynamic> userData;
  final ({double latitude, double longitude})? homeCoords;
  final VoidCallback onRefresh;

  const _FestaCard({
    required this.festa,
    required this.myUid,
    required this.isAdmin,
    required this.userData,
    required this.homeCoords,
    required this.onRefresh,
  });

  String? get _distLabel {
    if (homeCoords == null || !festa.canShowDistance) return null;
    final km = LocationService.distanceKm(
      homeCoords!.latitude,
      homeCoords!.longitude,
      festa.latitude!,
      festa.longitude!,
    );
    return LocationService.formatDistance(km);
  }

  @override
  Widget build(BuildContext context) {
    final temBanner = festa.bannerUrl != null && festa.bannerUrl!.isNotEmpty;
    final dist = _distLabel;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          barrierColor: Colors.black.withOpacity(0.8),
          builder: (_) => _FestaDetailSheet(
            festa: festa,
            myUid: myUid,
            isAdmin: isAdmin,
            userData: userData,
            homeCoords: homeCoords,
            onRefresh: onRefresh,
          ),
        );
      },
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          color: TabuColors.bgCard,
          border: Border.all(color: TabuColors.borderMid, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: TabuColors.glow.withOpacity(0.1),
              blurRadius: 14,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: temBanner
                  ? Image.network(festa.bannerUrl!,
                      fit: BoxFit.cover, errorBuilder: (_, __, ___) => _bg())
                  : _bg(),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.88)
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.25, 1.0],
                  ),
                ),
              ),
            ),
            if (dist != null)
              Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        border: Border.all(
                            color: TabuColors.rosaPrincipal.withOpacity(0.6),
                            width: 0.8)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.near_me_rounded,
                          color: TabuColors.rosaPrincipal, size: 9),
                      const SizedBox(width: 4),
                      Text(dist,
                          style: const TextStyle(
                              fontFamily: TabuTypography.bodyFont,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              color: TabuColors.rosaPrincipal)),
                    ]),
                  )),
            Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.12), width: 0.5)),
                  child: Text(
                      '${_fh(festa.dataInicio)} – ${_fh(festa.dataFim)}',
                      style: const TextStyle(
                          fontFamily: TabuTypography.bodyFont,
                          fontSize: 8,
                          letterSpacing: 1,
                          color: Colors.white70)),
                )),
            Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          color: TabuColors.rosaPrincipal,
                          child: Text(_fd(festa.dataInicio),
                              style: const TextStyle(
                                  fontFamily: TabuTypography.bodyFont,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2,
                                  color: Colors.white))),
                      const SizedBox(height: 6),
                      Text(festa.nome.toUpperCase(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: TabuTypography.displayFont,
                              fontSize: 16,
                              letterSpacing: 1.5,
                              color: Colors.white,
                              height: 1.2)),
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(
                            festa.hasLocal
                                ? Icons.location_on_outlined
                                : Icons.location_off_outlined,
                            color: festa.hasLocal
                                ? TabuColors.rosaClaro
                                : TabuColors.subtle,
                            size: 9),
                        const SizedBox(width: 3),
                        Expanded(
                            child: Text(
                                festa.hasLocal
                                    ? festa.local!
                                    : 'Local não confirmado',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontFamily: TabuTypography.bodyFont,
                                    fontSize: 9,
                                    fontStyle: festa.hasLocal
                                        ? FontStyle.normal
                                        : FontStyle.italic,
                                    color: festa.hasLocal
                                        ? TabuColors.rosaClaro
                                        : TabuColors.subtle))),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        _FB(Icons.star_outline_rounded, festa.interessados,
                            'interesse'),
                        const SizedBox(width: 8),
                        _FB(Icons.check_circle_outline_rounded,
                            festa.confirmados, 'vão'),
                        const SizedBox(width: 8),
                        _FB(Icons.chat_bubble_outline_rounded,
                            festa.commentCount, 'com'),
                      ]),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _bg() => Container(
      decoration: const BoxDecoration(
          gradient: LinearGradient(
              colors: [Color(0xFF3D0018), Color(0xFF6B0030)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight)));

  String _fd(DateTime dt) {
    const d = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];
    const m = [
      'JAN',
      'FEV',
      'MAR',
      'ABR',
      'MAI',
      'JUN',
      'JUL',
      'AGO',
      'SET',
      'OUT',
      'NOV',
      'DEZ'
    ];
    return '${d[dt.weekday - 1]}, ${dt.day} ${m[dt.month - 1]}';
  }

  String _fh(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _FB extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  const _FB(this.icon, this.count, this.label);
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white54, size: 10),
        const SizedBox(width: 3),
        Text('$count $label',
            style: const TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 8,
                letterSpacing: 0.3,
                color: Colors.white54)),
      ]);
}

// ══════════════════════════════════════════════════════════════════════════════
//  FESTA DETAIL SHEET  (sem alterações - mantém o código original completo)
// ══════════════════════════════════════════════════════════════════════════════
class _FestaDetailSheet extends StatefulWidget {
  final PartyModel festa;
  final String myUid;
  final bool isAdmin;
  final Map<String, dynamic> userData;
  final ({double latitude, double longitude})? homeCoords;
  final VoidCallback onRefresh;

  const _FestaDetailSheet({
    required this.festa,
    required this.myUid,
    required this.isAdmin,
    required this.userData,
    required this.homeCoords,
    required this.onRefresh,
  });

  @override
  State<_FestaDetailSheet> createState() => _FestaDetailSheetState();
}

class _FestaDetailSheetState extends State<_FestaDetailSheet> {
  FestaPresenca _presenca = FestaPresenca.nenhuma;
  bool _loadingPres = false;
  List<Map<String, dynamic>> _comentarios = [];
  bool _loadingComs = true;
  final _comCtrl = TextEditingController();
  final _comFocus = FocusNode();
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _carregarPresenca();
    _carregarComentarios();
  }

  @override
  void dispose() {
    _comCtrl.dispose();
    _comFocus.dispose();
    super.dispose();
  }

  Future<void> _carregarPresenca() async {
    if (widget.myUid.isEmpty) return;
    final p =
        await PartyService.instance.getPresenca(widget.festa.id, widget.myUid);
    if (mounted) setState(() => _presenca = p);
  }

  Future<void> _carregarComentarios() async {
    setState(() => _loadingComs = true);
    try {
      final list =
          await PartyService.instance.fetchComentarios(widget.festa.id);
      if (mounted)
        setState(() {
          _comentarios = list;
          _loadingComs = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loadingComs = false);
    }
  }

  Future<void> _togglePresenca(FestaPresenca nova) async {
    if (_loadingPres) return;
    setState(() => _loadingPres = true);
    HapticFeedback.selectionClick();
    try {
      if (nova == _presenca) {
        await PartyService.instance
            .togglePresenca(widget.festa.id, widget.myUid, _presenca);
        if (mounted)
          setState(() {
            _presenca = FestaPresenca.nenhuma;
            _loadingPres = false;
          });
      } else {
        FestaPresenca atual = _presenca;
        while (atual != nova) {
          atual = await PartyService.instance
              .togglePresenca(widget.festa.id, widget.myUid, atual);
        }
        if (mounted)
          setState(() {
            _presenca = nova;
            _loadingPres = false;
          });
      }
      widget.onRefresh();
    } catch (_) {
      if (mounted) setState(() => _loadingPres = false);
    }
  }

  Future<void> _enviarComentario() async {
    final texto = _comCtrl.text.trim();
    if (texto.isEmpty || _enviando) return;
    setState(() => _enviando = true);
    HapticFeedback.selectionClick();
    try {
      await PartyService.instance.addComentario(
        festaId: widget.festa.id,
        uid: widget.myUid,
        userName: UserDataNotifier.instance.name.isNotEmpty
            ? UserDataNotifier.instance.name
            : 'Usuário',
        userAvatar: UserDataNotifier.instance.avatar.isNotEmpty
            ? UserDataNotifier.instance.avatar
            : null,
        texto: texto,
      );
      _comCtrl.clear();
      FocusScope.of(context).unfocus();
      await _carregarComentarios();
      if (mounted) setState(() => _enviando = false);
    } catch (_) {
      if (mounted) setState(() => _enviando = false);
    }
  }

  String? get _distLabel {
    if (widget.homeCoords == null || !widget.festa.canShowDistance) return null;
    final km = LocationService.distanceKm(
        widget.homeCoords!.latitude,
        widget.homeCoords!.longitude,
        widget.festa.latitude!,
        widget.festa.longitude!);
    return LocationService.formatDistance(km);
  }

  @override
  Widget build(BuildContext context) {
    final festa = widget.festa;
    final temBanner = festa.bannerUrl != null && festa.bannerUrl!.isNotEmpty;
    final podeGerenciar = festa.creatorId == widget.myUid || widget.isAdmin;
    final dist = _distLabel;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.96,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
            color: TabuColors.bgAlt,
            border: Border(
                top: BorderSide(color: TabuColors.rosaPrincipal, width: 1.5))),
        child: Column(children: [
          Container(
              width: 36,
              height: 3,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                  color: TabuColors.border,
                  borderRadius: BorderRadius.circular(2))),
          Expanded(
              child: ListView(controller: ctrl, children: [
            if (temBanner)
              SizedBox(
                  height: 200,
                  child: Image.network(festa.bannerUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(height: 200, color: TabuColors.bgCard))),
            Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          color: TabuColors.rosaPrincipal,
                          child: Text(_fd(festa.dataInicio),
                              style: const TextStyle(
                                  fontFamily: TabuTypography.bodyFont,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2,
                                  color: Colors.white))),
                      const SizedBox(height: 10),
                      Text(festa.nome.toUpperCase(),
                          style: const TextStyle(
                              fontFamily: TabuTypography.displayFont,
                              fontSize: 26,
                              letterSpacing: 3,
                              color: TabuColors.branco)),
                      const SizedBox(height: 10),
                      Row(children: [
                        Icon(
                            festa.hasLocal
                                ? Icons.location_on_outlined
                                : Icons.location_off_outlined,
                            color: festa.hasLocal
                                ? TabuColors.rosaPrincipal
                                : TabuColors.subtle,
                            size: 13),
                        const SizedBox(width: 5),
                        Expanded(
                            child: Text(
                                festa.hasLocal
                                    ? festa.local!
                                    : 'Local não confirmado',
                                style: TextStyle(
                                    fontFamily: TabuTypography.bodyFont,
                                    fontSize: 13,
                                    fontStyle: festa.hasLocal
                                        ? FontStyle.normal
                                        : FontStyle.italic,
                                    color: festa.hasLocal
                                        ? TabuColors.rosaClaro
                                        : TabuColors.subtle))),
                        if (dist != null) ...[
                          const SizedBox(width: 8),
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                  color: TabuColors.rosaPrincipal
                                      .withOpacity(0.12),
                                  border: Border.all(
                                      color: TabuColors.rosaPrincipal
                                          .withOpacity(0.5),
                                      width: 0.8)),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.near_me_rounded,
                                        color: TabuColors.rosaPrincipal,
                                        size: 11),
                                    const SizedBox(width: 5),
                                    Text(dist,
                                        style: const TextStyle(
                                            fontFamily: TabuTypography.bodyFont,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1,
                                            color: TabuColors.rosaPrincipal)),
                                  ])),
                        ],
                      ]),
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.schedule_outlined,
                            color: TabuColors.subtle, size: 13),
                        const SizedBox(width: 5),
                        Text('${_fh(festa.dataInicio)} – ${_fh(festa.dataFim)}',
                            style: const TextStyle(
                                fontFamily: TabuTypography.bodyFont,
                                fontSize: 12,
                                color: TabuColors.dim)),
                      ]),
                      const SizedBox(height: 20),
                      Row(children: [
                        Expanded(
                            child: _PB(
                                icon: Icons.star_rounded,
                                label: 'INTERESSADO',
                                count: festa.interessados,
                                ativo: _presenca == FestaPresenca.interessado,
                                loading: _loadingPres,
                                color: TabuColors.rosaClaro,
                                onTap: () => _togglePresenca(
                                    FestaPresenca.interessado))),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _PB(
                                icon: Icons.check_circle_rounded,
                                label: 'VOU!',
                                count: festa.confirmados,
                                ativo: _presenca == FestaPresenca.confirmado,
                                loading: _loadingPres,
                                color: const Color(0xFF4ECDC4),
                                onTap: () =>
                                    _togglePresenca(FestaPresenca.confirmado))),
                      ]),
                      const SizedBox(height: 20),
                      Container(height: 0.5, color: TabuColors.border),
                      const SizedBox(height: 16),
                      if (festa.descricao.isNotEmpty) ...[
                        const Text('SOBRE A NOITE',
                            style: TextStyle(
                                fontFamily: TabuTypography.bodyFont,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 3,
                                color: TabuColors.subtle)),
                        const SizedBox(height: 10),
                        Text(festa.descricao,
                            style: const TextStyle(
                                fontFamily: TabuTypography.bodyFont,
                                fontSize: 14,
                                color: TabuColors.dim,
                                height: 1.6)),
                        const SizedBox(height: 16),
                        Container(height: 0.5, color: TabuColors.border),
                        const SizedBox(height: 16),
                      ],
                      Row(children: [
                        CachedAvatar(
                            uid: festa.creatorId,
                            name: festa.creatorName,
                            size: 30,
                            radius: 8),
                        const SizedBox(width: 10),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('CRIADO POR',
                                  style: TextStyle(
                                      fontFamily: TabuTypography.bodyFont,
                                      fontSize: 8,
                                      letterSpacing: 2,
                                      color: TabuColors.subtle)),
                              Text(festa.creatorName.toUpperCase(),
                                  style: const TextStyle(
                                      fontFamily: TabuTypography.bodyFont,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.5,
                                      color: TabuColors.branco)),
                            ]),
                      ]),
                      if (podeGerenciar) ...[
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(
                              child: GestureDetector(
                            onTap: () async {
                              Navigator.pop(context);
                              final ok = await Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (_, animation, __) =>
                                        EditPartyScreen(
                                            festa: festa,
                                            userData: widget.userData),
                                    transitionsBuilder: (_, animation, __,
                                            child) =>
                                        FadeTransition(
                                            opacity: CurvedAnimation(
                                                parent: animation,
                                                curve: Curves.easeOut),
                                            child: child),
                                    transitionDuration:
                                        const Duration(milliseconds: 250),
                                  ));
                              if (ok == true) widget.onRefresh();
                            },
                            child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                    color: TabuColors.bgCard,
                                    border: Border.all(
                                        color: TabuColors.rosaPrincipal
                                            .withOpacity(0.5),
                                        width: 0.8)),
                                child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.edit_rounded,
                                          color: TabuColors.rosaPrincipal,
                                          size: 14),
                                      SizedBox(width: 7),
                                      Text('EDITAR',
                                          style: TextStyle(
                                              fontFamily:
                                                  TabuTypography.bodyFont,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 2.5,
                                              color: TabuColors.rosaPrincipal)),
                                    ])),
                          )),
                          const SizedBox(width: 10),
                          Expanded(
                              child: GestureDetector(
                            onTap: () async {
                              Navigator.pop(context);
                              await PartyService.instance.deleteFesta(festa.id);
                              widget.onRefresh();
                            },
                            child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                    color: const Color(0xFF3D0A0A),
                                    border: Border.all(
                                        color: const Color(0xFFE85D5D)
                                            .withOpacity(0.4),
                                        width: 0.8)),
                                child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.delete_outline_rounded,
                                          color: Color(0xFFE85D5D), size: 14),
                                      SizedBox(width: 7),
                                      Text('EXCLUIR',
                                          style: TextStyle(
                                              fontFamily:
                                                  TabuTypography.bodyFont,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 2.5,
                                              color: Color(0xFFE85D5D))),
                                    ])),
                          )),
                        ]),
                      ],
                      const SizedBox(height: 20),
                      Container(height: 0.5, color: TabuColors.border),
                      const SizedBox(height: 16),
                      const Text('COMENTÁRIOS',
                          style: TextStyle(
                              fontFamily: TabuTypography.bodyFont,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 3,
                              color: TabuColors.rosaPrincipal)),
                      const SizedBox(height: 14),
                      if (_loadingComs)
                        const Center(
                            child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    color: TabuColors.rosaPrincipal,
                                    strokeWidth: 1.5)))
                      else if (_comentarios.isEmpty)
                        const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('Seja o primeiro a comentar',
                                style: TextStyle(
                                    fontFamily: TabuTypography.bodyFont,
                                    fontSize: 11,
                                    color: TabuColors.subtle)))
                      else
                        ..._comentarios.map((com) => _CT(data: com)),
                      const SizedBox(height: 80),
                    ])),
          ])),
          Container(
            decoration: const BoxDecoration(
                color: TabuColors.bgAlt,
                border: Border(
                    top: BorderSide(color: TabuColors.border, width: 0.5))),
            padding: EdgeInsets.fromLTRB(
                16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
            child: Row(children: [
              CachedAvatar(
                  uid: widget.myUid,
                  name: UserDataNotifier.instance.name,
                  size: 30,
                  radius: 8,
                  isOwn: true),
              const SizedBox(width: 10),
              Expanded(
                  child: Container(
                decoration: BoxDecoration(
                    color: TabuColors.bgCard,
                    border: Border.all(color: TabuColors.border, width: 0.8)),
                child: TextField(
                  controller: _comCtrl,
                  focusNode: _comFocus,
                  style: const TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 13,
                      color: TabuColors.branco),
                  cursorColor: TabuColors.rosaPrincipal,
                  decoration: const InputDecoration(
                      hintText: 'Comentar...',
                      border: InputBorder.none,
                      isDense: true,
                      hintStyle: TextStyle(
                          fontFamily: TabuTypography.bodyFont,
                          fontSize: 13,
                          color: TabuColors.subtle),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  onSubmitted: (_) => _enviarComentario(),
                ),
              )),
              const SizedBox(width: 8),
              GestureDetector(
                  onTap: _enviando ? null : _enviarComentario,
                  child: Container(
                      width: 36,
                      height: 36,
                      color: TabuColors.rosaPrincipal,
                      child: _enviando
                          ? const Center(
                              child: SizedBox(
                                  width: 13,
                                  height: 13,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 1.5)))
                          : const Icon(Icons.send_rounded,
                              color: Colors.white, size: 15))),
            ]),
          ),
        ]),
      ),
    );
  }

  String _fd(DateTime dt) {
    const m = [
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez'
    ];
    return '${dt.day.toString().padLeft(2, '0')} ${m[dt.month - 1]} · ${dt.year}';
  }

  String _fh(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// ══════════════════════════════════════════════════════════════════════════════
//  POST CARD — com suporte completo a vídeo
// ══════════════════════════════════════════════════════════════════════════════
class _PostCard extends StatefulWidget {
  final PostModel post;
  final String uid;
  final Map<String, dynamic> userData;
  const _PostCard({
    required this.post,
    required this.uid,
    required this.userData,
    super.key,
  });
  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _liked = false;
  late int _likes;
  late int _commentCount;
  bool _loadingLike = false;
  bool _isVip = false;

  @override
  void initState() {
    super.initState();
    _likes = widget.post.likes;
    _commentCount = widget.post.commentCount;
    _checkLike();
    _checkVip();

    // ── PRÉ-CARREGAMENTO: inicia em background ao montar o card ──────────
    if (widget.post.tipo == 'video' && widget.post.mediaUrl != null) {
      VideoPreloadService.instance.preload(
        widget.post.id,
        widget.post.mediaUrl!,
      );
    }
  }

  @override
  void dispose() {
    // Evict só quando o post sair completamente da tela.
    // Comentar esta linha se quiser cache mais agressivo (mantém todos na memória).
    if (widget.post.tipo == 'video') {
      VideoPreloadService.instance.evict(widget.post.id);
    }
    super.dispose();
  }

  Future<void> _checkVip() async {
    if (widget.uid.isEmpty || widget.post.userId == widget.uid) return;
    final vip =
        await FollowService.instance.isVip(widget.uid, widget.post.userId);
    if (mounted) setState(() => _isVip = vip);
  }

  Future<void> _checkLike() async {
    if (widget.uid.isEmpty) return;
    final liked =
        await PostService.instance.isLikedBy(widget.post.id, widget.uid);
    if (mounted) setState(() => _liked = liked);
  }

  Future<void> _toggleLike() async {
    if (_loadingLike || widget.uid.isEmpty) return;
    setState(() => _loadingLike = true);
    HapticFeedback.selectionClick();
    try {
      final nowLiked =
          await PostService.instance.toggleLike(widget.post.id, widget.uid);
      if (mounted)
        setState(() {
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
    final newCount = await showCommentsSheet(context,
        post: widget.post, userData: widget.userData);
    if (newCount != null && mounted) setState(() => _commentCount = newCount);
  }

  void _abrirPerfil() {
    if (widget.post.userId == widget.uid) return;
    HapticFeedback.selectionClick();
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PublicProfileScreen(
            userId: widget.post.userId,
            userName: widget.post.userName,
            userAvatar: widget.post.userAvatar,
          ),
        ));
  }

  /// Abre o vídeo em tela cheia usando o controller pré-carregado.
  void _abrirVideoFullscreen() {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      FullscreenVideoScreen.route(
        postId: widget.post.id,
        videoUrl: widget.post.mediaUrl!,
        thumbUrl: widget.post.thumbUrl,
        userName: widget.post.userName,
        titulo: widget.post.titulo,
        duration: widget.post.videoDuration,
      ),
    );
  }

  void _mostrarMenuPost(BuildContext context, bool isOwnPost) {
    showModalBottomSheet(
      context: context,
      backgroundColor: TabuColors.bgAlt,
      shape: const RoundedRectangleBorder(),
      builder: (_) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 36,
            height: 3,
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(
                color: TabuColors.border,
                borderRadius: BorderRadius.circular(2))),
        if (isOwnPost) ...[
          _PostMenuTile(
              icon: Icons.delete_outline_rounded,
              label: 'EXCLUIR POST',
              sublabel: 'Remove permanentemente',
              danger: true,
              onTap: () {
                Navigator.pop(context);
                _confirmarDelete(context);
              }),
          Container(height: 0.5, color: TabuColors.border),
        ],
        _PostMenuTile(
            icon: Icons.flag_outlined,
            label: 'DENUNCIAR',
            sublabel: 'Reportar este conteúdo',
            onTap: () {
              Navigator.pop(context);
              showReportPostSheet(context,
                  postId: widget.post.id,
                  postOwnerId: widget.post.userId,
                  postTitulo: widget.post.titulo);
            }),
        const SizedBox(height: 8),
      ])),
    );
  }

  void _confirmarDelete(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: TabuColors.bgAlt,
      shape: const RoundedRectangleBorder(),
      builder: (_) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 36,
            height: 3,
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(
                color: TabuColors.border,
                borderRadius: BorderRadius.circular(2))),
        const Text('EXCLUIR POST?',
            style: TextStyle(
                fontFamily: TabuTypography.displayFont,
                fontSize: 14,
                letterSpacing: 4,
                color: TabuColors.branco)),
        const SizedBox(height: 8),
        const Text('Esta ação não pode ser desfeita.',
            style: TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 12,
                color: TabuColors.subtle)),
        const SizedBox(height: 20),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(children: [
              Expanded(
                  child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                              color: TabuColors.bgCard,
                              border: Border.all(
                                  color: TabuColors.border, width: 0.8)),
                          child: const Center(
                              child: Text('CANCELAR',
                                  style: TextStyle(
                                      fontFamily: TabuTypography.bodyFont,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 2.5,
                                      color: TabuColors.dim)))))),
              const SizedBox(width: 12),
              Expanded(
                  child: GestureDetector(
                      onTap: () async {
                        Navigator.pop(context);
                        HapticFeedback.mediumImpact();
                        await PostService.instance.deletePost(widget.post.id);
                      },
                      child: Container(
                          height: 46,
                          color: const Color(0xFFE85D5D),
                          child: const Center(
                              child: Text('EXCLUIR',
                                  style: TextStyle(
                                      fontFamily: TabuTypography.bodyFont,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 2.5,
                                      color: Colors.white)))))),
            ])),
        const SizedBox(height: 20),
      ])),
    );
  }

  void _abrirImagemFullscreen() {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      FullscreenImageScreen.route(
        imageUrl: widget.post.mediaUrl!,
        userName: widget.post.userName,
        titulo: widget.post.titulo,
      ),
    );
  }

  List<Color> _gradientForUser(String userId) {
    final palettes = [
      [const Color(0xFF3D0018), const Color(0xFF6B0030)],
      [const Color(0xFF1A0030), const Color(0xFF4B005A)],
      [const Color(0xFF2D0010), const Color(0xFF7A0028)],
      [const Color(0xFF0D0020), const Color(0xFF3B0050)],
      [const Color(0xFF2A0012), const Color(0xFFCC0044)],
    ];
    final idx = userId.codeUnits.fold(0, (a, b) => a + b) % palettes.length;
    return palettes[idx];
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final isOwnPost = post.userId == widget.uid;
    final gradient = _gradientForUser(post.userId);
    final isVideo = post.tipo == 'video';
    final isPhoto = post.tipo == 'foto';
    final isEmoji = post.tipo == 'emoji';
    final temMidia = (isPhoto && post.mediaUrl != null) ||
        (isVideo && post.mediaUrl != null) ||
        isEmoji;

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 1),
      decoration: BoxDecoration(
          border:
              Border(bottom: BorderSide(color: TabuColors.border, width: 0.5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ──────────────────────────────────────────────────────────
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(children: [
              GestureDetector(
                  onTap: _abrirPerfil,
                  child: Stack(children: [
                    CachedAvatar(
                        uid: post.userId,
                        name: post.userName,
                        size: 48,
                        radius: 12,
                        isOwn: isOwnPost,
                        glowRing: isOwnPost),
                    if (_isVip)
                      Positioned.fill(
                          child: Container(
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFFD4AF37)
                                          .withOpacity(0.7),
                                      width: 1.5)))),
                  ])),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      GestureDetector(
                          onTap: _abrirPerfil,
                          child: Text(
                              isOwnPost &&
                                      UserDataNotifier.instance.name.isNotEmpty
                                  ? UserDataNotifier.instance.nameUpper
                                  : post.userName,
                              style: const TextStyle(
                                  fontFamily: TabuTypography.bodyFont,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                  color: TabuColors.branco))),
                      if (isOwnPost) ...[
                        const SizedBox(width: 7),
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color:
                                    TabuColors.rosaPrincipal.withOpacity(0.15),
                                border: Border.all(
                                    color: TabuColors.rosaPrincipal
                                        .withOpacity(0.5),
                                    width: 0.8)),
                            child: const Text('VOCÊ',
                                style: TextStyle(
                                    fontFamily: TabuTypography.bodyFont,
                                    fontSize: 7,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.5,
                                    color: TabuColors.rosaPrincipal))),
                      ],
                      if (isVideo) ...[
                        const SizedBox(width: 7),
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                border: Border.all(
                                    color: TabuColors.rosaPrincipal
                                        .withOpacity(0.4),
                                    width: 0.8)),
                            child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.videocam_rounded,
                                      color: TabuColors.rosaPrincipal, size: 9),
                                  SizedBox(width: 3),
                                  Text('VÍDEO',
                                      style: TextStyle(
                                          fontFamily: TabuTypography.bodyFont,
                                          fontSize: 7,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.5,
                                          color: TabuColors.rosaPrincipal)),
                                ])),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    Row(children: [
                      Text(_formatTime(post.createdAt),
                          style: const TextStyle(
                              fontFamily: TabuTypography.bodyFont,
                              fontSize: 10,
                              letterSpacing: 0.5,
                              color: TabuColors.subtle)),
                      const SizedBox(width: 6),
                      Container(
                          width: 3,
                          height: 3,
                          decoration: const BoxDecoration(
                              color: TabuColors.subtle,
                              shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      _VisibilidadeChip(visibilidade: post.visibilidade),
                    ]),
                  ])),
              GestureDetector(
                  onTap: () => _mostrarMenuPost(context, isOwnPost),
                  child: const Icon(Icons.more_horiz,
                      color: TabuColors.subtle, size: 18)),
            ])),

        // ── Título ───────────────────────────────────────────────────────────
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Text(post.titulo,
                style: const TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: TabuColors.branco,
                    height: 1.4))),

        // ── Mídia ────────────────────────────────────────────────────────────
        if (temMidia) _buildMidia(post, gradient),

        // ── Descrição ────────────────────────────────────────────────────────
        if (post.descricao != null && post.descricao!.isNotEmpty)
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Text(post.descricao!,
                  style: const TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 14,
                      letterSpacing: 0.2,
                      color: TabuColors.branco,
                      height: 1.5))),

        if (!temMidia && (post.descricao == null || post.descricao!.isEmpty))
          const SizedBox(height: 8),

        // ── Ações ────────────────────────────────────────────────────────────
        Container(
            height: 0.5,
            color: TabuColors.border,
            margin: const EdgeInsets.symmetric(horizontal: 16)),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(children: [
              _ActionBtn(
                  icon: _liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  label: '$_likes',
                  color: _liked ? TabuColors.rosaPrincipal : TabuColors.subtle,
                  onTap: _toggleLike),
              _ActionBtn(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: _commentCount > 0 ? '$_commentCount' : 'COMENTAR',
                  color: TabuColors.subtle,
                  onTap: _abrirComentarios),
            ])),
        const SizedBox(height: 4),
      ]),
    );
  }

  Widget _buildMidia(PostModel post, List<Color> gradient) {
    // ── Emoji ──────────────────────────────────────────────────────────────
    if (post.tipo == 'emoji' && post.emoji != null) {
      return Container(
          height: 160,
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              border: Border.all(color: TabuColors.border, width: 0.5)),
          child: Center(
              child: Text(post.emoji!, style: const TextStyle(fontSize: 96))));
    }

    // ── Vídeo — toca tela cheia ao tocar ──────────────────────────────────
    if (post.tipo == 'video' && post.mediaUrl != null) {
      return _VideoThumbnailCard(
        postId: post.id,
        videoUrl: post.mediaUrl!,
        thumbUrl: post.thumbUrl,
        duration: post.videoDuration,
        gradient: gradient,
        onTap: _abrirVideoFullscreen,
      );
    }

    // ── Foto ───────────────────────────────────────────────────────────────
    if (post.mediaUrl != null) {
      return GestureDetector(
        onTap: _abrirImagemFullscreen,
        child: Container(
          height: 220,
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          decoration: BoxDecoration(
            color: TabuColors.bgCard,
            border: Border.all(color: TabuColors.border, width: 0.5),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                post.mediaUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (_, __, ___) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.broken_image_outlined,
                        color: TabuColors.subtle, size: 36),
                  ),
                ),
              ),
              // Badge "TELA CHEIA" — mesmo padrão do vídeo
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.12), width: 0.5),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: const [
                    Icon(Icons.fullscreen_rounded,
                        color: Colors.white54, size: 10),
                    SizedBox(width: 3),
                    Text('TELA CHEIA',
                        style: TextStyle(
                            fontFamily: TabuTypography.bodyFont,
                            fontSize: 7,
                            letterSpacing: 1.5,
                            color: Colors.white54)),
                  ]),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

//══════════════════════════════════════════════════════════════════════════════
//  VIDEO PLAYER WIDGET — player inline no feed
// ══════════════════════════════════════════════════════════════════════════════
class _VideoThumbnailCard extends StatelessWidget {
  final String postId;
  final String videoUrl;
  final String? thumbUrl;
  final int? duration;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _VideoThumbnailCard({
    required this.postId,
    required this.videoUrl,
    required this.gradient,
    required this.onTap,
    this.thumbUrl,
    this.duration,
  });

  @override
  Widget build(BuildContext context) {
    // Verifica se o preload já terminou para mostrar indicador "pronto"
    final isPreloaded = VideoPreloadService.instance.isReady(postId);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 260,
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: TabuColors.borderMid, width: 0.8),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Capa / fundo ─────────────────────────────────────────────
            thumbUrl != null
                ? Image.network(
                    thumbUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _gradientBg(),
                  )
                : _gradientBg(),

            // ── Gradiente inferior ───────────────────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.80)
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // ── Botão play ───────────────────────────────────────────────
            Center(
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.55),
                  border:
                      Border.all(color: TabuColors.rosaPrincipal, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: TabuColors.glow.withOpacity(0.35),
                      blurRadius: 20,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),

            // ── Indicador "PRONTO" + duração (canto inferior direito) ────
            Positioned(
              bottom: 10,
              right: 10,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Badge "INSTANTÂNEO" quando pré-carregado
                  if (isPreloaded) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A6B3A).withOpacity(0.9),
                        border: Border.all(
                            color: const Color(0xFF4ECDC4).withOpacity(0.6),
                            width: 0.8),
                      ),
                      child:
                          Row(mainAxisSize: MainAxisSize.min, children: const [
                        Icon(Icons.bolt_rounded,
                            color: Color(0xFF4ECDC4), size: 9),
                        SizedBox(width: 3),
                        Text('PRONTO',
                            style: TextStyle(
                                fontFamily: TabuTypography.bodyFont,
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                color: Color(0xFF4ECDC4))),
                      ]),
                    ),
                    const SizedBox(width: 5),
                  ],
                  // Duração
                  if (duration != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        border: Border.all(
                            color: TabuColors.rosaPrincipal.withOpacity(0.5),
                            width: 0.8),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.play_circle_outline_rounded,
                            color: TabuColors.rosaPrincipal, size: 10),
                        const SizedBox(width: 4),
                        Text(
                          _fmtDuration(duration!),
                          style: const TextStyle(
                            fontFamily: TabuTypography.bodyFont,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: Colors.white,
                          ),
                        ),
                      ]),
                    ),
                ],
              ),
            ),

            // ── Label "TELA CHEIA" no topo direito ────────────────────────
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.12), width: 0.5),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: const [
                  Icon(Icons.fullscreen_rounded,
                      color: Colors.white54, size: 10),
                  SizedBox(width: 3),
                  Text('TELA CHEIA',
                      style: TextStyle(
                          fontFamily: TabuTypography.bodyFont,
                          fontSize: 7,
                          letterSpacing: 1.5,
                          color: Colors.white54)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gradientBg() => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: Icon(Icons.play_circle_outline_rounded,
              color: Colors.white24, size: 56),
        ),
      );

  String _fmtDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SEEK BAR — barra de progresso interativa (clique para seeking)
// ══════════════════════════════════════════════════════════════════════════════
class _SeekBar extends StatefulWidget {
  final VideoPlayerController controller;
  const _SeekBar({required this.controller});

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_update);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_update);
    super.dispose();
  }

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pos = widget.controller.value.position.inMilliseconds.toDouble();
    final total = widget.controller.value.duration.inMilliseconds.toDouble();
    final pct = total > 0 ? (pos / total).clamp(0.0, 1.0) : 0.0;

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (total <= 0) return;
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final localX = details.localPosition.dx.clamp(0.0, box.size.width);
        final seekMs = (localX / box.size.width * total).clamp(0.0, total);
        widget.controller.seekTo(Duration(milliseconds: seekMs.toInt()));
      },
      child: Container(
        height: 3,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.15)),
        child: FractionallySizedBox(
          widthFactor: pct,
          alignment: Alignment.centerLeft,
          child: Container(
            decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [TabuColors.rosaDeep, TabuColors.rosaPrincipal])),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  WIDGETS COMPARTILHADOS — continuação do código original
// ══════════════════════════════════════════════════════════════════════════════
class _PB extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool ativo;
  final bool loading;
  final Color color;
  final VoidCallback onTap;
  const _PB(
      {required this.icon,
      required this.label,
      required this.count,
      required this.ativo,
      required this.loading,
      required this.color,
      required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 50,
          decoration: BoxDecoration(
              color: ativo ? color.withOpacity(0.15) : TabuColors.bgCard,
              border: Border.all(
                  color: ativo ? color.withOpacity(0.6) : TabuColors.border,
                  width: ativo ? 1.2 : 0.8)),
          child: loading
              ? Center(
                  child: SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(
                          color: color, strokeWidth: 1.5)))
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(icon,
                      color: ativo ? color : TabuColors.subtle, size: 14),
                  const SizedBox(width: 6),
                  Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: TextStyle(
                                fontFamily: TabuTypography.bodyFont,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                color: ativo ? color : TabuColors.subtle)),
                        if (count > 0)
                          Text('$count',
                              style: TextStyle(
                                  fontFamily: TabuTypography.bodyFont,
                                  fontSize: 9,
                                  color: ativo
                                      ? color.withOpacity(0.7)
                                      : TabuColors.border)),
                      ]),
                ])));
}

class _CT extends StatelessWidget {
  final Map<String, dynamic> data;
  const _CT({required this.data});
  @override
  Widget build(BuildContext context) {
    final uid = data['user_id'] as String? ?? '';
    final name = data['user_name'] as String? ?? '';
    final texto = data['texto'] as String? ?? '';
    final ts = data['created_at'] as int? ?? 0;
    final diff =
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts));
    final tempo = diff.inMinutes < 60
        ? '${diff.inMinutes}min'
        : diff.inHours < 24
            ? '${diff.inHours}h'
            : '${diff.inDays}d';
    return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CachedAvatar(uid: uid, name: name, size: 30, radius: 8),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Text(name.toUpperCase(),
                      style: const TextStyle(
                          fontFamily: TabuTypography.bodyFont,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: TabuColors.branco)),
                  const SizedBox(width: 8),
                  Text(tempo,
                      style: const TextStyle(
                          fontFamily: TabuTypography.bodyFont,
                          fontSize: 9,
                          color: TabuColors.subtle)),
                ]),
                const SizedBox(height: 3),
                Text(texto,
                    style: const TextStyle(
                        fontFamily: TabuTypography.bodyFont,
                        fontSize: 13,
                        color: TabuColors.dim,
                        height: 1.4)),
              ])),
        ]));
  }
}

class _MenuOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final VoidCallback onTap;
  final bool accent;
  const _MenuOption(
      {required this.icon,
      required this.label,
      required this.sublabel,
      required this.onTap,
      this.accent = false});
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                    color: accent
                        ? TabuColors.rosaPrincipal.withOpacity(0.15)
                        : TabuColors.bgCard,
                    border: Border.all(
                        color: accent
                            ? TabuColors.rosaPrincipal
                            : TabuColors.border,
                        width: 0.8)),
                child: Icon(icon,
                    color: accent ? TabuColors.rosaPrincipal : TabuColors.dim,
                    size: 16)),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color: accent
                          ? TabuColors.rosaPrincipal
                          : TabuColors.branco)),
              Text(sublabel,
                  style: const TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 9,
                      letterSpacing: 0.5,
                      color: TabuColors.subtle)),
            ]),
          ])));
}

class _SquircleAvatar extends StatelessWidget {
  final double size;
  final double radius;
  final String avatarUrl;
  final List<Color> gradient;
  final Color ringColor;
  final bool hasNewStory;
  const _SquircleAvatar(
      {required this.size,
      required this.radius,
      required this.avatarUrl,
      required this.gradient,
      required this.ringColor,
      this.hasNewStory = false});
  @override
  Widget build(BuildContext context) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: hasNewStory
              ? const LinearGradient(colors: [
                  TabuColors.rosaDeep,
                  TabuColors.rosaPrincipal,
                  TabuColors.rosaClaro
                ], begin: Alignment.topLeft, end: Alignment.bottomRight)
              : LinearGradient(colors: [ringColor, ringColor]),
          boxShadow: hasNewStory
              ? [
                  BoxShadow(
                      color: TabuColors.glow, blurRadius: 10, spreadRadius: 1)
                ]
              : null),
      padding: const EdgeInsets.all(2),
      child: ClipRRect(
          borderRadius: BorderRadius.circular(radius - 2),
          child: avatarUrl.isNotEmpty
              ? Image.network(avatarUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholder())
              : _placeholder()));
  Widget _placeholder() => Container(
      decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight)),
      child: const Icon(Icons.person_outline,
          color: TabuColors.rosaPrincipal, size: 18));
}

// ══════════════════════════════════════════════════════════════════════════════
//  _StoryBubble - VERSÃO FINAL CORRIGIDA
// ══════════════════════════════════════════════════════════════════════════════
// 
// ✅ Substitua TODA a classe _StoryBubble por esta versão
// ✅ Localização: aproximadamente linha 1600-1800 no arquivo home_screen.dart
//
// MUDANÇAS:
// 1. SizedBox(20x20) envolvendo o GestureDetector do botão +
// 2. Isso limita a área clicável apenas ao tamanho visual do botão
// 3. O resto do avatar (62x62) é 100% clicável para abrir o viewer
//
// ══════════════════════════════════════════════════════════════════════════════

class _StoryBubble extends StatelessWidget {
  final String uid;
  final String name;
  final String avatarUrl;
  final bool isOwn;
  final bool hasNew;
  final bool viewed;
  final bool isVip;
  final Map<String, dynamic> userData;
  final VoidCallback onTap;

  const _StoryBubble({
    required this.uid,
    required this.name,
    required this.avatarUrl,
    required this.isOwn,
    required this.hasNew,
    required this.userData,
    required this.onTap,
    this.viewed = false,
    this.isVip = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      child: Column(
        children: [
          // ✅ STACK COM ÁREAS DE TOQUE SEPARADAS
          SizedBox(
            width: 68,
            height: 68,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // ═══ ÁREA CLICÁVEL DO AVATAR (TODA A ÁREA) ═══
                Positioned.fill(
                  child: GestureDetector(
                    onTap: onTap, // ✅ SEMPRE abre viewer (incluindo o seu)
                    behavior: HitTestBehavior.opaque, // ✅ CAPTURA TODA A ÁREA
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Anéis coloridos baseado no estado
                        if (isVip && hasNew && !viewed)
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF6B4A00),
                                  Color(0xFFD4AF37),
                                  Color(0xFFFFE066),
                                  Color(0xFFD4AF37)
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0xFFD4AF37),
                                  blurRadius: 14,
                                  spreadRadius: 1,
                                  blurStyle: BlurStyle.outer,
                                )
                              ],
                            ),
                          )
                        else if (hasNew && !viewed)
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                colors: [
                                  TabuColors.rosaDeep,
                                  TabuColors.rosaPrincipal,
                                  TabuColors.rosaClaro
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: TabuColors.glow,
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                )
                              ],
                            ),
                          )
                        else if (hasNew && viewed)
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF3A3A4A),
                                width: 1.5,
                              ),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1E1E2A), Color(0xFF2A2A3A)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          )
                        else
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: TabuColors.border,
                            ),
                          ),

                        // Avatar
                        Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(color: TabuColors.bg, width: 2.5),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10.5),
                            child: avatarUrl.isNotEmpty
                                ? Image.network(
                                    avatarUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _avatarPlaceholder(),
                                  )
                                : _avatarPlaceholder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ═══ BOTÃO + (APENAS NO SEU STORY) ═══
                // ✅ POSICIONADO POR ÚLTIMO = FICA POR CIMA
                // ✅ SizedBox LIMITA A ÁREA CLICÁVEL A APENAS 20x20px
                if (isOwn)
                  Positioned(
                    bottom: 1,
                    right: 1,
                    child: SizedBox(
                      width: 20, // ✅ LIMITA A ÁREA CLICÁVEL
                      height: 20, // ✅ APENAS AO TAMANHO DO BOTÃO
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (_, animation, __) =>
                                  CreateStoryScreen(userData: userData),
                              transitionsBuilder: (_, animation, __, child) =>
                                  FadeTransition(
                                opacity: CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutCubic,
                                ),
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.06),
                                    end: Offset.zero,
                                  ).animate(
                                    CurvedAnimation(
                                      parent: animation,
                                      curve: Curves.easeOutCubic,
                                    ),
                                  ),
                                  child: child,
                                ),
                              ),
                              transitionDuration: const Duration(milliseconds: 340),
                            ),
                          );
                        },
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: TabuColors.rosaPrincipal,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: TabuColors.bg, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: TabuColors.glow.withOpacity(0.4),
                                blurRadius: 8,
                                spreadRadius: 0.5,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.add,
                            color: TabuColors.branco,
                            size: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 6),
          Text(
            isOwn ? 'SEU' : name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
              color: hasNew ? TabuColors.rosaPrincipal : TabuColors.subtle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarPlaceholder() => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isOwn
                ? [const Color(0xFF3D0018), const Color(0xFF8B003A)]
                : [const Color(0xFF1A0030), const Color(0xFF9B0060)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: isOwn
            ? const Icon(
                Icons.person_outline,
                color: TabuColors.rosaPrincipal,
                size: 26,
              )
            : Center(
                child: Text(
                  name.isNotEmpty ? name.substring(0, 1) : '?',
                  style: const TextStyle(
                    fontFamily: TabuTypography.displayFont,
                    fontSize: 22,
                    color: Colors.white,
                  ),
                ),
              ),
      );
}

class _VisibilidadeChip extends StatelessWidget {
  final String visibilidade;
  const _VisibilidadeChip({required this.visibilidade});
  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (visibilidade) {
      case 'seguidores':
        icon = Icons.people_outline_rounded;
        break;
      case 'vip':
        icon = Icons.star_border_rounded;
        break;
      default:
        icon = Icons.public_rounded;
        break;
    }
    return Icon(icon, color: TabuColors.subtle, size: 10);
  }
}

class _PostMenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final bool danger;
  final VoidCallback onTap;
  const _PostMenuTile(
      {required this.icon,
      required this.label,
      required this.sublabel,
      required this.onTap,
      this.danger = false});
  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFE85D5D) : TabuColors.branco;
    return InkWell(
        onTap: onTap,
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(children: [
              Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      border: Border.all(
                          color: color.withOpacity(0.3), width: 0.8)),
                  child: Icon(icon, color: color, size: 18)),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label,
                    style: TextStyle(
                        fontFamily: TabuTypography.bodyFont,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: color)),
                Text(sublabel,
                    style: const TextStyle(
                        fontFamily: TabuTypography.bodyFont,
                        fontSize: 10,
                        letterSpacing: 0.5,
                        color: TabuColors.subtle)),
              ]),
            ])));
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
              padding: const EdgeInsets.symmetric(vertical: 10),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, color: color, size: 17),
                const SizedBox(width: 5),
                Text(label,
                    style: TextStyle(
                        fontFamily: TabuTypography.bodyFont,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                        color: color)),
              ]))));
}

class _PostsSkeleton extends StatelessWidget {
  const _PostsSkeleton();
  @override
  Widget build(BuildContext context) => Column(
      children: List.generate(
          2,
          (_) => Container(
              margin: const EdgeInsets.only(bottom: 1),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  border: Border(
                      bottom:
                          BorderSide(color: TabuColors.border, width: 0.5))),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      _SkeletonBox(width: 44, height: 44, radius: 10),
                      const SizedBox(width: 12),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SkeletonBox(width: 120, height: 12, radius: 4),
                            const SizedBox(height: 6),
                            _SkeletonBox(width: 80, height: 10, radius: 4),
                          ]),
                    ]),
                    const SizedBox(height: 12),
                    _SkeletonBox(width: double.infinity, height: 16, radius: 4),
                    const SizedBox(height: 8),
                    _SkeletonBox(width: 200, height: 14, radius: 4),
                    const SizedBox(height: 12),
                    _SkeletonBox(
                        width: double.infinity, height: 140, radius: 0),
                  ]))));
}

class _StoriesSkeleton extends StatelessWidget {
  const _StoriesSkeleton();
  @override
  Widget build(BuildContext context) => ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemCount: 5,
      itemBuilder: (_, __) => SizedBox(
          width: 68,
          child: Column(children: [
            _SkeletonBox(width: 68, height: 68, radius: 16),
            const SizedBox(height: 6),
            _SkeletonBox(width: 40, height: 8, radius: 4),
          ])));
}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  const _SkeletonBox(
      {required this.width, required this.height, required this.radius});
  @override
  Widget build(BuildContext context) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
          color: TabuColors.border.withOpacity(0.4),
          borderRadius: BorderRadius.circular(radius)));
}

class _FeedBg extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = TabuColors.bg);
    canvas.drawCircle(
        Offset(size.width * 0.85, size.height * 0.1),
        size.width * 0.7,
        Paint()
          ..shader = RadialGradient(colors: [
            TabuColors.rosaPrincipal.withOpacity(0.07),
            Colors.transparent,
          ]).createShader(Rect.fromCircle(
              center: Offset(size.width * 0.85, size.height * 0.1),
              radius: size.width * 0.7)));
  }

  @override
  bool shouldRepaint(_FeedBg _) => false;
}
