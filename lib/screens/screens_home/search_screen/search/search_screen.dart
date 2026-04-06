// lib/screens/screens_home/search_screen/search_screen_paginated.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/models/party_model.dart';
import 'package:tabuapp/models/user_search.dart';
import 'package:tabuapp/screens/screens_home/home_screen/perfis/public_profile_screen.dart';
import 'package:tabuapp/services/services_administrative/location_service.dart';
import 'package:tabuapp/services/services_administrative/party_service.dart';
import 'package:tabuapp/services/services_app/cached_avatar.dart';
import 'package:tabuapp/services/services_app/follow_service.dart';
import 'package:tabuapp/services/services_app/ibge_service.dart';
import 'package:tabuapp/services/services_app/party_service_paginated.dart';
import 'package:tabuapp/services/services_app/search_service_paginated.dart';
import 'package:tabuapp/services/services_app/user_data_notifier.dart';

class SearchScreenPaginated extends StatefulWidget {
  const SearchScreenPaginated({super.key});

  @override
  State<SearchScreenPaginated> createState() => _SearchScreenPaginatedState();
}

class _SearchScreenPaginatedState extends State<SearchScreenPaginated>
    with TickerProviderStateMixin {

  late TabController _tabCtrl;
  int _tabIndex = 0;

  // Controllers & Focus Nodes
  final TextEditingController _nameCtrl   = TextEditingController();
  final TextEditingController _festaCtrl  = TextEditingController();
  final TextEditingController _bairroCtrl = TextEditingController();
  final FocusNode             _nameFocus  = FocusNode();
  final FocusNode             _festaFocus = FocusNode();
  final IbgeService           _ibge       = IbgeService();

  // Scroll Controllers para paginação
  final ScrollController _pessoasScrollCtrl = ScrollController();
  final ScrollController _festasScrollCtrl  = ScrollController();

  // Timer para debounce
  Timer? _debounceTimer;
  static const _debounceDuration = Duration(milliseconds: 500);

  // IBGE Data
  List<EstadoIBGE> _estados         = [];
  List<CidadeIBGE> _cidades         = [];
  EstadoIBGE?      _estadoFiltro;
  CidadeIBGE?      _cidadeFiltro;
  bool             _loadingEstados  = false;
  bool             _loadingCidades  = false;

  List<EstadoIBGE> _festasEstados        = [];
  List<CidadeIBGE> _festasCidades        = [];
  EstadoIBGE?      _festasEstadoFiltro;
  CidadeIBGE?      _festasCidadeFiltro;
  String           _festasBairroFiltro   = '';
  bool             _loadingFestasEstados = false;
  bool             _loadingFestasCidades = false;

  // Coordenadas de casa do usuário
  ({double latitude, double longitude})? _homeCoords;

  // Filtros de proximidade
  bool   _proximidadeAtiva        = true;
  double _raioKm                  = 100;
  bool   _pessoasProximidadeAtiva = false;
  double _pessoasRaioKm           = 50;

  // PESSOAS - Paginação
  List<UserSearchResult> _allPessoasResults  = [];
  Set<String>            _followingIds       = {};
  bool                   _loadingPessoas     = false;
  bool                   _loadingMorePessoas = false;
  bool                   _hasMorePessoas     = false;
  int                    _currentPessoasPage = 0;
  String                 _queryPessoas       = '';

  // FESTAS - Paginação
  List<PartyModel> _allFestasResults  = [];
  bool             _loadingFestas     = false;
  bool             _loadingMoreFestas = false;
  bool             _hasMoreFestas     = false;
  int              _currentFestasPage = 0;
  String           _queryFestas       = '';

  // Animation
  late AnimationController _entryCtrl;
  late Animation<double>   _fadeAnim;

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ══════════════════════════════════════════════════════════════════════════
  //  LIFECYCLE
  // ══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();

    _tabCtrl = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (_tabCtrl.indexIsChanging) return;
        setState(() => _tabIndex = _tabCtrl.index);
        HapticFeedback.selectionClick();
      });

    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400))
      ..forward();
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);

    _nameCtrl.addListener(_onPessoaTextChanged);
    _festaCtrl.addListener(_onFestaTextChanged);
    _bairroCtrl.addListener(_onBairroTextChanged);
    _nameFocus.addListener(() => setState(() {}));
    _festaFocus.addListener(() => setState(() {}));

    _pessoasScrollCtrl.addListener(_onPessoasScroll);
    _festasScrollCtrl.addListener(_onFestasScroll);

    _carregarEstados();
    _carregarFestasEstados();
    _carregarCoordenadas();
    _carregarPessoasInicial();
    _carregarFestasInicial();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _tabCtrl.dispose();
    _entryCtrl.dispose();
    _nameCtrl.dispose();
    _festaCtrl.dispose();
    _bairroCtrl.dispose();
    _nameFocus.dispose();
    _festaFocus.dispose();
    _pessoasScrollCtrl.dispose();
    _festasScrollCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DEBOUNCE
  // ══════════════════════════════════════════════════════════════════════════

  void _onPessoaTextChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      final newQuery = _nameCtrl.text.trim();
      if (newQuery != _queryPessoas) {
        _queryPessoas = newQuery;
        _resetarPaginacaoPessoas();
      }
    });
  }

  void _onFestaTextChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      final newQuery = _festaCtrl.text.trim();
      if (newQuery != _queryFestas) {
        _queryFestas = newQuery;
        _resetarPaginacaoFestas();
      }
    });
  }

  void _onBairroTextChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      final newBairro = _bairroCtrl.text.trim();
      if (newBairro != _festasBairroFiltro) {
        _festasBairroFiltro = newBairro;
        _resetarPaginacaoFestas();
      }
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  INFINITE SCROLL
  // ══════════════════════════════════════════════════════════════════════════

  void _onPessoasScroll() {
    if (_loadingMorePessoas || !_hasMorePessoas) return;
    final pos = _pessoasScrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      _carregarMaisPessoas();
    }
  }

  void _onFestasScroll() {
    if (_loadingMoreFestas || !_hasMoreFestas) return;
    final pos = _festasScrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      _carregarMaisFestas();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  COORDENADAS DE CASA
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _carregarCoordenadas() async {
    try {
      final coords = await LocationService.instance.getUserHomeCoords(_myUid);
      if (mounted) setState(() => _homeCoords = coords);
    } catch (e) {
      debugPrint('Erro ao carregar coordenadas: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  IBGE
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _carregarEstados() async {
    setState(() => _loadingEstados = true);
    try {
      final lista = await _ibge.buscarEstados();
      if (mounted) setState(() { _estados = lista; _loadingEstados = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingEstados = false);
    }
  }

  Future<void> _carregarCidades(int estadoId) async {
    setState(() { _loadingCidades = true; _cidades = []; _cidadeFiltro = null; });
    try {
      final lista = await _ibge.buscarCidades(estadoId);
      if (mounted) setState(() { _cidades = lista; _loadingCidades = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingCidades = false);
    }
  }

  Future<void> _carregarFestasEstados() async {
    setState(() => _loadingFestasEstados = true);
    try {
      final lista = await _ibge.buscarEstados();
      if (mounted) setState(() { _festasEstados = lista; _loadingFestasEstados = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingFestasEstados = false);
    }
  }

  Future<void> _carregarFestasCidades(int estadoId) async {
    setState(() { _loadingFestasCidades = true; _festasCidades = []; _festasCidadeFiltro = null; });
    try {
      final lista = await _ibge.buscarCidades(estadoId);
      if (mounted) setState(() { _festasCidades = lista; _loadingFestasCidades = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingFestasCidades = false);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PESSOAS - PAGINAÇÃO
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _carregarPessoasInicial() async {
    setState(() {
      _loadingPessoas = true;
      _currentPessoasPage = 0;
      _allPessoasResults = [];
    });

    try {
      final following = await FollowService.instance.getFollowing(_myUid);
      _followingIds = Set<String>.from(following);

      if (_pessoasProximidadeAtiva && _homeCoords != null) {
        await _carregarPessoasProximidade();
      } else {
        await _carregarPessoasPaginado(0);
      }

      if (mounted) setState(() => _loadingPessoas = false);
    } catch (e) {
      debugPrint('Erro ao carregar pessoas: $e');
      if (mounted) setState(() => _loadingPessoas = false);
    }
  }

  Future<void> _carregarPessoasPaginado(int page) async {
    try {
      final result = await SearchServicePaginated.instance.fetchUsers(
        myUid:        _myUid,
        followingIds: _followingIds,
        page:         page,
        query:        _queryPessoas.isNotEmpty ? _queryPessoas : null,
        estadoSigla:  _estadoFiltro?.sigla,
        cidadeNome:   _cidadeFiltro?.nome,
      );

      if (mounted) {
        setState(() {
          if (page == 0) {
            _allPessoasResults = result.users;
          } else {
            _allPessoasResults.addAll(result.users);
          }
          _currentPessoasPage = page;
          _hasMorePessoas = result.hasMore;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar pessoas paginado: $e');
    }
  }

  Future<void> _carregarPessoasProximidade() async {
    if (_homeCoords == null) {
      setState(() => _allPessoasResults = []);
      return;
    }

    try {
      final users = await SearchServicePaginated.instance.fetchUsersByProximity(
        myUid:        _myUid,
        followingIds: _followingIds,
        latitude:     _homeCoords!.latitude,
        longitude:    _homeCoords!.longitude,
        radiusKm:     _pessoasRaioKm,
        query:        _queryPessoas.isNotEmpty ? _queryPessoas : null,
      );

      if (mounted) {
        setState(() {
          _allPessoasResults = users;
          _hasMorePessoas = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar pessoas por proximidade: $e');
    }
  }

  Future<void> _carregarMaisPessoas() async {
    if (_loadingMorePessoas || !_hasMorePessoas || _pessoasProximidadeAtiva) return;
    setState(() => _loadingMorePessoas = true);
    await _carregarPessoasPaginado(_currentPessoasPage + 1);
    if (mounted) setState(() => _loadingMorePessoas = false);
  }

  void _resetarPaginacaoPessoas() {
    _currentPessoasPage = 0;
    _allPessoasResults  = [];
    _carregarPessoasInicial();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FESTAS - PAGINAÇÃO
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _carregarFestasInicial() async {
    setState(() {
      _loadingFestas = true;
      _currentFestasPage = 0;
      _allFestasResults  = [];
    });

    try {
      if (_proximidadeAtiva && _homeCoords != null) {
        await _carregarFestasProximidade();
      } else {
        await _carregarFestasPaginado(0);
      }

      if (mounted) setState(() => _loadingFestas = false);
    } catch (e) {
      debugPrint('Erro ao carregar festas: $e');
      if (mounted) setState(() => _loadingFestas = false);
    }
  }

  Future<void> _carregarFestasPaginado(int page) async {
    try {
      final result = await PartyServicePaginated.instance.fetchParties(
        page:        page,
        query:       _queryFestas.isNotEmpty ? _queryFestas : null,
        estadoSigla: _festasEstadoFiltro?.sigla,
        cidadeNome:  _festasCidadeFiltro?.nome,
        bairro:      _festasBairroFiltro.isNotEmpty ? _festasBairroFiltro : null,
      );

      if (mounted) {
        setState(() {
          if (page == 0) {
            _allFestasResults = result.parties;
          } else {
            _allFestasResults.addAll(result.parties);
          }
          _currentFestasPage = page;
          _hasMoreFestas = result.hasMore;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar festas paginado: $e');
    }
  }

  Future<void> _carregarFestasProximidade() async {
    if (_homeCoords == null) {
      setState(() => _allFestasResults = []);
      return;
    }

    try {
      final festas = await PartyServicePaginated.instance.fetchPartiesByProximity(
        latitude:  _homeCoords!.latitude,
        longitude: _homeCoords!.longitude,
        radiusKm:  _raioKm,
        query:     _queryFestas.isNotEmpty ? _queryFestas : null,
      );

      if (mounted) {
        setState(() {
          _allFestasResults = festas;
          _hasMoreFestas = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar festas por proximidade: $e');
    }
  }

  Future<void> _carregarMaisFestas() async {
    if (_loadingMoreFestas || !_hasMoreFestas || _proximidadeAtiva) return;
    setState(() => _loadingMoreFestas = true);
    await _carregarFestasPaginado(_currentFestasPage + 1);
    if (mounted) setState(() => _loadingMoreFestas = false);
  }

  void _resetarPaginacaoFestas() {
    _currentFestasPage = 0;
    _allFestasResults  = [];
    _carregarFestasInicial();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FILTROS - CALLBACKS
  // ══════════════════════════════════════════════════════════════════════════

  void _onEstadoChanged(EstadoIBGE? estado) {
    setState(() { _estadoFiltro = estado; _cidadeFiltro = null; _cidades = []; });
    if (estado != null) _carregarCidades(estado.id);
    _resetarPaginacaoPessoas();
  }

  void _onCidadeChanged(CidadeIBGE? cidade) {
    setState(() => _cidadeFiltro = cidade);
    _resetarPaginacaoPessoas();
  }

  void _onFestasEstadoChanged(EstadoIBGE? estado) {
    setState(() {
      _festasEstadoFiltro = estado;
      _festasCidadeFiltro = null;
      _festasCidades = [];
    });
    if (estado != null) _carregarFestasCidades(estado.id);
    _resetarPaginacaoFestas();
  }

  void _onFestasCidadeChanged(CidadeIBGE? cidade) {
    setState(() => _festasCidadeFiltro = cidade);
    _resetarPaginacaoFestas();
  }

  void _limparFiltrosPessoas() {
    setState(() {
      _estadoFiltro = null;
      _cidadeFiltro = null;
      _cidades      = [];
    });
    _nameCtrl.clear();
    _queryPessoas = '';
    _resetarPaginacaoPessoas();
  }

  void _limparFiltrosFestas() {
    setState(() {
      _festasEstadoFiltro = null;
      _festasCidadeFiltro = null;
      _festasCidades      = [];
      _festasBairroFiltro = '';
    });
    _festaCtrl.clear();
    _bairroCtrl.clear();
    _queryFestas = '';
    _resetarPaginacaoFestas();
  }

  bool get _temFiltroAtivoPessoas =>
      _pessoasProximidadeAtiva ||
      _estadoFiltro != null ||
      _cidadeFiltro != null ||
      _queryPessoas.isNotEmpty;

  bool get _temFiltroAtivoFestas =>
      (!_proximidadeAtiva &&
          (_festasEstadoFiltro != null ||
              _festasCidadeFiltro != null ||
              _festasBairroFiltro.isNotEmpty)) ||
      _queryFestas.isNotEmpty;

  // ══════════════════════════════════════════════════════════════════════════
  //  NAVEGAÇÃO
  // ══════════════════════════════════════════════════════════════════════════

  void _abrirPerfil(UserSearchResult user) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicProfileScreen(
          userId:     user.uid,
          userName:   user.name,
          userAvatar: user.avatar.isNotEmpty ? user.avatar : null,
        ),
      ),
    ).then((_) {
      SearchServicePaginated.instance.invalidateUserCache(_myUid);
      _resetarPaginacaoPessoas();
    });
  }

  void _abrirFesta(PartyModel festa) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (_) => _FestaDetailSheet(
        festa:      festa,
        myUid:      _myUid,
        homeCoords: _homeCoords,
        onRefresh: () {
          PartyServicePaginated.instance.invalidatePartiesCache();
          _resetarPaginacaoFestas();
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TabuColors.bg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: _SearchBg())),

          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: 1.5,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.transparent,
                  TabuColors.rosaDeep, TabuColors.rosaPrincipal,
                  TabuColors.rosaClaro,
                  TabuColors.rosaPrincipal, TabuColors.rosaDeep,
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          SafeArea(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.translucent,
              child: Column(children: [
                _buildHeader(),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildPessoasTab(),
                      _buildFestasTab(),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  HEADER & TAB BAR
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildHeader() {
    final loading   = _tabIndex == 0 ? _loadingPessoas : _loadingFestas;
    final temFiltro = _tabIndex == 0 ? _temFiltroAtivoPessoas : _temFiltroAtivoFestas;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
                colors: [TabuColors.rosaPrincipal, TabuColors.rosaClaro])
                .createShader(b),
            child: const Text('BUSCAR',
                style: TextStyle(
                    fontFamily: TabuTypography.displayFont,
                    fontSize: 24,
                    letterSpacing: 6,
                    color: Colors.white)),
          ),
          const SizedBox(height: 2),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _tabIndex == 0 ? 'ENCONTRE PESSOAS' : 'DESCUBRA FESTAS',
              key: ValueKey(_tabIndex),
              style: const TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 3,
                  color: TabuColors.subtle),
            ),
          ),
        ]),
        const Spacer(),
        if (loading)
          SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(
                color: TabuColors.rosaPrincipal.withOpacity(0.6),
                strokeWidth: 1.5),
          )
        else if (temFiltro)
          GestureDetector(
            onTap: () {
              if (_tabIndex == 0) _limparFiltrosPessoas();
              else _limparFiltrosFestas();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: TabuColors.bgCard,
                border: Border.all(color: TabuColors.border, width: 0.8),
              ),
              child: const Text('LIMPAR',
                  style: TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color: TabuColors.subtle)),
            ),
          ),
      ]),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: TabuColors.bgCard,
          border: Border.all(color: TabuColors.border, width: 0.8),
        ),
        child: Row(children: [
          _TabBtn(
            label: 'PESSOAS',
            icon: Icons.person_outline_rounded,
            active: _tabIndex == 0,
            onTap: () => _tabCtrl.animateTo(0),
          ),
          Container(width: 0.8, color: TabuColors.border),
          _TabBtn(
            label: 'FESTAS',
            icon: Icons.nightlife_rounded,
            active: _tabIndex == 1,
            onTap: () => _tabCtrl.animateTo(1),
          ),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ABA PESSOAS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildPessoasTab() {
    return Column(children: [
      _buildSearchBar(
        ctrl:  _nameCtrl,
        focus: _nameFocus,
        hint:  'Quem você está procurando?',
        label: 'NOME',
      ),
      _buildPessoasModeSwitcher(),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _pessoasProximidadeAtiva
            ? _buildPessoasProximidadeControls()
            : _buildPessoasFiltros(),
      ),
      Expanded(child: _buildPessoasBody()),
    ]);
  }

  Widget _buildPessoasModeSwitcher() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: TabuColors.bgCard,
          border: Border.all(color: TabuColors.border, width: 0.8),
        ),
        child: Row(children: [
          _ModeBtn(
            label:  'PROXIMIDADE',
            icon:   Icons.my_location_rounded,
            active: _pessoasProximidadeAtiva,
            onTap: () {
              setState(() => _pessoasProximidadeAtiva = true);
              _resetarPaginacaoPessoas();
            },
          ),
          Container(width: 0.8, color: TabuColors.border),
          _ModeBtn(
            label:  'POR REGIÃO',
            icon:   Icons.tune_rounded,
            active: !_pessoasProximidadeAtiva,
            onTap: () {
              setState(() => _pessoasProximidadeAtiva = false);
              _resetarPaginacaoPessoas();
            },
          ),
        ]),
      ),
    );
  }

  Widget _buildPessoasProximidadeControls() {
    return Padding(
      key: const ValueKey('prox_pessoas'),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: TabuColors.bgCard,
          border: Border.all(color: TabuColors.border, width: 0.8),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.radar_rounded,
                color: TabuColors.rosaPrincipal, size: 13),
            const SizedBox(width: 6),
            const Text('RAIO DE BUSCA',
                style: TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                    color: TabuColors.subtle)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: TabuColors.rosaPrincipal.withOpacity(0.12),
                border: Border.all(
                    color: TabuColors.rosaPrincipal.withOpacity(0.4),
                    width: 0.8),
              ),
              child: Text(
                _pessoasRaioKm >= 1000 ? 'SEM LIMITE' : '${_pessoasRaioKm.toInt()} KM',
                style: const TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: TabuColors.rosaPrincipal),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          if (_homeCoords == null)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 2),
              child: Text(
                'Cadastre sua moradia no perfil para usar a proximidade.',
                style: TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 10,
                    color: TabuColors.subtle.withOpacity(0.7)),
              ),
            )
          else
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor:   TabuColors.rosaPrincipal,
                inactiveTrackColor: TabuColors.border,
                thumbColor:         TabuColors.rosaPrincipal,
                overlayColor:       TabuColors.rosaPrincipal.withOpacity(0.12),
                trackHeight:        2,
                thumbShape:  const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value:     _pessoasRaioKm.clamp(10, 1000),
                min:       10,
                max:       1000,
                divisions: 99,
                onChanged:    (v) => setState(() => _pessoasRaioKm = v),
                onChangeEnd:  (_) => _resetarPaginacaoPessoas(),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _buildPessoasFiltros() {
    return Padding(
      key: const ValueKey('regiao_pessoas'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(children: [
        Expanded(
          child: _FilterDropdown<EstadoIBGE>(
            label:        'ESTADO',
            icon:         Icons.map_outlined,
            hint:         'Selecione',
            loading:      _loadingEstados,
            value:        _estadoFiltro,
            items:        _estados,
            itemLabel:    (e) => '${e.sigla}  –  ${e.nome}',
            displayLabel: (e) => e.sigla,
            onChanged:    _onEstadoChanged,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _FilterDropdown<CidadeIBGE>(
            label:        'CIDADE',
            icon:         Icons.location_city_outlined,
            hint:         _estadoFiltro == null ? 'Escolha estado' : 'Selecione',
            loading:      _loadingCidades,
            enabled:      _estadoFiltro != null && !_loadingCidades && _cidades.isNotEmpty,
            value:        _cidadeFiltro,
            items:        _cidades,
            itemLabel:    (c) => c.nome,
            displayLabel: (c) => c.nome,
            onChanged:    _onCidadeChanged,
          ),
        ),
      ]),
    );
  }

  Widget _buildPessoasBody() {
    if (_loadingPessoas) return _buildSkeleton();

    if (_allPessoasResults.isEmpty) {
      return _buildVazio(_pessoasProximidadeAtiva
          ? 'NENHUM USUÁRIO\nNESSE RAIO'
          : _temFiltroAtivoPessoas
              ? 'NENHUM RESULTADO\nPARA OS FILTROS APLICADOS'
              : 'NENHUM USUÁRIO\nENCONTRADO');
    }

    return RefreshIndicator(
      color:           TabuColors.rosaPrincipal,
      backgroundColor: TabuColors.bgAlt,
      onRefresh: () async {
        SearchServicePaginated.instance.invalidateUserCache(_myUid);
        await _carregarPessoasInicial();
      },
      child: ListView.separated(
        controller: _pessoasScrollCtrl,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 100),
        itemCount: _allPessoasResults.length + (_hasMorePessoas ? 1 : 0),
        separatorBuilder: (_, __) =>
            Container(height: 0.5, color: TabuColors.border),
        itemBuilder: (_, i) {
          if (i == _allPessoasResults.length) return _buildLoadingMore();
          return _UserTile(
            user:        _allPessoasResults[i],
            isFollowing: _followingIds.contains(_allPessoasResults[i].uid),
            onTap:       () => _abrirPerfil(_allPessoasResults[i]),
            homeCoords:  _pessoasProximidadeAtiva ? _homeCoords : null,
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ABA FESTAS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildFestasTab() {
    return Column(children: [
      _buildSearchBar(
        ctrl:  _festaCtrl,
        focus: _festaFocus,
        hint:  'Nome, local, descrição...',
        label: 'BUSCAR FESTA',
      ),
      _buildFestasModeSwitcher(),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _proximidadeAtiva
            ? _buildProximidadeControls()
            : _buildRegiaoFiltros(),
      ),
      Expanded(child: _buildFestasBody()),
    ]);
  }

  Widget _buildFestasModeSwitcher() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: TabuColors.bgCard,
          border: Border.all(color: TabuColors.border, width: 0.8),
        ),
        child: Row(children: [
          _ModeBtn(
            label:  'PROXIMIDADE',
            icon:   Icons.my_location_rounded,
            active: _proximidadeAtiva,
            onTap: () {
              setState(() => _proximidadeAtiva = true);
              _resetarPaginacaoFestas();
            },
          ),
          Container(width: 0.8, color: TabuColors.border),
          _ModeBtn(
            label:  'POR REGIÃO',
            icon:   Icons.tune_rounded,
            active: !_proximidadeAtiva,
            onTap: () {
              setState(() => _proximidadeAtiva = false);
              _resetarPaginacaoFestas();
            },
          ),
        ]),
      ),
    );
  }

  Widget _buildProximidadeControls() {
    return Padding(
      key: const ValueKey('prox'),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: TabuColors.bgCard,
          border: Border.all(color: TabuColors.border, width: 0.8),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.radar_rounded,
                color: TabuColors.rosaPrincipal, size: 13),
            const SizedBox(width: 6),
            const Text('RAIO DE BUSCA',
                style: TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                    color: TabuColors.subtle)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: TabuColors.rosaPrincipal.withOpacity(0.12),
                border: Border.all(
                    color: TabuColors.rosaPrincipal.withOpacity(0.4),
                    width: 0.8),
              ),
              child: Text(
                _raioKm >= 500 ? 'SEM LIMITE' : '${_raioKm.toInt()} KM',
                style: const TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: TabuColors.rosaPrincipal),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          if (_homeCoords == null)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 2),
              child: Text(
                'Cadastre sua moradia no perfil para usar a proximidade.',
                style: TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 10,
                    color: TabuColors.subtle.withOpacity(0.7)),
              ),
            )
          else
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor:   TabuColors.rosaPrincipal,
                inactiveTrackColor: TabuColors.border,
                thumbColor:         TabuColors.rosaPrincipal,
                overlayColor:       TabuColors.rosaPrincipal.withOpacity(0.12),
                trackHeight:        2,
                thumbShape:  const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value:     _raioKm.clamp(10, 1000),
                min:       10,
                max:       1000,
                divisions: 99,
                onChanged:   (v) => setState(() => _raioKm = v),
                onChangeEnd: (_) => _resetarPaginacaoFestas(),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _buildRegiaoFiltros() {
    final bairroFocus = FocusNode();
    return Padding(
      key: const ValueKey('regiao'),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: _FilterDropdown<EstadoIBGE>(
              label:        'ESTADO',
              icon:         Icons.map_outlined,
              hint:         'Selecione',
              loading:      _loadingFestasEstados,
              value:        _festasEstadoFiltro,
              items:        _festasEstados,
              itemLabel:    (e) => '${e.sigla}  –  ${e.nome}',
              displayLabel: (e) => e.sigla,
              onChanged:    _onFestasEstadoChanged,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _FilterDropdown<CidadeIBGE>(
              label:        'CIDADE',
              icon:         Icons.location_city_outlined,
              hint:         _festasEstadoFiltro == null ? 'Escolha estado' : 'Selecione',
              loading:      _loadingFestasCidades,
              enabled:      _festasEstadoFiltro != null &&
                            !_loadingFestasCidades &&
                            _festasCidades.isNotEmpty,
              value:        _festasCidadeFiltro,
              items:        _festasCidades,
              itemLabel:    (c) => c.nome,
              displayLabel: (c) => c.nome,
              onChanged:    _onFestasCidadeChanged,
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 2, height: 10,
              color: _festasBairroFiltro.isNotEmpty
                  ? TabuColors.rosaPrincipal
                  : TabuColors.border,
            ),
            const SizedBox(width: 8),
            Text('BAIRRO',
                style: TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                    color: _festasBairroFiltro.isNotEmpty
                        ? TabuColors.rosaPrincipal
                        : TabuColors.subtle)),
          ]),
          const SizedBox(height: 5),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF0D0115),
              border: Border.all(
                color: _festasBairroFiltro.isNotEmpty
                    ? TabuColors.rosaPrincipal.withOpacity(0.45)
                    : TabuColors.border,
                width: _festasBairroFiltro.isNotEmpty ? 1 : 0.8,
              ),
            ),
            child: Row(children: [
              const SizedBox(width: 12),
              const Icon(Icons.place_outlined,
                  color: TabuColors.subtle, size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _bairroCtrl,
                  focusNode:  bairroFocus,
                  style: const TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.3,
                      color: TabuColors.branco),
                  cursorColor:  TabuColors.rosaPrincipal,
                  cursorWidth:  1,
                  cursorHeight: 16,
                  decoration: InputDecoration(
                    hintText: 'Ex: Jardim Botânico',
                    hintStyle: TextStyle(
                        fontFamily: TabuTypography.bodyFont,
                        fontSize: 13,
                        fontWeight: FontWeight.w300,
                        color: TabuColors.subtle.withOpacity(0.5)),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                ),
              ),
              if (_festasBairroFiltro.isNotEmpty)
                GestureDetector(
                  onTap: () => _bairroCtrl.clear(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.close_rounded,
                        color: TabuColors.subtle.withOpacity(0.5), size: 13),
                  ),
                ),
            ]),
          ),
        ]),
      ]),
    );
  }

  Widget _buildFestasBody() {
    if (_loadingFestas) return _buildSkeleton();

    if (_allFestasResults.isEmpty) {
      return _buildVazio(_temFiltroAtivoFestas || _proximidadeAtiva
          ? 'NENHUMA FESTA\nNESSA REGIÃO'
          : 'NENHUMA FESTA\nENCONTRADA');
    }

    return RefreshIndicator(
      color:           TabuColors.rosaPrincipal,
      backgroundColor: TabuColors.bgAlt,
      onRefresh: () async {
        PartyServicePaginated.instance.invalidatePartiesCache();
        await _carregarFestasInicial();
      },
      child: ListView.separated(
        controller: _festasScrollCtrl,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 100),
        itemCount: _allFestasResults.length + (_hasMoreFestas ? 1 : 0),
        separatorBuilder: (_, __) =>
            Container(height: 0.5, color: TabuColors.border),
        itemBuilder: (_, i) {
          if (i == _allFestasResults.length) return _buildLoadingMore();
          return _FestaSearchTile(
            festa:      _allFestasResults[i],
            homeCoords: _homeCoords,
            onTap:      () => _abrirFesta(_allFestasResults[i]),
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  WIDGETS COMUNS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildSearchBar({
    required TextEditingController ctrl,
    required FocusNode focus,
    required String hint,
    required String label,
  }) {
    final focused = focus.hasFocus;
    final hasText = ctrl.text.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: 1, bottom: 8),
          child: Row(children: [
            Container(
              width: 2, height: 10,
              color: focused ? TabuColors.rosaPrincipal : TabuColors.border,
            ),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                    color: focused ? TabuColors.rosaPrincipal : TabuColors.subtle)),
          ]),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFF0D0115),
            border: Border(
              left: BorderSide(
                color: focused
                    ? TabuColors.rosaPrincipal
                    : hasText
                        ? TabuColors.rosaPrincipal.withOpacity(0.25)
                        : TabuColors.border,
                width: focused ? 2 : 0.8,
              ),
              top:    BorderSide(color: TabuColors.border, width: 0.5),
              right:  BorderSide(color: TabuColors.border, width: 0.5),
              bottom: BorderSide(color: TabuColors.border, width: 0.5),
            ),
          ),
          child: Row(children: [
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: ctrl,
                focusNode:  focus,
                autofocus:  false,
                style: const TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.5,
                    color: TabuColors.branco),
                cursorColor:  TabuColors.rosaPrincipal,
                cursorWidth:  1,
                cursorHeight: 18,
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 0.3,
                      color: TabuColors.subtle.withOpacity(0.6)),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onSubmitted: (_) => FocusScope.of(context).unfocus(),
              ),
            ),
            if (hasText)
              GestureDetector(
                onTap: () => ctrl.clear(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Icon(Icons.close_rounded,
                      color: TabuColors.subtle.withOpacity(0.5), size: 14),
                ),
              )
            else
              const SizedBox(width: 16),
          ]),
        ),
      ]),
    );
  }

  Widget _buildLoadingMore() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: SizedBox(
          width: 16, height: 16,
          child: CircularProgressIndicator(
              color: TabuColors.rosaPrincipal.withOpacity(0.6),
              strokeWidth: 1.5),
        ),
      ),
    );
  }

  Widget _buildVazio(String msg) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: TabuColors.bgCard,
            border: Border.all(color: TabuColors.border, width: 0.8),
          ),
          child: Icon(
            _tabIndex == 0
                ? Icons.person_search_rounded
                : Icons.search_off_rounded,
            color: TabuColors.border,
            size: 24,
          ),
        ),
        const SizedBox(height: 16),
        Text(msg,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
                color: TabuColors.subtle)),
      ]),
    );
  }

  Widget _buildSkeleton() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: 5,
        separatorBuilder: (_, __) =>
            Container(height: 0.5, color: TabuColors.border),
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            _Skeleton(width: 48, height: 48, radius: 12),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _Skeleton(width: 110 - i * 6.0, height: 12, radius: 4),
                const SizedBox(height: 6),
                _Skeleton(width: 70, height: 9, radius: 3),
              ]),
            ),
            _Skeleton(width: 32, height: 32, radius: 4),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  TAB BUTTON
