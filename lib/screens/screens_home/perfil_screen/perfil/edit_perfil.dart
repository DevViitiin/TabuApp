// lib/screens/screens_home/perfil_screen/edit_perfil_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/services/services_app/user_avatar_service.dart';
import 'package:tabuapp/services/services_app/edit_perfil_service.dart';
import 'package:tabuapp/services/services_app/user_data_notifier.dart';

const _kPlacesApiKey = 'AIzaSyDt4lIuxWvTESG21ok0YexdTgskf8NaNZ4';

// ── Lista de estados brasileiros ──────────────────────────────────────────────
const _kEstados = [
  {'sigla': 'AC', 'nome': 'Acre'},
  {'sigla': 'AL', 'nome': 'Alagoas'},
  {'sigla': 'AP', 'nome': 'Amapá'},
  {'sigla': 'AM', 'nome': 'Amazonas'},
  {'sigla': 'BA', 'nome': 'Bahia'},
  {'sigla': 'CE', 'nome': 'Ceará'},
  {'sigla': 'DF', 'nome': 'Distrito Federal'},
  {'sigla': 'ES', 'nome': 'Espírito Santo'},
  {'sigla': 'GO', 'nome': 'Goiás'},
  {'sigla': 'MA', 'nome': 'Maranhão'},
  {'sigla': 'MT', 'nome': 'Mato Grosso'},
  {'sigla': 'MS', 'nome': 'Mato Grosso do Sul'},
  {'sigla': 'MG', 'nome': 'Minas Gerais'},
  {'sigla': 'PA', 'nome': 'Pará'},
  {'sigla': 'PB', 'nome': 'Paraíba'},
  {'sigla': 'PR', 'nome': 'Paraná'},
  {'sigla': 'PE', 'nome': 'Pernambuco'},
  {'sigla': 'PI', 'nome': 'Piauí'},
  {'sigla': 'RJ', 'nome': 'Rio de Janeiro'},
  {'sigla': 'RN', 'nome': 'Rio Grande do Norte'},
  {'sigla': 'RS', 'nome': 'Rio Grande do Sul'},
  {'sigla': 'RO', 'nome': 'Rondônia'},
  {'sigla': 'RR', 'nome': 'Roraima'},
  {'sigla': 'SC', 'nome': 'Santa Catarina'},
  {'sigla': 'SP', 'nome': 'São Paulo'},
  {'sigla': 'SE', 'nome': 'Sergipe'},
  {'sigla': 'TO', 'nome': 'Tocantins'},
];

// Status de validação
enum _FieldStatus { idle, validando, valido, invalido }

class EditPerfilScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final void Function(Map<String, dynamic> updatedData)? onSaved;
  const EditPerfilScreen({super.key, required this.userData, this.onSaved});

  @override
  State<EditPerfilScreen> createState() => _EditPerfilScreenState();
}

class _EditPerfilScreenState extends State<EditPerfilScreen> {
  final _service  = EditPerfilService();
  final _formKey  = GlobalKey<FormState>();
  final _nameFocus  = FocusNode();
  final _bioFocus   = FocusNode();
  final _cidadeFocus = FocusNode();
  final _bairroFocus = FocusNode();

  late TextEditingController _nameCtrl;
  late TextEditingController _bioCtrl;
  late TextEditingController _cidadeCtrl;
  late TextEditingController _bairroCtrl;

  // Estado selecionado via dropdown
  String? _estadoSelecionado;

  final _cidadeFieldKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  File?   _imageFile;
  String  _currentAvatar = '';
  bool    _uploading      = false;
  bool    _saving         = false;
  double  _uploadProgress = 0;

  double?              _latitude;
  double?              _longitude;
  bool                 _mapaConfirmado = false;
  GoogleMapController?  _mapController;

  // Autocomplete cidade
  List<Map<String, dynamic>> _sugestoes = [];
  bool                       _buscando  = false;

  // Validação da cidade (verifica se pertence ao estado)
  _FieldStatus _cidadeStatus  = _FieldStatus.idle;
  String?      _cidadeErro;
  String?      _cidadeValidada;

  // Validação do bairro
  _FieldStatus _bairroStatus  = _FieldStatus.idle;
  String?      _bairroErro;
  String?      _bairroValidado;

  // Debounce
  DateTime? _bairroUltimaDigitacao;

  // ── Getters ────────────────────────────────────────────────────────────────
  bool get _estadoPreenchido  => _estadoSelecionado != null && _estadoSelecionado!.isNotEmpty;
  bool get _cidadePreenchida  => _cidadeCtrl.text.trim().isNotEmpty && _latitude != null && _cidadeStatus == _FieldStatus.valido;
  bool get _bairroOk          => _bairroStatus == _FieldStatus.valido;
  bool get _localizacaoCompleta =>
      _estadoPreenchido && _cidadePreenchida && _bairroOk;

  String get _enderecoCompleto => [
    _bairroCtrl.text.trim(),
    _cidadeCtrl.text.trim(),
    _estadoSelecionado ?? '',
  ].where((s) => s.isNotEmpty).join(', ');

  @override
  void initState() {
    super.initState();
    _nameCtrl   = TextEditingController(text: widget.userData['name']   as String? ?? '');
    _bioCtrl    = TextEditingController(text: ((widget.userData['bio']  as String?) ?? '').trim());
    _cidadeCtrl = TextEditingController(text: widget.userData['city']   as String? ?? '');
    _bairroCtrl = TextEditingController(text: widget.userData['bairro'] as String? ?? '');

    // Inicializa estado pelo dropdown
    final estadoSalvo = widget.userData['state'] as String? ?? '';
    _estadoSelecionado = _kEstados.any((e) => e['sigla'] == estadoSalvo)
        ? estadoSalvo
        : null;

    _currentAvatar = widget.userData['avatar']    as String? ?? '';
    _latitude      = (widget.userData['latitude']  as num?)?.toDouble();
    _longitude     = (widget.userData['longitude'] as num?)?.toDouble();

    // Se já tinha dados salvos, marca como válidos
    if (_cidadeCtrl.text.trim().isNotEmpty &&
        _estadoSelecionado != null &&
        _latitude != null) {
      _cidadeStatus   = _FieldStatus.valido;
      _cidadeValidada = _cidadeCtrl.text.trim();
    }

    if (_bairroCtrl.text.trim().isNotEmpty &&
        _cidadeCtrl.text.trim().isNotEmpty &&
        _estadoSelecionado != null) {
      _bairroStatus   = _FieldStatus.valido;
      _bairroValidado = _bairroCtrl.text.trim();
    }

    _mapaConfirmado = _latitude != null && _localizacaoCompleta;

    _cidadeFocus.addListener(_onCidadeFocusChange);
    _bairroFocus.addListener(_onBairroFocusChange);
  }

  void _onCidadeFocusChange() {
    if (!_cidadeFocus.hasFocus) {
      Future.delayed(const Duration(milliseconds: 200), _removeOverlay);
    }
    if (mounted) setState(() {});
  }