// ══════════════════════════════════════════════════════════════════════════════
class _TabBtn extends StatelessWidget {
  final String     label;
  final IconData   icon;
  final bool       active;
  final VoidCallback onTap;

  const _TabBtn({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 42,
          color: active
              ? TabuColors.rosaPrincipal.withOpacity(0.1)
              : Colors.transparent,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon,
                size: 13,
                color: active ? TabuColors.rosaPrincipal : TabuColors.subtle),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: active ? TabuColors.rosaPrincipal : TabuColors.subtle)),
            if (active) ...[
              const SizedBox(width: 6),
              Container(
                width: 4, height: 4,
                decoration: const BoxDecoration(
                    color: TabuColors.rosaPrincipal,
                    shape: BoxShape.circle)),
            ],
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  MODE BUTTON
// ══════════════════════════════════════════════════════════════════════════════
class _ModeBtn extends StatelessWidget {
  final String     label;
  final IconData   icon;
  final bool       active;
  final VoidCallback onTap;

  const _ModeBtn({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 36,
          color: active
              ? TabuColors.rosaPrincipal.withOpacity(0.1)
              : Colors.transparent,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon,
                size: 11,
                color: active ? TabuColors.rosaPrincipal : TabuColors.subtle),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: active ? TabuColors.rosaPrincipal : TabuColors.subtle)),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  USER TILE
// ══════════════════════════════════════════════════════════════════════════════
class _UserTile extends StatelessWidget {
  final UserSearchResult                       user;
  final bool                                   isFollowing;
  final VoidCallback                           onTap;
  final ({double latitude, double longitude})? homeCoords;

  const _UserTile({
    required this.user,
    required this.isFollowing,
    required this.onTap,
    this.homeCoords,
  });

  @override
  Widget build(BuildContext context) {
    final loc = [user.city, user.state].where((s) => s.isNotEmpty).join(', ');

    String? distLabel;
    if (homeCoords != null && user.latitude != null && user.longitude != null) {
      final km = LocationService.distanceKm(
          homeCoords!.latitude, homeCoords!.longitude,
          user.latitude!, user.longitude!);
      distLabel = LocationService.formatDistance(km);
    }

    return InkWell(
      onTap: onTap,
      splashColor:    TabuColors.rosaPrincipal.withOpacity(0.05),
      highlightColor: TabuColors.rosaPrincipal.withOpacity(0.03),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          CachedAvatar(uid: user.uid, name: user.name, size: 48, radius: 12),
          const SizedBox(width: 14),

          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user.name.toUpperCase(),
                  style: const TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: TabuColors.branco)),
              const SizedBox(height: 3),
              if (loc.isNotEmpty)
                Row(children: [
                  const Icon(Icons.location_on_outlined,
                      color: TabuColors.subtle, size: 10),
                  const SizedBox(width: 3),
                  Text(loc.toUpperCase(),
                      style: const TextStyle(
                          fontFamily: TabuTypography.bodyFont,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.5,
                          color: TabuColors.subtle)),
                ])
              else if (user.bio.isNotEmpty)
                Text(user.bio,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: TabuTypography.bodyFont,
                        fontSize: 10,
                        letterSpacing: 0.3,
                        color: TabuColors.subtle.withOpacity(0.7))),
              const SizedBox(height: 4),
              Row(children: [
                _MiniStat(value: user.followersCount, label: 'seguidores'),
                const SizedBox(width: 12),
                _MiniStat(value: user.followingCount, label: 'seguindo'),
                if (distLabel != null) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: TabuColors.rosaPrincipal.withOpacity(0.10),
                      border: Border.all(
                          color: TabuColors.rosaPrincipal.withOpacity(0.35),
                          width: 0.8),
                    ),
                    child: Text(distLabel,
                        style: const TextStyle(
                            fontFamily: TabuTypography.bodyFont,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: TabuColors.rosaPrincipal)),
                  ),
                ],
              ]),
            ]),
          ),

          const SizedBox(width: 12),

          if (isFollowing)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: TabuColors.bgAlt,
                border: Border.all(
                    color: TabuColors.rosaPrincipal.withOpacity(0.4),
                    width: 0.8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_rounded,
                    color: TabuColors.rosaPrincipal, size: 11),
                const SizedBox(width: 4),
                const Text('SEGUINDO',
                    style: TextStyle(
                        fontFamily: TabuTypography.bodyFont,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: TabuColors.rosaPrincipal)),
              ]),
            )
          else
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                  color: TabuColors.bgCard,
                  border: Border.all(color: TabuColors.border, width: 0.8)),
              child: const Icon(Icons.chevron_right_rounded,
                  color: TabuColors.subtle, size: 16),
            ),
        ]),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final int    value;
  final String label;
  const _MiniStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$value',
              style: const TextStyle(
                  fontFamily: TabuTypography.displayFont,
                  fontSize: 11,
                  color: TabuColors.branco,
                  letterSpacing: 0.5)),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 8,
                  letterSpacing: 0.5,
                  color: TabuColors.subtle.withOpacity(0.7))),
        ],
      );
}