  void _onBairroFocusChange() {
    if (!_bairroFocus.hasFocus) {
      final v = _bairroCtrl.text.trim();
      if (v.isNotEmpty && v != _bairroValidado && _cidadePreenchida) {
        _validarBairro(v);
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _removeOverlay();
    _cidadeFocus.removeListener(_onCidadeFocusChange);
    _bairroFocus.removeListener(_onBairroFocusChange);
    _nameCtrl.dispose(); _bioCtrl.dispose();
    _cidadeCtrl.dispose(); _bairroCtrl.dispose();
    _nameFocus.dispose(); _bioFocus.dispose();
    _cidadeFocus.dispose(); _bairroFocus.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ── Overlay sugestões cidade ───────────────────────────────────────────────
  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showOverlay() {
    _removeOverlay();
    if (_sugestoes.isEmpty) return;
    final renderBox = _cidadeFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size   = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (_) => Positioned(
        left: offset.dx, top: offset.dy + size.height, width: size.width,
        child: Material(
          color: Colors.transparent, elevation: 8,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 240),
            decoration: BoxDecoration(
              color: TabuColors.bgAlt,
              border: Border.all(color: TabuColors.borderMid, width: 0.8),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.6),
                  blurRadius: 16, offset: const Offset(0, 4))]),
            child: ListView.builder(
              padding: EdgeInsets.zero, shrinkWrap: true,
              itemCount: _sugestoes.length,
              itemBuilder: (ctx, i) {
                final pred      = _sugestoes[i];
                final main      = (pred['structured_formatting'] as Map?)?['main_text']      as String? ?? pred['description'] as String? ?? '';
                final secondary = (pred['structured_formatting'] as Map?)?['secondary_text'] as String? ?? '';
                return Column(mainAxisSize: MainAxisSize.min, children: [
                  if (i > 0) Container(height: 0.5, color: TabuColors.border),
                  InkWell(
                    onTap: () => _selecionarCidade(pred),
                    child: Container(
                      color: TabuColors.bgAlt,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(children: [
                        const Icon(Icons.location_on_outlined,
                            color: TabuColors.rosaPrincipal, size: 16),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(main, style: const TextStyle(
                                fontFamily: TabuTypography.bodyFont,
                                fontSize: 13, fontWeight: FontWeight.w600,
                                color: TabuColors.branco)),
                            if (secondary.isNotEmpty)
                              Text(secondary, style: const TextStyle(
                                  fontFamily: TabuTypography.bodyFont,
                                  fontSize: 11, color: TabuColors.subtle)),
                          ])),
                      ])),
                  ),
                ]);
              },
            ))),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  // ── Busca cidades (filtrado pelo estado selecionado) ───────────────────────
  Future<void> _buscarCidades(String input) async {
    if (input.length < 2) {
      _removeOverlay();
      if (mounted) setState(() => _sugestoes = []);
      return;
    }
    if (!_estadoPreenchido) {
      _showSnack('SELECIONE O ESTADO PRIMEIRO', success: false);
      return;
    }
    if (mounted) setState(() => _buscando = true);
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(input)}'
        '&components=country:br'
        '&types=(cities)'
        '&language=pt-BR'
        '&key=$_kPlacesApiKey',
      );
      final res  = await http.get(uri);
      if (!mounted) return;
      final data  = jsonDecode(res.body) as Map<String, dynamic>;
      final preds = (data['predictions'] as List? ?? []).cast<Map<String, dynamic>>();

      // Filtra sugestões pelo estado selecionado
      final estadoNome = _kEstados
          .firstWhere((e) => e['sigla'] == _estadoSelecionado,
              orElse: () => {'sigla': '', 'nome': ''})['nome']!
          .toLowerCase();
      final estadoSigla = (_estadoSelecionado ?? '').toLowerCase();

      final filtradas = preds.where((p) {
        final desc = (p['description'] as String? ?? '').toLowerCase();
        return desc.contains(estadoSigla) || desc.contains(estadoNome);
      }).toList();

      setState(() { _sugestoes = filtradas; _buscando = false; });
      _showOverlay();
    } catch (_) {
      if (mounted) setState(() => _buscando = false);
    }
  }

  // ── Seleciona cidade e valida que ela está no estado escolhido ─────────────
  Future<void> _selecionarCidade(Map<String, dynamic> pred) async {
    final placeId = pred['place_id'] as String? ?? '';
    _removeOverlay();
    if (mounted) setState(() { _sugestoes = []; _buscando = false; });
    FocusScope.of(context).unfocus();
    if (placeId.isEmpty) return;

    setState(() { _cidadeStatus = _FieldStatus.validando; _cidadeErro = null; });

    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=$placeId'
        '&fields=geometry,address_components'
        '&key=$_kPlacesApiKey',
      );
      final res    = await http.get(uri);
      final data   = jsonDecode(res.body) as Map<String, dynamic>;
      final result = data['result'] as Map<String, dynamic>? ?? {};
      final loc    = (result['geometry'] as Map?)?['location'] as Map?;
      final lat    = (loc?['lat'] as num?)?.toDouble();
      final lng    = (loc?['lng'] as num?)?.toDouble();

      String? city, stateFromApi;
      for (final comp in (result['address_components'] as List? ?? [])) {
        final types = (comp['types'] as List).cast<String>();
        if (types.contains('administrative_area_level_2')) city         = comp['long_name']  as String?;
        if (types.contains('administrative_area_level_1')) stateFromApi = comp['short_name'] as String?;
      }

      if (!mounted) return;

      // ── Validação: cidade deve pertencer ao estado selecionado ──────────────
      if (stateFromApi != null &&
          stateFromApi.toUpperCase() != (_estadoSelecionado ?? '').toUpperCase()) {
        final nomeEstadoSelecionado = _kEstados
            .firstWhere((e) => e['sigla'] == _estadoSelecionado,
                orElse: () => {'nome': _estadoSelecionado ?? ''})['nome'];
        setState(() {
          _cidadeStatus = _FieldStatus.invalido;
          _cidadeErro   = 'Esta cidade pertence a $stateFromApi, não a $nomeEstadoSelecionado';
          _cidadeCtrl.text = city ?? (pred['description'] as String? ?? '');
        });
        return;
      }

      setState(() {
        _cidadeCtrl.text = city  ?? '';
        _latitude        = lat;
        _longitude       = lng;
        _mapaConfirmado  = false;
        _cidadeStatus    = _FieldStatus.valido;
        _cidadeValidada  = city ?? '';
        _cidadeErro      = null;
        // Reseta bairro pois a cidade mudou
        _bairroStatus    = _FieldStatus.idle;
        _bairroErro      = null;
        _bairroValidado  = null;
      });

      if (lat != null && lng != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) =>
            _mapController?.animateCamera(CameraUpdate.newLatLng(LatLng(lat, lng))));
      }

      final bairroAtual = _bairroCtrl.text.trim();
      if (bairroAtual.isNotEmpty) {
        await _validarBairro(bairroAtual);
      } else {
        FocusScope.of(context).requestFocus(_bairroFocus);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _cidadeStatus = _FieldStatus.invalido;
          _cidadeErro   = 'Não foi possível verificar a cidade';
        });
      }
    }
  }

  // ── Validação do bairro ────────────────────────────────────────────────────
  //
  // Por que as abordagens anteriores falhavam:
  //   - Autocomplete com "bairro, cidade, estado" na query: o Google geocodifica
  //     o texto todo e ignora qualquer bounds/bias, então "Setor Independência
  //     Mansões, Brasília, DF" retorna Brasília mesmo que o bairro fique em
  //     Aparecida de Goiânia.
  //   - Geocoding com bounds + texto completo: mesma coisa — o texto explícito
  //     da cidade/estado na query domina e o bounds vira só hint fraco.
  //
  // Solução correta:
  //   Buscar APENAS o nome do bairro (sem cidade/estado na query) usando a
  //   Geocoding API com `location` (ponto central) + `radius` em metros via
  //   o novo endpoint Places API Nearby ou, mais simples e sem SDK adicional,
  //   usando o parâmetro `latlng` do Reverse Geocoding não — usamos o
  //   `components=locality` + `bounds` apertado (±0.05° ≈ 5 km).
  //
  //   Com query = só o nome do bairro e bounds restrito à cidade, o Google não
  //   tem texto de cidade/estado para se agarrar e obedece o bounds de verdade.
  //   Os address_components do resultado são então verificados estruturalmente.
  Future<void> _validarBairro(String bairro) async {
    if (!_cidadePreenchida) return;
    if (bairro.isEmpty) {
      setState(() { _bairroStatus = _FieldStatus.idle; _bairroErro = null; });
      return;
    }

    setState(() { _bairroStatus = _FieldStatus.validando; _bairroErro = null; });

    try {
      final cidade     = _cidadeCtrl.text.trim();
      final estado     = _estadoSelecionado ?? '';
      final cidadeNorm = _normalizar(cidade);
      final estadoNorm = estado.toUpperCase().trim();

      // Coordenadas da cidade (salvas quando o usuário selecionou a cidade)
      final latC  = _latitude!;
      final lngC  = _longitude!;

      // bounds apertado ±0.05° ≈ 5 km — não deixa o Google escapar para outra cidade
      const delta = 0.05;
      final sw = '${latC - delta},${lngC - delta}';
      final ne = '${latC + delta},${lngC + delta}';

      // Query = SOMENTE o nome do bairro, sem cidade/estado
      // Isso força o Google a usar o bounds como localização principal
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?address=${Uri.encodeComponent(bairro)}'
        '&bounds=$sw|$ne'
        '&components=country:BR'
        '&language=pt-BR'
        '&key=$_kPlacesApiKey',
      );

      final res     = await http.get(uri);
      if (!mounted) return;
      final data    = jsonDecode(res.body) as Map<String, dynamic>;
      final results = (data['results'] as List? ?? []).cast<Map<String, dynamic>>();

      if (results.isEmpty) {
        setState(() {
          _bairroStatus   = _FieldStatus.invalido;
          _bairroErro     = 'Bairro não encontrado em $cidade/$estado';
          _mapaConfirmado = false;
        });
        return;
      }

      for (final r in results) {
        final comps = (r['address_components'] as List? ?? [])
            .cast<Map<String, dynamic>>();

        String? cidadeComp, estadoComp;
        for (final c in comps) {
          final types = (c['types'] as List).cast<String>();
          if (types.contains('administrative_area_level_2')) {
            cidadeComp = _normalizar(c['long_name'] as String? ?? '');
          }
          if (types.contains('administrative_area_level_1')) {
            estadoComp = (c['short_name'] as String? ?? '').toUpperCase().trim();
          }
        }

        final cidadeOk = cidadeComp != null && cidadeComp == cidadeNorm;
        final estadoOk = estadoComp != null && estadoComp == estadoNorm;

        if (cidadeOk && estadoOk) {
          final loc = (r['geometry'] as Map?)?['location'] as Map?;
          final lat = (loc?['lat'] as num?)?.toDouble();
          final lng = (loc?['lng'] as num?)?.toDouble();

          if (!mounted) return;
          setState(() {
            _bairroStatus   = _FieldStatus.valido;
            _bairroErro     = null;
            _bairroValidado = bairro;
            if (lat != null && lng != null) {
              _latitude       = lat;
              _longitude      = lng;
              _mapaConfirmado = false;
              WidgetsBinding.instance.addPostFrameCallback((_) =>
                  _mapController?.animateCamera(
                      CameraUpdate.newLatLng(LatLng(lat, lng))));
            }
          });
          return;
        }
      }

      // Nenhum resultado dentro do bounds bateu cidade + estado
      if (!mounted) return;
      setState(() {
        _bairroStatus   = _FieldStatus.invalido;
        _bairroErro     = 'Bairro não pertence a $cidade/$estado';
        _mapaConfirmado = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _bairroStatus = _FieldStatus.invalido;
          _bairroErro   = 'Não foi possível verificar o bairro';
        });
      }
    }
  }

  /// Normaliza string: minúsculas, sem acentos, sem espaços extras.
  String _normalizar(String s) {
    const from = 'àáâãäåæçèéêëìíîïðñòóôõöøùúûüýþÿ';
    const to   = 'aaaaaaa ceeeeiiiidnoooooouuuuypy';
    var r = s.toLowerCase().trim();
    for (var i = 0; i < from.length; i++) {
      r = r.replaceAll(from[i], to[i]);
    }
    return r;
  }

  void _onPinDragged(LatLng pos) => setState(() {
    _latitude = pos.latitude; _longitude = pos.longitude; _mapaConfirmado = false;
  });

  // ── Imagem ─────────────────────────────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context);
    final picked = await ImagePicker().pickImage(
        source: source, maxWidth: 800, maxHeight: 800, imageQuality: 85);
    if (picked == null) return;
    setState(() => _imageFile = File(picked.path));
  }

  // ── Salvar ─────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_estadoPreenchido) {
      _showSnack('SELECIONE SEU ESTADO', success: false);
      return;
    }

    if (!_localizacaoCompleta) {
      if (_cidadeStatus == _FieldStatus.invalido) {
        _showSnack(_cidadeErro?.toUpperCase() ?? 'CIDADE INVÁLIDA', success: false);
      } else if (!_cidadePreenchida) {
        _showSnack('SELECIONE SUA CIDADE', success: false);
      } else if (_bairroStatus == _FieldStatus.invalido) {
        _showSnack(_bairroErro?.toUpperCase() ?? 'BAIRRO INVÁLIDO', success: false);
      } else if (_bairroStatus == _FieldStatus.validando) {
        _showSnack('AGUARDE A VERIFICAÇÃO DO BAIRRO', success: false);
      } else {
        _showSnack('PREENCHA TODOS OS CAMPOS DE LOCALIZAÇÃO', success: false);
      }
      return;
    }

    setState(() { _saving = true; _uploading = _imageFile != null; });
    try {
      final updated = await _service.updateProfile(
        name:             _nameCtrl.text,
        bio:              _bioCtrl.text,
        currentAvatarUrl: _currentAvatar,
        newImageFile:     _imageFile,
        onUploadProgress: (p) { if (mounted) setState(() => _uploadProgress = p); },
        state:     _estadoSelecionado,
        city:      _cidadeCtrl.text.trim().isEmpty ? null : _cidadeCtrl.text.trim(),
        bairro:    _bairroCtrl.text.trim().isEmpty ? null : _bairroCtrl.text.trim(),
        latitude:  _latitude,
        longitude: _longitude,
      );
      if (mounted) {
        UserDataNotifier.instance.update(updated);
        UserAvatarService.instance.invalidate(updated['uid'] as String? ?? '');
        widget.onSaved?.call(updated);
        _showSnack('PERFIL ATUALIZADO', success: true);
        Navigator.pop(context, updated);
      }
    } catch (e) {
      if (mounted) _showSnack('ERRO: $e', success: false);
    } finally {
      if (mounted) setState(() { _saving = false; _uploading = false; });
    }
  }

  void _showSnack(String msg, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: success ? TabuColors.rosaDeep : const Color(0xFF3D0A0A),
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(),
      content: Text(msg, style: const TextStyle(
          fontFamily: TabuTypography.bodyFont, fontSize: 12,
          fontWeight: FontWeight.w700, letterSpacing: 2.5,
          color: TabuColors.branco))));
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: TabuColors.bgAlt,
      shape: const RoundedRectangleBorder(),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 3,
          margin: const EdgeInsets.only(top: 12, bottom: 20),
          decoration: BoxDecoration(color: TabuColors.border, borderRadius: BorderRadius.circular(2))),
        const Text('TROCAR FOTO', style: TextStyle(
            fontFamily: TabuTypography.displayFont,
            fontSize: 18, letterSpacing: 5, color: TabuColors.branco)),
        const SizedBox(height: 16),
        Container(height: 0.5, color: TabuColors.border),
        _SheetOption(icon: Icons.photo_camera_outlined, label: 'CÂMERA',
            onTap: () => _pickImage(ImageSource.camera)),
        Container(height: 0.5, color: TabuColors.border),
        _SheetOption(icon: Icons.photo_library_outlined, label: 'GALERIA',
            onTap: () => _pickImage(ImageSource.gallery)),
        if (_currentAvatar.isNotEmpty || _imageFile != null) ...[
          Container(height: 0.5, color: TabuColors.border),
          _SheetOption(icon: Icons.delete_outline, label: 'REMOVER FOTO',
            color: const Color(0xFFE85D5D),
            onTap: () {
              Navigator.pop(context);
              setState(() { _imageFile = null; _currentAvatar = ''; });
            }),
        ],
        const SizedBox(height: 16),
      ])));
  }

  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final busy = _saving || _uploading;

    return Scaffold(
      backgroundColor: TabuColors.bg,
      body: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _EditBg())),
        Positioned(top: 0, left: 0, right: 0,
          child: Container(height: 3,
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [
              TabuColors.rosaDeep, TabuColors.rosaPrincipal,
              TabuColors.rosaClaro, TabuColors.rosaPrincipal, TabuColors.rosaDeep,
            ])))),

        SafeArea(child: Column(children: [

          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: TabuColors.dim, size: 18),
                onPressed: () => Navigator.pop(context)),
              const Expanded(child: Text('EDITAR PERFIL',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: TabuTypography.displayFont,
                    fontSize: 20, letterSpacing: 5, color: TabuColors.branco))),
              GestureDetector(
                onTap: busy ? null : _save,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: busy ? TabuColors.bgCard : TabuColors.rosaPrincipal,
                    border: Border.all(color: TabuColors.rosaPrincipal, width: 0.8)),
                  child: Text(busy ? '...' : 'SALVAR',
                    style: TextStyle(fontFamily: TabuTypography.bodyFont,
                        fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2.5,
                        color: busy ? TabuColors.subtle : TabuColors.branco)))),
            ])),

          Container(height: 0.5, color: TabuColors.border),

          Expanded(child: GestureDetector(
            onTap: () { FocusScope.of(context).unfocus(); _removeOverlay(); },
            behavior: HitTestBehavior.translucent,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(key: _formKey, child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 36),

                  _AvatarPicker(
                    imageFile: _imageFile, avatarUrl: _currentAvatar,
                    uploading: _uploading, uploadProgress: _uploadProgress,
                    onTap: _showImagePicker),

                  const SizedBox(height: 36),

                  _SectionLabel(label: 'DADOS PESSOAIS'),
                  const SizedBox(height: 14),

                  _TabuField(
                    controller: _nameCtrl, focusNode: _nameFocus,
                    label: 'NOME', icon: Icons.person_outline,
                    hint: 'Seu nome',
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Nome é obrigatório' : null,
                    onEditingComplete: () => FocusScope.of(context).requestFocus(_bioFocus)),

                  const SizedBox(height: 14),

                  _TabuField(
                    controller: _bioCtrl, focusNode: _bioFocus,
                    label: 'BIO', icon: Icons.edit_note_outlined,
                    hint: 'Conte um pouco sobre você...',
                    maxLines: 3, maxLength: 120,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline),

                  const SizedBox(height: 28),

                  _SectionLabel(label: 'LOCALIZAÇÃO'),
                  const SizedBox(height: 6),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: TabuColors.rosaPrincipal.withOpacity(0.06),
                      border: Border.all(color: TabuColors.border, width: 0.8)),
                    child: const Row(children: [
                      Icon(Icons.info_outline, color: TabuColors.subtle, size: 14),
                      SizedBox(width: 8),
                      Expanded(child: Text(
                        'Selecione o estado, depois busque a cidade e confirme seu bairro.',
                        style: TextStyle(fontFamily: TabuTypography.bodyFont,
                            fontSize: 11, letterSpacing: 0.5, color: TabuColors.subtle))),
                    ])),

                  const SizedBox(height: 16),

                  // ── Dropdown de estados ──────────────────────────────────
                  _buildEstadoDropdown(),

                  const SizedBox(height: 14),

                  // ── Cidade com autocomplete ──────────────────────────────
                  _buildCidadeField(),

                  const SizedBox(height: 14),

                  // ── Bairro com validação ─────────────────────────────────
                  _buildBairroField(),

                  const SizedBox(height: 10),

                  // ── Mini-mapa ────────────────────────────────────────────
                  if (_latitude != null) _buildMiniMap(),

                  const SizedBox(height: 28),

                  _SectionLabel(label: 'CONTA'),
                  const SizedBox(height: 14),

                  _ReadOnlyField(
                    label: 'E-MAIL',
                    value: widget.userData['email'] as String? ?? '',
                    icon: Icons.mail_outline),

                  const SizedBox(height: 8),
                  _InfoBox(text: 'O e-mail não pode ser alterado por aqui.'),

                  const SizedBox(height: 40),

                  _SaveButton(
                    saving: _saving, uploading: _uploading,
                    progress: _uploadProgress, onTap: _save),

                  const SizedBox(height: 40),
                ],
              )),
            ),
          )),
        ])),
      ]),
    );
  }

  // ── Dropdown de estados ────────────────────────────────────────────────────
  Widget _buildEstadoDropdown() {
    final hasValue = _estadoSelecionado != null;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.map_outlined,
            color: hasValue ? TabuColors.rosaPrincipal : TabuColors.subtle, size: 14),
        const SizedBox(width: 6),
        Text('ESTADO *', style: TextStyle(
            fontFamily: TabuTypography.bodyFont, fontSize: 9,
            fontWeight: FontWeight.w700, letterSpacing: 2.5,
            color: hasValue ? TabuColors.rosaPrincipal : TabuColors.subtle)),
      ]),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
          color: TabuColors.bgCard,
          border: Border.all(
            color: hasValue ? TabuColors.rosaPrincipal : TabuColors.border,
            width: hasValue ? 1.5 : 0.8)),
        child: DropdownButtonFormField<String>(
          value: _estadoSelecionado,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: TabuColors.subtle, size: 20),
          dropdownColor: TabuColors.bgAlt,
          style: const TextStyle(fontFamily: TabuTypography.bodyFont,
              fontSize: 15, fontWeight: FontWeight.w500,
              color: TabuColors.branco),
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            isDense: true),
          hint: const Text('Selecione seu estado',
            style: TextStyle(fontFamily: TabuTypography.bodyFont,
                fontSize: 13, color: TabuColors.subtle)),
          validator: (v) => (v == null || v.isEmpty) ? 'Estado obrigatório' : null,
          onChanged: (val) {
            setState(() {
              _estadoSelecionado = val;
              // Reseta cidade e bairro ao trocar estado
              _cidadeCtrl.clear();
              _latitude        = null;
              _longitude       = null;
              _mapaConfirmado  = false;
              _cidadeStatus    = _FieldStatus.idle;
              _cidadeErro      = null;
              _cidadeValidada  = null;
              _bairroStatus    = _FieldStatus.idle;
              _bairroErro      = null;
              _bairroValidado  = null;
              _sugestoes       = [];
            });
            _removeOverlay();
          },
          items: _kEstados.map((e) {
            return DropdownMenuItem<String>(
              value: e['sigla'],
              child: Row(children: [
                Container(
                  width: 32, height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: TabuColors.rosaPrincipal.withOpacity(0.15),
                    border: Border.all(color: TabuColors.border, width: 0.5)),
                  child: Text(e['sigla']!,
                    style: const TextStyle(
                        fontFamily: TabuTypography.bodyFont,
                        fontSize: 9, fontWeight: FontWeight.w800,
                        letterSpacing: 1, color: TabuColors.rosaPrincipal))),
                const SizedBox(width: 10),
                Text(e['nome']!,
                  style: const TextStyle(fontFamily: TabuTypography.bodyFont,
                      fontSize: 13, color: TabuColors.branco)),
              ]));
          }).toList(),
        )),
    ]);
  }

  // ── Campo cidade com autocomplete ──────────────────────────────────────────
  Widget _buildCidadeField() {
    final focused  = _cidadeFocus.hasFocus;
    final hasValue = _cidadeCtrl.text.isNotEmpty;

    // Cor da borda conforme status
    Color bordaColor;
    switch (_cidadeStatus) {
      case _FieldStatus.valido:
        bordaColor = TabuColors.rosaPrincipal;
      case _FieldStatus.invalido:
        bordaColor = const Color(0xFFE85D5D);
      case _FieldStatus.validando:
        bordaColor = TabuColors.rosaPrincipal.withOpacity(0.5);
      case _FieldStatus.idle:
        bordaColor = focused ? TabuColors.rosaPrincipal : TabuColors.border;
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.location_on_outlined,
            color: _cidadeStatus == _FieldStatus.valido
                ? TabuColors.rosaPrincipal
                : _cidadeStatus == _FieldStatus.invalido
                    ? const Color(0xFFE85D5D)
                    : focused ? TabuColors.rosaPrincipal : TabuColors.subtle,
            size: 14),
        const SizedBox(width: 6),
        Text('CIDADE *', style: TextStyle(
            fontFamily: TabuTypography.bodyFont, fontSize: 9,
            fontWeight: FontWeight.w700, letterSpacing: 2.5,
            color: _cidadeStatus == _FieldStatus.valido
                ? TabuColors.rosaPrincipal
                : _cidadeStatus == _FieldStatus.invalido
                    ? const Color(0xFFE85D5D)
                    : focused ? TabuColors.rosaPrincipal : TabuColors.subtle)),
        if (!_estadoPreenchido) ...[
          const SizedBox(width: 8),
          const Text('(selecione o estado primeiro)',
            style: TextStyle(fontFamily: TabuTypography.bodyFont,
                fontSize: 9, color: TabuColors.subtle, letterSpacing: 0.5)),
        ],
      ]),
      const SizedBox(height: 6),
      Container(
        key: _cidadeFieldKey,
        decoration: BoxDecoration(
          color: TabuColors.bgCard,
          border: Border.all(color: bordaColor,
              width: (focused || _cidadeStatus != _FieldStatus.idle) ? 1.5 : 0.8)),
        child: Row(children: [
          const SizedBox(width: 12),
          const Icon(Icons.search_rounded, color: TabuColors.subtle, size: 18),
          const SizedBox(width: 8),
          Expanded(child: TextField(
            controller: _cidadeCtrl,
            focusNode: _cidadeFocus,
            enabled: _estadoPreenchido,
            style: TextStyle(fontFamily: TabuTypography.bodyFont,
                fontSize: 15, fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
                color: _estadoPreenchido ? TabuColors.branco : TabuColors.subtle),
            cursorColor: TabuColors.rosaPrincipal,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              border: InputBorder.none, isDense: true,
              hintText: _estadoPreenchido
                  ? 'Busque sua cidade...'
                  : 'Selecione o estado primeiro',
              hintStyle: const TextStyle(fontFamily: TabuTypography.bodyFont,
                  fontSize: 13, color: TabuColors.subtle),
              contentPadding: const EdgeInsets.symmetric(vertical: 14)),
            onChanged: (v) {
              // Reseta validação ao digitar
              setState(() {
                _cidadeStatus = _FieldStatus.idle;
                _cidadeErro   = null;
                _latitude     = null;
                _longitude    = null;
              });
              _buscarCidades(v);
            },
            onEditingComplete: () => FocusScope.of(context).requestFocus(_bairroFocus),
          )),
          if (_buscando || _cidadeStatus == _FieldStatus.validando)
            const Padding(padding: EdgeInsets.only(right: 12),
              child: SizedBox(width: 14, height: 14,
                child: CircularProgressIndicator(
                    color: TabuColors.rosaPrincipal, strokeWidth: 1.5)))
          else if (_cidadeStatus == _FieldStatus.valido)
            const Padding(padding: EdgeInsets.only(right: 10),
              child: Icon(Icons.check_circle_rounded,
                  color: TabuColors.rosaPrincipal, size: 18))
          else if (_cidadeStatus == _FieldStatus.invalido)
            const Padding(padding: EdgeInsets.only(right: 10),
              child: Icon(Icons.cancel_rounded,
                  color: Color(0xFFE85D5D), size: 18))
          else if (hasValue && !focused)
            const Padding(padding: EdgeInsets.only(right: 10),
              child: Icon(Icons.check_circle_rounded,
                  color: TabuColors.rosaPrincipal, size: 18))
          else if (hasValue)
            GestureDetector(
              onTap: () {
                _cidadeCtrl.clear();
                _removeOverlay();
                setState(() {
                  _sugestoes    = [];
                  _latitude     = null;
                  _longitude    = null;
                  _mapaConfirmado = false;
                  _cidadeStatus = _FieldStatus.idle;
                  _cidadeErro   = null;
                  _cidadeValidada = null;
                  _bairroStatus = _FieldStatus.idle;
                  _bairroErro   = null;
                  _bairroValidado = null;
                });
              },
              child: const Padding(padding: EdgeInsets.only(right: 10),
                child: Icon(Icons.close_rounded, color: TabuColors.subtle, size: 16))),
        ])),

      // Mensagem de erro/sucesso cidade
      if (_cidadeStatus == _FieldStatus.invalido && _cidadeErro != null)
        Padding(
          padding: const EdgeInsets.only(top: 5, left: 2),
          child: Row(children: [
            const Icon(Icons.info_outline, color: Color(0xFFE85D5D), size: 11),
            const SizedBox(width: 4),
            Expanded(child: Text(_cidadeErro!,
              style: const TextStyle(fontFamily: TabuTypography.bodyFont,
                  fontSize: 10, letterSpacing: 0.8, color: Color(0xFFE85D5D)))),
          ])),

      if (_cidadeStatus == _FieldStatus.valido)
        Padding(
          padding: const EdgeInsets.only(top: 5, left: 2),
          child: Row(children: [
            const Icon(Icons.check_circle_outline,
                color: TabuColors.rosaPrincipal, size: 11),
            const SizedBox(width: 4),
            Text('Cidade confirmada em $_estadoSelecionado',
              style: const TextStyle(fontFamily: TabuTypography.bodyFont,
                  fontSize: 10, letterSpacing: 0.8, color: TabuColors.rosaPrincipal)),
          ])),
    ]);
  }

  // ── Campo bairro com validação inline ─────────────────────────────────────
  Widget _buildBairroField() {
    final focused = _bairroFocus.hasFocus;

    Color bordaColor;
    switch (_bairroStatus) {
      case _FieldStatus.valido:
        bordaColor = TabuColors.rosaPrincipal;
      case _FieldStatus.invalido:
        bordaColor = const Color(0xFFE85D5D);
      case _FieldStatus.validando:
        bordaColor = TabuColors.rosaPrincipal.withOpacity(0.5);
      case _FieldStatus.idle:
        bordaColor = focused ? TabuColors.rosaPrincipal : TabuColors.border;
    }

    Widget? sufixo;
    switch (_bairroStatus) {
      case _FieldStatus.validando:
        sufixo = const Padding(padding: EdgeInsets.only(right: 12),
          child: SizedBox(width: 14, height: 14,
            child: CircularProgressIndicator(
                color: TabuColors.rosaPrincipal, strokeWidth: 1.5)));
      case _FieldStatus.valido:
        sufixo = const Padding(padding: EdgeInsets.only(right: 10),
          child: Icon(Icons.check_circle_rounded,
              color: TabuColors.rosaPrincipal, size: 18));
      case _FieldStatus.invalido:
        sufixo = const Padding(padding: EdgeInsets.only(right: 10),
          child: Icon(Icons.cancel_rounded,
              color: Color(0xFFE85D5D), size: 18));
      case _FieldStatus.idle:
        sufixo = null;
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.location_city_outlined,
            color: _bairroStatus == _FieldStatus.valido
                ? TabuColors.rosaPrincipal
                : _bairroStatus == _FieldStatus.invalido
                    ? const Color(0xFFE85D5D)
                    : focused ? TabuColors.rosaPrincipal : TabuColors.subtle,
            size: 14),
        const SizedBox(width: 6),
        Text('BAIRRO *', style: TextStyle(
            fontFamily: TabuTypography.bodyFont, fontSize: 9,
            fontWeight: FontWeight.w700, letterSpacing: 2.5,
            color: _bairroStatus == _FieldStatus.valido
                ? TabuColors.rosaPrincipal
                : _bairroStatus == _FieldStatus.invalido
                    ? const Color(0xFFE85D5D)
                    : focused ? TabuColors.rosaPrincipal : TabuColors.subtle)),
        if (!_cidadePreenchida) ...[
          const SizedBox(width: 8),
          const Text('(confirme a cidade primeiro)',
            style: TextStyle(fontFamily: TabuTypography.bodyFont,
                fontSize: 9, color: TabuColors.subtle, letterSpacing: 0.5)),
        ],
      ]),
      const SizedBox(height: 6),

      Container(
        decoration: BoxDecoration(
          color: TabuColors.bgCard,
          border: Border.all(color: bordaColor,
              width: focused || _bairroStatus != _FieldStatus.idle ? 1.5 : 0.8)),
        child: Row(children: [
          const SizedBox(width: 16),
          Expanded(child: TextFormField(
            controller: _bairroCtrl,
            focusNode:  _bairroFocus,
            enabled:    _cidadePreenchida,
            style: TextStyle(fontFamily: TabuTypography.bodyFont,
                fontSize: 15, fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
                color: _cidadePreenchida ? TabuColors.branco : TabuColors.subtle),
            cursorColor: TabuColors.rosaPrincipal,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Bairro obrigatório';
              if (_bairroStatus == _FieldStatus.invalido) return _bairroErro;
              return null;
            },
            decoration: InputDecoration(
              border: InputBorder.none, isDense: true,
              hintText: _cidadePreenchida
                  ? 'Ex: Setor Bueno, Jardins...'
                  : 'Confirme a cidade primeiro',
              hintStyle: const TextStyle(fontFamily: TabuTypography.bodyFont,
                  fontSize: 13, color: TabuColors.subtle),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              errorStyle: const TextStyle(height: 0)),
            onChanged: (v) {
              setState(() {
                _bairroStatus   = _FieldStatus.idle;
                _bairroErro     = null;
                _mapaConfirmado = false;
              });
              _bairroUltimaDigitacao = DateTime.now();
              final capturedTime = _bairroUltimaDigitacao!;
              Future.delayed(const Duration(milliseconds: 800), () {
                if (_bairroUltimaDigitacao == capturedTime && mounted) {
                  final current = _bairroCtrl.text.trim();
                  if (current.isNotEmpty && _cidadePreenchida) {
                    _validarBairro(current);
                  }
                }
              });
            },
            onEditingComplete: () {
              FocusScope.of(context).unfocus();
              final v = _bairroCtrl.text.trim();
              if (v.isNotEmpty && _cidadePreenchida && v != _bairroValidado) {
                _validarBairro(v);
              }
            },
          )),
          if (sufixo != null) sufixo,
        ])),

      if (_bairroStatus == _FieldStatus.invalido && _bairroErro != null)
        Padding(
          padding: const EdgeInsets.only(top: 5, left: 2),
          child: Row(children: [
            const Icon(Icons.info_outline, color: Color(0xFFE85D5D), size: 11),
            const SizedBox(width: 4),
            Expanded(child: Text(_bairroErro!,
              style: const TextStyle(fontFamily: TabuTypography.bodyFont,
                  fontSize: 10, letterSpacing: 0.8, color: Color(0xFFE85D5D)))),
          ])),

      if (_bairroStatus == _FieldStatus.valido)
        Padding(
          padding: const EdgeInsets.only(top: 5, left: 2),
          child: Row(children: [
            const Icon(Icons.check_circle_outline,
                color: TabuColors.rosaPrincipal, size: 11),
            const SizedBox(width: 4),
            Text('Bairro confirmado em ${_cidadeCtrl.text.trim()}',
              style: const TextStyle(fontFamily: TabuTypography.bodyFont,
                  fontSize: 10, letterSpacing: 0.8, color: TabuColors.rosaPrincipal)),
          ])),

      if (_bairroStatus == _FieldStatus.validando)
        const Padding(
          padding: EdgeInsets.only(top: 5, left: 2),
          child: Text('Verificando bairro...',
            style: TextStyle(fontFamily: TabuTypography.bodyFont,
                fontSize: 10, letterSpacing: 0.8, color: TabuColors.subtle))),
    ]);
  }

  // ── Mini-mapa ──────────────────────────────────────────────────────────────
  Widget _buildMiniMap() {
    final pos        = LatLng(_latitude!, _longitude!);
    final enderecoOk = _localizacaoCompleta;
    final texto      = _enderecoCompleto;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      height: 200,
      decoration: BoxDecoration(
        border: Border.all(
          color: _mapaConfirmado
              ? TabuColors.rosaPrincipal
              : enderecoOk ? TabuColors.borderMid : TabuColors.border.withOpacity(0.4),
          width: _mapaConfirmado ? 1.5 : 0.8)),
      child: Stack(children: [

        GoogleMap(
          initialCameraPosition: CameraPosition(target: pos, zoom: 15),
          onMapCreated: (ctrl) => _mapController = ctrl,
          markers: {
            Marker(
              markerId: const MarkerId('perfil'),
              position: pos,
              draggable: enderecoOk,
              onDragEnd: _onPinDragged,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
            ),
          },
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
          style: _mapStyle,
        ),

        if (!enderecoOk)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.edit_location_alt_outlined,
                      color: TabuColors.subtle, size: 24),
                  const SizedBox(height: 8),
                  Text(_getMensagemMapa(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: TabuTypography.bodyFont,
                        fontSize: 11, letterSpacing: 1, color: TabuColors.subtle)),
                ]))),
          ),

        if (enderecoOk && !_mapaConfirmado)
          Positioned(top: 10, left: 0, right: 0,
            child: Center(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.65),
                border: Border.all(color: TabuColors.borderMid, width: 0.6)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.open_with_rounded, color: TabuColors.subtle, size: 11),
                SizedBox(width: 5),
                Text('Arraste o pin para ajustar',
                  style: TextStyle(fontFamily: TabuTypography.bodyFont,
                      fontSize: 10, letterSpacing: 1, color: TabuColors.subtle)),
              ])))),

        Positioned(bottom: 10, right: 10,
          child: GestureDetector(
            onTap: enderecoOk
                ? () { HapticFeedback.lightImpact(); setState(() => _mapaConfirmado = true); }
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _mapaConfirmado
                    ? TabuColors.rosaPrincipal
                    : enderecoOk
                        ? Colors.black.withOpacity(0.75)
                        : Colors.black.withOpacity(0.3),
                border: Border.all(
                  color: _mapaConfirmado
                      ? TabuColors.rosaPrincipal
                      : enderecoOk ? TabuColors.borderMid : TabuColors.border.withOpacity(0.3),
                  width: 0.8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  _mapaConfirmado ? Icons.check_circle_rounded : Icons.check_rounded,
                  color: enderecoOk ? Colors.white : TabuColors.subtle, size: 12),
                const SizedBox(width: 6),
                Text(_mapaConfirmado ? 'CONFIRMADO' : 'CONFIRMAR',
                  style: TextStyle(fontFamily: TabuTypography.bodyFont,
                      fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2,
                      color: enderecoOk ? Colors.white : TabuColors.subtle)),
              ]))),
        ),

        if (enderecoOk && texto.isNotEmpty)
          Positioned(bottom: 10, left: 10,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 210),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              color: Colors.black.withOpacity(0.65),
              child: Text(texto,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: TabuTypography.bodyFont,
                    fontSize: 9, letterSpacing: 0.3, color: TabuColors.subtle)))),
      ]),
    );
  }

  String _getMensagemMapa() {
    if (!_estadoPreenchido)                                 return 'Selecione seu estado\npara começar';
    if (!_cidadePreenchida)                                 return 'Selecione sua cidade\npara posicionar o mapa';
    if (_bairroStatus == _FieldStatus.validando)            return 'Verificando bairro...';
    if (_bairroStatus == _FieldStatus.invalido)             return 'Corrija o bairro\npara confirmar';
    if (_bairroCtrl.text.trim().isEmpty)                    return 'Digite seu bairro\npara confirmar';
    return 'Complete a localização\npara confirmar';
  }
}