// ══════════════════════════════════════════════════════════════════════════════
//  FESTA SEARCH TILE
// ══════════════════════════════════════════════════════════════════════════════
class _FestaSearchTile extends StatelessWidget {
  final PartyModel                             festa;
  final ({double latitude, double longitude})? homeCoords;
  final VoidCallback                           onTap;

  const _FestaSearchTile({
    required this.festa,
    required this.homeCoords,
    required this.onTap,
  });

  String _fd(DateTime d) {
    const meses = ['JAN','FEV','MAR','ABR','MAI','JUN',
                   'JUL','AGO','SET','OUT','NOV','DEZ'];
    return '${d.day.toString().padLeft(2, '0')} ${meses[d.month - 1]}';
  }

  String _fh(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}h${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    double? distKm;
    if (homeCoords != null && festa.canShowDistance) {
      distKm = LocationService.distanceKm(
          homeCoords!.latitude, homeCoords!.longitude,
          festa.latitude!, festa.longitude!);
    }
    final temBanner = festa.bannerUrl != null && festa.bannerUrl!.isNotEmpty;

    return InkWell(
      onTap: onTap,
      splashColor:    TabuColors.rosaPrincipal.withOpacity(0.05),
      highlightColor: TabuColors.rosaPrincipal.withOpacity(0.03),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [

          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: TabuColors.bgCard,
              border: Border.all(color: TabuColors.border, width: 0.8),
              borderRadius: BorderRadius.circular(4),
            ),
            clipBehavior: Clip.antiAlias,
            child: temBanner
                ? Image.network(festa.bannerUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _FestaPlaceholder(nome: festa.nome))
                : _FestaPlaceholder(nome: festa.nome),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${_fd(festa.dataInicio)} • ${_fh(festa.dataInicio)}',
                  style: const TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                      color: TabuColors.subtle)),
              const SizedBox(height: 3),
              Text(festa.nome.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: TabuColors.branco)),
              const SizedBox(height: 3),
              Row(children: [
                Icon(
                  festa.hasLocal ? Icons.place_outlined : Icons.location_off_outlined,
                  color: festa.hasLocal ? TabuColors.subtle : TabuColors.border,
                  size: 10,
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    festa.hasLocal ? festa.local! : 'Local não confirmado',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: TabuTypography.bodyFont,
                        fontSize: 10,
                        letterSpacing: 0.5,
                        fontStyle: festa.hasLocal ? FontStyle.normal : FontStyle.italic,
                        color: festa.hasLocal ? TabuColors.subtle : TabuColors.border),
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                _FStat(Icons.star_outline_rounded, festa.interessados),
                const SizedBox(width: 10),
                _FStat(Icons.check_circle_outline_rounded, festa.confirmados),
                const SizedBox(width: 10),
                _FStat(Icons.chat_bubble_outline_rounded, festa.commentCount),
                const Spacer(),
                if (distKm != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: TabuColors.rosaPrincipal.withOpacity(0.10),
                      border: Border.all(
                          color: TabuColors.rosaPrincipal.withOpacity(0.35),
                          width: 0.8),
                    ),
                    child: Text(
                      LocationService.formatDistance(distKm),
                      style: const TextStyle(
                          fontFamily: TabuTypography.bodyFont,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: TabuColors.rosaPrincipal),
                    ),
                  ),
              ]),
            ]),
          ),

          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded,
              color: TabuColors.subtle, size: 16),
        ]),
      ),
    );
  }
}

class _FestaPlaceholder extends StatelessWidget {
  final String nome;
  const _FestaPlaceholder({required this.nome});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: TabuColors.bgAlt,
      child: Center(
        child: Text(
          nome.isNotEmpty ? nome[0].toUpperCase() : '★',
          style: const TextStyle(
              fontFamily: TabuTypography.displayFont,
              fontSize: 22,
              color: TabuColors.border),
        ),
      ),
    );
  }
}

class _FStat extends StatelessWidget {
  final IconData icon;
  final int      value;
  const _FStat(this.icon, this.value);

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: TabuColors.subtle),
          const SizedBox(width: 3),
          Text('$value',
              style: const TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 9,
                  letterSpacing: 0.5,
                  color: TabuColors.subtle)),
        ],
      );
}

// ══════════════════════════════════════════════════════════════════════════════
//  FILTER DROPDOWN
// ══════════════════════════════════════════════════════════════════════════════
class _FilterDropdown<T> extends StatefulWidget {
  final String             label;
  final String             hint;
  final IconData           icon;
  final bool               loading;
  final bool               enabled;
  final T?                 value;
  final List<T>            items;
  final String Function(T) itemLabel;
  final String Function(T) displayLabel;
  final void Function(T?)  onChanged;

  const _FilterDropdown({
    required this.label,
    required this.hint,
    required this.icon,
    required this.items,
    required this.itemLabel,
    required this.displayLabel,
    required this.onChanged,
    this.value,
    this.loading = false,
    this.enabled = true,
  });