// ── Estilo escuro do mapa ──────────────────────────────────────────────────────
const _mapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#0d0015"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#746262"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#0d0015"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#2a1a2e"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#1a0a1f"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#3d1a3a"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#1a0d1f"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#06000d"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#1a0d1f"}]},
  {"featureType":"administrative","elementType":"geometry.stroke","stylers":[{"color":"#3d1a3a"}]}
]
''';

// ══════════════════════════════════════════════════════════════════════════════
//  WIDGETS INTERNOS
// ══════════════════════════════════════════════════════════════════════════════
class _AvatarPicker extends StatelessWidget {
  final File? imageFile; final String avatarUrl;
  final bool uploading; final double uploadProgress;
  final VoidCallback onTap;
  const _AvatarPicker({required this.imageFile, required this.avatarUrl,
      required this.uploading, required this.uploadProgress, required this.onTap});

  Widget _placeholder() => Container(color: TabuColors.bgAlt,
      child: const Icon(Icons.person_outline, color: TabuColors.rosaPrincipal, size: 40));

  @override
  Widget build(BuildContext context) {
    final hasImage = imageFile != null || avatarUrl.isNotEmpty;
    return GestureDetector(onTap: onTap,
      child: Column(children: [
        Stack(alignment: Alignment.center, children: [
          Container(width: 108, height: 108,
            decoration: BoxDecoration(shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: TabuColors.glow, blurRadius: 24, spreadRadius: 2)],
              gradient: const LinearGradient(
                  colors: [TabuColors.rosaDeep, TabuColors.rosaPrincipal],
                  begin: Alignment.topLeft, end: Alignment.bottomRight))),
          Container(width: 100, height: 100,
            decoration: BoxDecoration(shape: BoxShape.circle,
                border: Border.all(color: TabuColors.bg, width: 3)),
            child: ClipOval(child: imageFile != null
                ? Image.file(imageFile!, fit: BoxFit.cover)
                : avatarUrl.isNotEmpty
                    ? Image.network(avatarUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder())
                    : _placeholder())),
          if (hasImage)
            Positioned.fill(child: ClipOval(child: Container(
              color: Colors.black.withOpacity(0.38),
              child: const Center(child: Icon(Icons.photo_camera,
                  color: TabuColors.branco, size: 26))))),
          if (uploading)
            SizedBox(width: 108, height: 108,
              child: CircularProgressIndicator(value: uploadProgress,
                  strokeWidth: 3, color: TabuColors.rosaPrincipal,
                  backgroundColor: TabuColors.border)),
          if (!uploading)
            Positioned(bottom: 2, right: 2,
              child: Container(width: 30, height: 30,
                decoration: BoxDecoration(color: TabuColors.rosaPrincipal,
                    shape: BoxShape.circle,
                    border: Border.all(color: TabuColors.bg, width: 2)),
                child: const Icon(Icons.edit, color: TabuColors.branco, size: 13))),
        ]),
        const SizedBox(height: 8),
        Text(uploading
            ? 'ENVIANDO ${(uploadProgress * 100).toInt()}%'
            : 'TOQUE PARA ALTERAR',
          style: TextStyle(fontFamily: TabuTypography.bodyFont,
              fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 3,
              color: uploading ? TabuColors.rosaPrincipal : TabuColors.subtle)),
      ]));
  }
}

class _SaveButton extends StatelessWidget {
  final bool saving, uploading; final double progress; final VoidCallback onTap;
  const _SaveButton({required this.saving, required this.uploading,
      required this.progress, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final busy  = saving || uploading;
    final label = uploading
        ? 'ENVIANDO FOTO ${(progress * 100).toInt()}%'
        : saving ? 'SALVANDO...' : 'SALVAR ALTERAÇÕES';
    return GestureDetector(onTap: busy ? null : onTap,
      child: Container(
        width: double.infinity, height: 52,
        decoration: BoxDecoration(
          color: busy ? TabuColors.bgCard : TabuColors.rosaPrincipal,
          border: Border.all(color: busy ? TabuColors.border : TabuColors.rosaPrincipal, width: 0.8)),
        child: Stack(alignment: Alignment.center, children: [
          if (uploading)
            Positioned.fill(child: FractionallySizedBox(
              alignment: Alignment.centerLeft, widthFactor: progress,
              child: Container(color: TabuColors.rosaPrincipal.withOpacity(0.25)))),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (busy)
              const SizedBox(width: 14, height: 14,
                child: CircularProgressIndicator(color: TabuColors.rosaPrincipal, strokeWidth: 1.5))
            else
              const Icon(Icons.check, color: TabuColors.branco, size: 16),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(fontFamily: TabuTypography.bodyFont,
                fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 3,
                color: busy ? TabuColors.subtle : TabuColors.branco)),
          ]),
        ])));
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 5, height: 5, decoration: const BoxDecoration(
        color: TabuColors.rosaPrincipal, shape: BoxShape.circle)),
    const SizedBox(width: 8),
    Text(label, style: const TextStyle(fontFamily: TabuTypography.bodyFont,
        fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 3,
        color: TabuColors.rosaPrincipal)),
    const SizedBox(width: 12),
    Expanded(child: Container(height: 0.5, color: TabuColors.border)),
  ]);
}

class _TabuField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label, hint; final IconData icon;
  final int maxLines; final int? maxLength;
  final TextCapitalization textCapitalization;
  final TextInputType keyboardType; final TextInputAction textInputAction;
  final String? Function(String?)? validator; final VoidCallback? onEditingComplete;

  const _TabuField({
    required this.controller, required this.focusNode,
    required this.label, required this.hint, required this.icon,
    this.maxLines = 1, this.maxLength,
    this.textCapitalization = TextCapitalization.none,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.validator, this.onEditingComplete,
  });

  @override
  State<_TabuField> createState() => _TabuFieldState();
}

class _TabuFieldState extends State<_TabuField> {
  bool _focused = false;
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() {
      if (mounted) setState(() => _focused = widget.focusNode.hasFocus);
    });
  }
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Icon(widget.icon,
            color: _focused ? TabuColors.rosaPrincipal : TabuColors.subtle, size: 14),
        const SizedBox(width: 6),
        Text(widget.label, style: TextStyle(fontFamily: TabuTypography.bodyFont,
            fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2.5,
            color: _focused ? TabuColors.rosaPrincipal : TabuColors.subtle)),
      ]),
      const SizedBox(height: 6),
      TextFormField(
        controller: widget.controller, focusNode: widget.focusNode,
        maxLines: widget.maxLines, maxLength: widget.maxLength,
        textCapitalization: widget.textCapitalization,
        keyboardType: widget.keyboardType, textInputAction: widget.textInputAction,
        validator: widget.validator, onEditingComplete: widget.onEditingComplete,
        style: const TextStyle(fontFamily: TabuTypography.bodyFont,
            fontSize: 15, fontWeight: FontWeight.w500,
            letterSpacing: 0.5, color: TabuColors.branco),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: const TextStyle(fontFamily: TabuTypography.bodyFont,
              fontSize: 13, color: TabuColors.subtle),
          counterStyle: const TextStyle(fontFamily: TabuTypography.bodyFont,
              fontSize: 9, color: TabuColors.subtle),
          filled: true, fillColor: TabuColors.bgCard,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: const OutlineInputBorder(borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: TabuColors.border, width: 0.8)),
          enabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: TabuColors.border, width: 0.8)),
          focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: TabuColors.rosaPrincipal, width: 1.5)),
          errorBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: Color(0xFFE85D5D), width: 1)),
          focusedErrorBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: Color(0xFFE85D5D), width: 1.5)),
          errorStyle: const TextStyle(fontFamily: TabuTypography.bodyFont,
              fontSize: 10, letterSpacing: 1, color: Color(0xFFE85D5D)))),
    ]);
}

class _ReadOnlyField extends StatelessWidget {
  final String label, value; final IconData icon;
  const _ReadOnlyField({required this.label, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Icon(icon, color: TabuColors.subtle, size: 14),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontFamily: TabuTypography.bodyFont,
            fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2.5,
            color: TabuColors.subtle)),
      ]),
      const SizedBox(height: 6),
      Container(width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: TabuColors.bgCard,
            border: Border.all(color: TabuColors.border, width: 0.8)),
        child: Text(value, style: const TextStyle(fontFamily: TabuTypography.bodyFont,
            fontSize: 15, fontWeight: FontWeight.w500, color: TabuColors.subtle))),
    ]);
}

class _InfoBox extends StatelessWidget {
  final String text;
  const _InfoBox({required this.text});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: TabuColors.rosaPrincipal.withOpacity(0.06),
      border: Border.all(color: TabuColors.border, width: 0.8)),
    child: Row(children: [
      const Icon(Icons.info_outline, color: TabuColors.subtle, size: 14),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(
          fontFamily: TabuTypography.bodyFont, fontSize: 11,
          letterSpacing: 0.5, color: TabuColors.subtle))),
    ]));
}

class _SheetOption extends StatelessWidget {
  final IconData icon; final String label;
  final VoidCallback onTap; final Color color;
  const _SheetOption({required this.icon, required this.label,
      required this.onTap, this.color = TabuColors.branco});
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap,
    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 16),
        Text(label, style: TextStyle(fontFamily: TabuTypography.bodyFont,
            fontSize: 14, fontWeight: FontWeight.w600,
            letterSpacing: 2.5, color: color)),
      ])));
}

class _EditBg extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = TabuColors.bg);
    canvas.drawCircle(
      Offset(size.width * 0.9, size.height * 0.08), size.width * 0.6,
      Paint()..shader = RadialGradient(colors: [
        TabuColors.rosaPrincipal.withOpacity(0.07), Colors.transparent,
      ]).createShader(Rect.fromCircle(
          center: Offset(size.width * 0.9, size.height * 0.08),
          radius: size.width * 0.6)));
  }
  @override
  bool shouldRepaint(_EditBg _) => false;
}