  @override
  State<_FilterDropdown<T>> createState() => _FilterDropdownState<T>();
}

class _FilterDropdownState<T> extends State<_FilterDropdown<T>> {
  bool _open = false;

  Future<void> _openSheet() async {
    if (!widget.enabled || widget.loading) return;
    FocusScope.of(context).unfocus();
    setState(() => _open = true);

    final result = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SelectionSheet<T>(
        title:     widget.label,
        items:     widget.items,
        selected:  widget.value,
        itemLabel: widget.itemLabel,
      ),
    );

    if (mounted) setState(() => _open = false);
    if (result != null) widget.onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final active   = widget.value != null;
    final disabled = !widget.enabled && !widget.loading;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(widget.icon,
            color: _open
                ? TabuColors.rosaPrincipal
                : active
                    ? TabuColors.rosaPrincipal.withOpacity(0.7)
                    : disabled
                        ? const Color(0xFF6B5200)
                        : TabuColors.subtle,
            size: 11),
        const SizedBox(width: 5),
        Text(widget.label,
            style: TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: _open
                    ? TabuColors.rosaPrincipal
                    : active
                        ? TabuColors.rosaPrincipal.withOpacity(0.7)
                        : disabled
                            ? const Color(0xFF6B5200)
                            : TabuColors.subtle)),
      ]),
      const SizedBox(height: 5),

      GestureDetector(
        onTap: _openSheet,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 42,
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF1A0A14)
                : disabled
                    ? const Color(0xFF1A1200)
                    : TabuColors.bgCard,
            border: Border.all(
              color: _open
                  ? TabuColors.rosaPrincipal
                  : active
                      ? TabuColors.rosaPrincipal.withOpacity(0.45)
                      : disabled
                          ? const Color(0xFF4A3800)
                          : TabuColors.border,
              width: _open || active ? 1 : 0.8,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            Expanded(
              child: widget.loading
                  ? Row(children: [
                      SizedBox(
                        width: 11, height: 11,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: TabuColors.rosaPrincipal.withOpacity(0.6)),
                      ),
                      const SizedBox(width: 8),
                      const Text('...',
                          style: TextStyle(
                              fontFamily: TabuTypography.bodyFont,
                              fontSize: 11,
                              color: TabuColors.subtle)),
                    ])
                  : Text(
                      active ? widget.displayLabel(widget.value as T) : widget.hint,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: TabuTypography.bodyFont,
                          fontSize: active ? 12 : 11,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                          letterSpacing: active ? 0.5 : 0.3,
                          color: active
                              ? TabuColors.rosaPrincipal
                              : disabled
                                  ? const Color(0xFF6B5200)
                                  : TabuColors.subtle),
                    ),
            ),
            if (active)
              GestureDetector(
                onTap: () => widget.onChanged(null),
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(Icons.close_rounded,
                      color: TabuColors.rosaPrincipal.withOpacity(0.6),
                      size: 13),
                ),
              )
            else
              AnimatedRotation(
                turns:    _open ? 0.5 : 0,
                duration: const Duration(milliseconds: 180),
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: disabled ? TabuColors.border : TabuColors.subtle)),
          ]),
        ),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SELECTION SHEET
// ══════════════════════════════════════════════════════════════════════════════
class _SelectionSheet<T> extends StatefulWidget {
  final String             title;
  final List<T>            items;
  final T?                 selected;
  final String Function(T) itemLabel;

  const _SelectionSheet({
    required this.title,
    required this.items,
    required this.itemLabel,
    this.selected,
  });

  @override
  State<_SelectionSheet<T>> createState() => _SelectionSheetState<T>();
}

class _SelectionSheetState<T> extends State<_SelectionSheet<T>> {
  late List<T>                _filtered;
  final TextEditingController _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filtered = widget.items;
    _ctrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _ctrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.items
          : widget.items
              .where((i) => widget.itemLabel(i).toLowerCase().contains(q))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75),
      decoration: const BoxDecoration(
        color: TabuColors.bgAlt,
        border: Border(
            top: BorderSide(color: TabuColors.rosaPrincipal, width: 1.5)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [

        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Column(children: [
            Center(
              child: Container(
                width: 36, height: 3,
                decoration: BoxDecoration(
                    color: TabuColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Text('SELECIONAR ${widget.title}',
                  style: const TextStyle(
                      fontFamily: TabuTypography.displayFont,
                      fontSize: 16,
                      letterSpacing: 4,
                      color: TabuColors.branco)),
              const Spacer(),
              Text('${widget.items.length}',
                  style: const TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                      color: TabuColors.subtle)),
            ]),
          ]),
        ),

        const SizedBox(height: 14),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            height: 42,
            decoration: BoxDecoration(
                color: TabuColors.bgCard,
                border: Border.all(color: TabuColors.border, width: 0.8)),
            child: Row(children: [
              const SizedBox(width: 12),
              const Icon(Icons.search, color: TabuColors.subtle, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  style: const TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 13,
                      color: TabuColors.branco,
                      letterSpacing: 0.3),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Buscar...',
                    hintStyle: TextStyle(
                        fontFamily: TabuTypography.bodyFont,
                        fontSize: 13,
                        color: TabuColors.subtle),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (_ctrl.text.isNotEmpty)
                GestureDetector(
                  onTap: () => _ctrl.clear(),
                  child: const Padding(
                    padding: EdgeInsets.only(right: 10),
                    child: Icon(Icons.close, color: TabuColors.subtle, size: 14),
                  ),
                ),
            ]),
          ),
        ),

        const SizedBox(height: 10),
        Container(height: 0.5, color: TabuColors.border),

        Flexible(
          child: _filtered.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Nenhum resultado',
                      style: TextStyle(
                          fontFamily: TabuTypography.bodyFont,
                          fontSize: 12,
                          letterSpacing: 2,
                          color: TabuColors.subtle)))
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) =>
                      Container(height: 0.5, color: TabuColors.border),
                  itemBuilder: (_, i) {
                    final item       = _filtered[i];
                    final isSelected = item == widget.selected;
                    return InkWell(
                      onTap: () => Navigator.pop(context, item),
                      child: Container(
                        color: isSelected
                            ? TabuColors.rosaPrincipal.withOpacity(0.08)
                            : Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        child: Row(children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 3,
                            height: isSelected ? 18 : 0,
                            color: TabuColors.rosaPrincipal,
                            margin: const EdgeInsets.only(right: 14),
                          ),
                          Expanded(
                            child: Text(widget.itemLabel(item),
                                style: TextStyle(
                                    fontFamily: TabuTypography.bodyFont,
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    letterSpacing: 0.3,
                                    color: isSelected
                                        ? TabuColors.rosaPrincipal
                                        : TabuColors.branco)),
                          ),
                          if (isSelected)
                            const Icon(Icons.check,
                                color: TabuColors.rosaPrincipal, size: 16),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SKELETON
// ══════════════════════════════════════════════════════════════════════════════
class _Skeleton extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  const _Skeleton({required this.width, required this.height, required this.radius});

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: TabuColors.border.withOpacity(0.35),
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
//  BACKGROUND
// ══════════════════════════════════════════════════════════════════════════════
class _SearchBg extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = TabuColors.bg);
    canvas.drawCircle(
      Offset(size.width * 0.1, size.height * 0.08),
      size.width * 0.6,
      Paint()
        ..shader = RadialGradient(colors: [
          TabuColors.rosaPrincipal.withOpacity(0.06),
          Colors.transparent,
        ]).createShader(Rect.fromCircle(
            center: Offset(size.width * 0.1, size.height * 0.08),
            radius: size.width * 0.6)),
    );
  }

  @override
  bool shouldRepaint(_SearchBg old) => false;
}

// ══════════════════════════════════════════════════════════════════════════════
//  FESTA DETAIL SHEET
// ══════════════════════════════════════════════════════════════════════════════
class _FestaDetailSheet extends StatefulWidget {
  final PartyModel                             festa;
  final String                                 myUid;
  final ({double latitude, double longitude})? homeCoords;
  final VoidCallback                           onRefresh;

  const _FestaDetailSheet({
    required this.festa,
    required this.myUid,
    required this.homeCoords,
    required this.onRefresh,
  });

  @override
  State<_FestaDetailSheet> createState() => _FestaDetailSheetState();
}

class _FestaDetailSheetState extends State<_FestaDetailSheet> {
  FestaPresenca              _presenca    = FestaPresenca.nenhuma;
  bool                       _loadingPres = false;
  List<Map<String, dynamic>> _comentarios = [];
  bool                       _loadingComs = true;
  final _comCtrl  = TextEditingController();
  final _comFocus = FocusNode();
  bool  _enviando = false;

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
    final p = await PartyService.instance
        .getPresenca(widget.festa.id, widget.myUid);
    if (mounted) setState(() => _presenca = p);
  }

  Future<void> _carregarComentarios() async {
    setState(() => _loadingComs = true);
    try {
      final list =
          await PartyService.instance.fetchComentarios(widget.festa.id);
      if (mounted) setState(() { _comentarios = list; _loadingComs = false; });
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
        if (mounted) setState(() { _presenca = FestaPresenca.nenhuma; _loadingPres = false; });
      } else {
        FestaPresenca atual = _presenca;
        while (atual != nova) {
          atual = await PartyService.instance
              .togglePresenca(widget.festa.id, widget.myUid, atual);
        }
        if (mounted) setState(() { _presenca = nova; _loadingPres = false; });
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
        festaId:    widget.festa.id,
        uid:        widget.myUid,
        userName:   UserDataNotifier.instance.name.isNotEmpty
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
        widget.homeCoords!.latitude, widget.homeCoords!.longitude,
        widget.festa.latitude!, widget.festa.longitude!);
    return LocationService.formatDistance(km);
  }

  @override
  Widget build(BuildContext context) {
    final festa     = widget.festa;
    final temBanner = festa.bannerUrl != null && festa.bannerUrl!.isNotEmpty;
    final isOwn     = festa.creatorId == widget.myUid;
    final dist      = _distLabel;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize:     0.96,
      minChildSize:     0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: TabuColors.bgAlt,
          border: Border(
              top: BorderSide(color: TabuColors.rosaPrincipal, width: 1.5)),
        ),
        child: Column(children: [
          Container(
            width: 36, height: 3,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
                color: TabuColors.border,
                borderRadius: BorderRadius.circular(2)),
          ),
          Expanded(
            child: ListView(controller: ctrl, children: [
              if (temBanner)
                SizedBox(
                  height: 200,
                  child: Image.network(festa.bannerUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(height: 200, color: TabuColors.bgCard)),
                ),

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
                            color: Colors.white)),
                  ),
                  const SizedBox(height: 10),
                  Text(festa.nome.toUpperCase(),
                      style: const TextStyle(
                          fontFamily: TabuTypography.displayFont,
                          fontSize: 26,
                          letterSpacing: 3,
                          color: TabuColors.branco)),
                  const SizedBox(height: 10),

                  // Local
                  Row(children: [
                    Icon(
                      festa.hasLocal
                          ? Icons.location_on_outlined
                          : Icons.location_off_outlined,
                      color: festa.hasLocal
                          ? TabuColors.rosaPrincipal
                          : TabuColors.subtle,
                      size: 13,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        festa.hasLocal ? festa.local! : 'Local não confirmado',
                        style: TextStyle(
                            fontFamily: TabuTypography.bodyFont,
                            fontSize: 13,
                            fontStyle: festa.hasLocal
                                ? FontStyle.normal
                                : FontStyle.italic,
                            color: festa.hasLocal
                                ? TabuColors.rosaClaro
                                : TabuColors.subtle),
                      ),
                    ),
                    if (dist != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: TabuColors.rosaPrincipal.withOpacity(0.12),
                          border: Border.all(
                              color:
                                  TabuColors.rosaPrincipal.withOpacity(0.5),
                              width: 0.8),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.near_me_rounded,
                              color: TabuColors.rosaPrincipal, size: 11),
                          const SizedBox(width: 5),
                          Text(dist,
                              style: const TextStyle(
                                  fontFamily: TabuTypography.bodyFont,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                  color: TabuColors.rosaPrincipal)),
                        ]),
                      ),
                    ],
                  ]),

                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.schedule_outlined,
                        color: TabuColors.subtle, size: 13),
                    const SizedBox(width: 5),
                    Text(
                      '${_fh(festa.dataInicio)} – ${_fh(festa.dataFim)}',
                      style: const TextStyle(
                          fontFamily: TabuTypography.bodyFont,
                          fontSize: 12,
                          color: TabuColors.dim),
                    ),
                  ]),
                  const SizedBox(height: 20),

                  Row(children: [
                    Expanded(
                      child: _PB(
                        icon:    Icons.star_rounded,
                        label:   'INTERESSADO',
                        count:   festa.interessados,
                        ativo:   _presenca == FestaPresenca.interessado,
                        loading: _loadingPres,
                        color:   TabuColors.rosaClaro,
                        onTap:   () =>
                            _togglePresenca(FestaPresenca.interessado),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PB(
                        icon:    Icons.check_circle_rounded,
                        label:   'VOU!',
                        count:   festa.confirmados,
                        ativo:   _presenca == FestaPresenca.confirmado,
                        loading: _loadingPres,
                        color:   const Color(0xFF4ECDC4),
                        onTap:   () =>
                            _togglePresenca(FestaPresenca.confirmado),
                      ),
                    ),
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
                        uid:    festa.creatorId,
                        name:   festa.creatorName,
                        size:   30,
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
                    if (isOwn) ...[
                      const Spacer(),
                      GestureDetector(
                        onTap: () async {
                          Navigator.pop(context);
                          await PartyService.instance
                              .deleteFesta(festa.id);
                          widget.onRefresh();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3D0A0A),
                            border: Border.all(
                                color: const Color(0xFFE85D5D)
                                    .withOpacity(0.4),
                                width: 0.8),
                          ),
                          child: const Text('EXCLUIR',
                              style: TextStyle(
                                  fontFamily: TabuTypography.bodyFont,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2,
                                  color: Color(0xFFE85D5D))),
                        ),
                      ),
                    ],
                  ]),

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
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            color: TabuColors.rosaPrincipal, strokeWidth: 1.5),
                      ),
                    )
                  else if (_comentarios.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Seja o primeiro a comentar',
                          style: TextStyle(
                              fontFamily: TabuTypography.bodyFont,
                              fontSize: 11,
                              color: TabuColors.subtle)),
                    )
                  else
                    ..._comentarios.map((com) => _CT(data: com)),

                  const SizedBox(height: 80),
                ]),
              ),
            ]),
          ),

          // Campo de comentário
          Container(
            decoration: const BoxDecoration(
              color: TabuColors.bgAlt,
              border: Border(
                  top: BorderSide(color: TabuColors.border, width: 0.5)),
            ),
            padding: EdgeInsets.fromLTRB(
                16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
            child: Row(children: [
              CachedAvatar(
                uid:    widget.myUid,
                name:   UserDataNotifier.instance.name,
                size:   30,
                radius: 8,
                isOwn:  true,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: TabuColors.bgCard,
                    border: Border.all(color: TabuColors.border, width: 0.8),
                  ),
                  child: TextField(
                    controller: _comCtrl,
                    focusNode:  _comFocus,
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
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onSubmitted: (_) => _enviarComentario(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _enviando ? null : _enviarComentario,
                child: Container(
                  width: 36, height: 36,
                  color: TabuColors.rosaPrincipal,
                  child: _enviando
                      ? const Center(
                          child: SizedBox(
                            width: 13, height: 13,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 1.5),
                          ),
                        )
                      : const Icon(Icons.send_rounded,
                          color: Colors.white, size: 15),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  String _fd(DateTime dt) {
    const m = ['Jan','Fev','Mar','Abr','Mai','Jun',
               'Jul','Ago','Set','Out','Nov','Dez'];
    return '${dt.day.toString().padLeft(2, '0')} ${m[dt.month - 1]} · ${dt.year}';
  }

  String _fh(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// ══════════════════════════════════════════════════════════════════════════════
//  PRESENÇA BUTTON
// ══════════════════════════════════════════════════════════════════════════════
class _PB extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final int          count;
  final bool         ativo;
  final bool         loading;
  final Color        color;
  final VoidCallback onTap;

  const _PB({
    required this.icon,
    required this.label,
    required this.count,
    required this.ativo,
    required this.loading,
    required this.color,
    required this.onTap,
  });

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
                width: ativo ? 1.2 : 0.8),
          ),
          child: loading
              ? Center(
                  child: SizedBox(
                    width: 13, height: 13,
                    child: CircularProgressIndicator(
                        color: color, strokeWidth: 1.5),
                  ),
                )
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
                    ],
                  ),
                ]),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
//  COMMENT TILE
// ══════════════════════════════════════════════════════════════════════════════
class _CT extends StatelessWidget {
  final Map<String, dynamic> data;
  const _CT({required this.data});

  @override
  Widget build(BuildContext context) {
    final uid   = data['user_id']    as String? ?? '';
    final name  = data['user_name']  as String? ?? '';
    final texto = data['texto']      as String? ?? '';
    final ts    = data['created_at'] as int?    ?? 0;
    final diff  = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(ts));
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
          ]),
        ),
      ]),
    );
  }
}