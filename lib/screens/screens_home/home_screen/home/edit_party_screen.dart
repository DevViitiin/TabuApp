// lib/screens/screens_administrative/home_screen/edit_party_screen.dart
//
// Tela de edição de festa — acessível apenas por admin ou criador da festa.
// Aberta a partir de _FestaDetalheSheet em HomeScreenAdministrative.
//
// Campos editáveis: Nome, Descrição, Local (autocomplete + mapa), Data início/fim, Banner.
//
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/models/party_model.dart';
import 'package:tabuapp/services/services_administrative/party_service.dart';

const _kPlacesApiKey = 'AIzaSyDt4lIuxWvTESG21ok0YexdTgskf8NaNZ4';

class EditPartyScreen extends StatefulWidget {
  final PartyModel festa;
  final Map<String, dynamic> userData;

  const EditPartyScreen({
    super.key,
    required this.festa,
    required this.userData,
  });

  @override
  State<EditPartyScreen> createState() => _EditPartyScreenState();
}

class _EditPartyScreenState extends State<EditPartyScreen> {
  // ── Controllers ────────────────────────────────────────────────────────────
  late final TextEditingController _nomeCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _localCtrl;
  final _nomeFocus  = FocusNode();
  final _descFocus  = FocusNode();
  final _localFocus = FocusNode();

  // ── State ──────────────────────────────────────────────────────────────────
  late DateTime _dataInicio;
  late DateTime _dataFim;

  /// Novo banner escolhido pelo usuário (File local). Null = não alterou.
  File?   _novoBanner;

  /// URL do banner atual (vindo da festa). Pode ser zerado para remover.
  String? _bannerUrlAtual;

  bool   _salvando   = false;
  bool   _uploading  = false;
  double _uploadProg = 0;

  double?              _latitude;
  double?              _longitude;
  bool                 _mapaConfirmado = false;
  GoogleMapController?  _mapController;

  // ── Helpers ────────────────────────────────────────────────────────────────
  String get _uid =>
      FirebaseAuth.instance.currentUser?.uid ??
      (widget.userData['uid'] as String? ?? '');

  bool get _temLocal => _localCtrl.text.trim().isNotEmpty;

  /// True se o banner foi alterado de alguma forma.
  bool get _bannerAlterado => _novoBanner != null || _bannerUrlAtual != widget.festa.bannerUrl;

  @override
  void initState() {
    super.initState();

    final f = widget.festa;

    // Pré-popula os campos com os valores atuais da festa
    _nomeCtrl  = TextEditingController(text: f.nome);
    _descCtrl  = TextEditingController(text: f.descricao);
    _localCtrl = TextEditingController(text: f.local ?? '');

    _dataInicio     = f.dataInicio;
    _dataFim        = f.dataFim;
    _bannerUrlAtual = f.bannerUrl;

    // Se já tinha coords na festa, pré-carrega no mapa
    if (f.hasCoords) {
      _latitude       = f.latitude;
      _longitude      = f.longitude;
      _mapaConfirmado = f.hasLocal; // considera confirmado se já tinha endereço
    }

    _localCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _descCtrl.dispose();
    _localCtrl.dispose();
    _nomeFocus.dispose();
    _descFocus.dispose();
    _localFocus.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ── Mapa ───────────────────────────────────────────────────────────────────
  void _animateMap(double lat, double lng) {
    _mapController?.animateCamera(CameraUpdate.newLatLng(LatLng(lat, lng)));
  }

  void _onPinDragged(LatLng pos) {
    setState(() {
      _latitude       = pos.latitude;
      _longitude      = pos.longitude;
      _mapaConfirmado = false;
    });
  }

  void _limparLocal() {
    setState(() {
      _localCtrl.clear();
      _latitude       = null;
      _longitude      = null;
      _mapaConfirmado = false;
    });
  }

  // ── Banner picker ──────────────────────────────────────────────────────────
  Future<void> _pickBanner() async {
    HapticFeedback.selectionClick();

    final temBannerAtual = _novoBanner != null ||
        (_bannerUrlAtual != null && _bannerUrlAtual!.isNotEmpty);

    showModalBottomSheet(
      context: context,
      backgroundColor: TabuColors.bgAlt,
      shape: const RoundedRectangleBorder(),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36, height: 3,
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            decoration: BoxDecoration(
              color: TabuColors.border, borderRadius: BorderRadius.circular(2)),
          ),
          const Text('BANNER DA FESTA',
            style: TextStyle(fontFamily: TabuTypography.displayFont,
                fontSize: 18, letterSpacing: 5, color: TabuColors.branco)),
          const SizedBox(height: 16),
          Container(height: 0.5, color: TabuColors.border),
          _PickerTile(icon: Icons.photo_camera_outlined, label: 'CÂMERA',
            onTap: () async {
              Navigator.pop(context);
              final f = await ImagePicker().pickImage(
                  source: ImageSource.camera, maxWidth: 1200, imageQuality: 88);
              if (f != null && mounted) setState(() => _novoBanner = File(f.path));
            }),
          Container(height: 0.5, color: TabuColors.border),
          _PickerTile(icon: Icons.photo_library_outlined, label: 'GALERIA',
            onTap: () async {
              Navigator.pop(context);
              final f = await ImagePicker().pickImage(
                  source: ImageSource.gallery, maxWidth: 1200, imageQuality: 88);
              if (f != null && mounted) setState(() => _novoBanner = File(f.path));
            }),
          if (temBannerAtual) ...[
            Container(height: 0.5, color: TabuColors.border),
            _PickerTile(
              icon: Icons.delete_outline, label: 'REMOVER BANNER',
              color: const Color(0xFFE85D5D),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _novoBanner     = null;
                  _bannerUrlAtual = null;
                });
              }),
          ],
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  // ── Date / time pickers ────────────────────────────────────────────────────
  Future<void> _pickDataInicio() async {
    final now  = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dataInicio,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: _datePickerTheme,
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dataInicio),
      builder: _datePickerTheme,
    );
    if (time == null || !mounted) return;

    setState(() {
      _dataInicio = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      if (_dataFim.isBefore(_dataInicio)) {
        _dataFim = _dataInicio.add(const Duration(hours: 4));
      }
    });
  }

  Future<void> _pickDataFim() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dataFim,
      firstDate: _dataInicio,
      lastDate: _dataInicio.add(const Duration(days: 3)),
      builder: _datePickerTheme,
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dataFim),
      builder: _datePickerTheme,
    );
    if (time == null || !mounted) return;

    setState(() =>
      _dataFim = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Widget Function(BuildContext, Widget?) get _datePickerTheme =>
      (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: TabuColors.rosaPrincipal,
            onPrimary: TabuColors.branco,
            surface: TabuColors.bgAlt,
            onSurface: TabuColors.branco,
          ),
          dialogBackgroundColor: TabuColors.bgAlt,
        ),
        child: child!,
      );

  // ── Salvar ─────────────────────────────────────────────────────────────────
  Future<void> _salvar() async {
    if (_nomeCtrl.text.trim().isEmpty) {
      _showSnack('Nome da festa obrigatório');
      return;
    }
    if (_temLocal && _latitude == null) {
      _showSnack('Selecione um endereço da lista para fixar no mapa');
      return;
    }

    setState(() { _salvando = true; _uploading = _novoBanner != null; _uploadProg = 0; });
    FocusScope.of(context).unfocus();

    try {
      // ── Upload de novo banner (se houver) ──────────────────────────────
      String? bannerUrl = _bannerUrlAtual; // mantém a atual por padrão

      if (_novoBanner != null) {
        final ref = FirebaseStorage.instance
            .ref('festas/$_uid/${DateTime.now().millisecondsSinceEpoch}.jpg');
        final task = ref.putFile(
            _novoBanner!, SettableMetadata(contentType: 'image/jpeg'));
        task.snapshotEvents.listen((snap) {
          if (!mounted) return;
          setState(() => _uploadProg =
              snap.bytesTransferred / (snap.totalBytes == 0 ? 1 : snap.totalBytes));
        });
        await task;
        bannerUrl = await ref.getDownloadURL();
        if (mounted) setState(() => _uploading = false);
      }

      // ── Monta mapa de updates — só envia campos que mudaram ───────────
      final updates = <String, dynamic>{
        'nome':        _nomeCtrl.text.trim(),
        'descricao':   _descCtrl.text.trim(),
        'data_inicio': _dataInicio.millisecondsSinceEpoch,
        'data_fim':    _dataFim.millisecondsSinceEpoch,
      };

      // Local
      if (_temLocal) {
        updates['local']     = _localCtrl.text.trim();
        updates['latitude']  = _latitude;
        updates['longitude'] = _longitude;
      } else {
        // Remove o local se foi apagado
        updates['local']     = null;
        updates['latitude']  = null;
        updates['longitude'] = null;
      }

      // Banner
      if (bannerUrl != null && bannerUrl.isNotEmpty) {
        updates['banner_url'] = bannerUrl;
      } else {
        updates['banner_url'] = null;
      }

      await PartyService.instance.updateFesta(widget.festa.id, updates);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('editFesta error: $e');
      if (mounted) {
        setState(() { _salvando = false; _uploading = false; });
        _showSnack('Erro ao salvar. Tente novamente.');
      }
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: TabuColors.bgAlt,
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(),
      margin: const EdgeInsets.all(16),
      content: Text(msg,
        style: const TextStyle(fontFamily: TabuTypography.bodyFont,
            fontSize: 12, letterSpacing: 1.5, color: TabuColors.branco)),
    ));
  }

  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TabuColors.bg,
      body: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _EditFestaBg())),

        // Barra de gradiente no topo
        Positioned(top: 0, left: 0, right: 0,
          child: Container(height: 2,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent,
                TabuColors.rosaDeep, TabuColors.rosaPrincipal,
                TabuColors.rosaClaro,
                TabuColors.rosaPrincipal, TabuColors.rosaDeep,
                Colors.transparent,
              ])))),

        SafeArea(child: Column(children: [

          // ── App Bar ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 10, 16, 0),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: TabuColors.dim, size: 16),
                onPressed: () => Navigator.pop(context),
              ),
              const Expanded(
                child: Text('EDITAR FESTA',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: TabuTypography.displayFont,
                    fontSize: 20, letterSpacing: 5,
                    color: TabuColors.branco,
                  )),
              ),
              GestureDetector(
                onTap: (_salvando || _uploading) ? null : _salvar,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: (_salvando || _uploading)
                        ? TabuColors.bgCard
                        : TabuColors.rosaPrincipal,
                    border: Border.all(color: TabuColors.rosaPrincipal, width: 0.8),
                  ),
                  child: (_salvando || _uploading)
                      ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(
                              color: TabuColors.rosaPrincipal, strokeWidth: 1.5))
                      : const Text('SALVAR',
                          style: TextStyle(
                            fontFamily: TabuTypography.bodyFont,
                            fontSize: 11, fontWeight: FontWeight.w700,
                            letterSpacing: 2.5, color: TabuColors.branco,
                          )),
                ),
              ),
            ]),
          ),

          Container(height: 0.5, margin: const EdgeInsets.only(top: 10),
              color: TabuColors.border),

          // ── Badge "EDITANDO" ───────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            color: TabuColors.rosaPrincipal.withOpacity(0.06),
            child: Row(children: [
              const Icon(Icons.edit_rounded,
                  color: TabuColors.rosaPrincipal, size: 10),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  widget.festa.nome.toUpperCase(),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 9, fontWeight: FontWeight.w700,
                    letterSpacing: 2.5, color: TabuColors.rosaPrincipal,
                  ),
                ),
              ),
            ]),
          ),

          Container(height: 0.5, color: TabuColors.border),

          // ── Formulário ────────────────────────────────────────────────────
          Expanded(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.translucent,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // BANNER
                    _buildBannerPicker(),
                    const SizedBox(height: 28),

                    // NOME
                    _buildSectionLabel('NOME DA FESTA',
                        Icons.local_fire_department_outlined),
                    const SizedBox(height: 8),
                    _buildField(
                      ctrl: _nomeCtrl, focus: _nomeFocus,
                      hint: 'Ex: Neon Shadows',
                      nextFocus: _localFocus,
                      capitalize: TextCapitalization.words,
                    ),
                    const SizedBox(height: 24),

                    // LOCAL — opcional
                    _buildLocalSectionLabel(),
                    const SizedBox(height: 8),
                    _buildLocalField(),
                    const SizedBox(height: 6),

                    if (!_temLocal)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(children: [
                          const Icon(Icons.info_outline_rounded,
                              color: TabuColors.subtle, size: 11),
                          const SizedBox(width: 6),
                          Text('Deixe em branco para divulgar depois',
                            style: TextStyle(
                              fontFamily: TabuTypography.bodyFont,
                              fontSize: 10, letterSpacing: 0.3,
                              color: TabuColors.subtle.withOpacity(0.7),
                            )),
                        ]),
                      ),

                    if (_latitude != null) _buildMiniMap(),

                    const SizedBox(height: 24),

                    // DATA / HORA
                    _buildSectionLabel('DATA & HORÁRIO', Icons.schedule_outlined),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: _buildDateTile(
                        label: 'INÍCIO', value: _dataInicio,
                        onTap: _pickDataInicio,
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _buildDateTile(
                        label: 'FIM', value: _dataFim,
                        onTap: _pickDataFim,
                      )),
                    ]),
                    const SizedBox(height: 24),

                    // DESCRIÇÃO
                    _buildSectionLabel('DESCRIÇÃO', Icons.edit_note_outlined),
                    const SizedBox(height: 8),
                    _buildField(
                      ctrl: _descCtrl, focus: _descFocus,
                      hint: 'Conta como vai ser a noite...',
                      maxLines: 5, maxLength: 400,
                      action: TextInputAction.newline,
                    ),

                    // Progress de upload
                    if (_uploading)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ENVIANDO BANNER ${(_uploadProg * 100).toInt()}%',
                              style: const TextStyle(
                                fontFamily: TabuTypography.bodyFont,
                                fontSize: 9, letterSpacing: 2,
                                color: TabuColors.rosaPrincipal,
                              )),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(1),
                              child: LinearProgressIndicator(
                                value: _uploadProg,
                                backgroundColor: TabuColors.border,
                                color: TabuColors.rosaPrincipal,
                                minHeight: 2,
                              )),
                          ]),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ])),
      ]),
    );
  }

  // ── Banner Picker ──────────────────────────────────────────────────────────
  Widget _buildBannerPicker() {
    final temBannerLocal  = _novoBanner != null;
    final temBannerRemoto = _bannerUrlAtual != null && _bannerUrlAtual!.isNotEmpty;
    final temBanner       = temBannerLocal || temBannerRemoto;

    return GestureDetector(
      onTap: _pickBanner,
      child: Container(
        height: 180, width: double.infinity,
        decoration: BoxDecoration(
          color: TabuColors.bgCard,
          border: Border.all(
            color: temBanner
                ? TabuColors.rosaPrincipal.withOpacity(0.5)
                : TabuColors.border,
            width: temBanner ? 1 : 0.8,
          )),
        child: temBanner
            ? Stack(fit: StackFit.expand, children: [
                // Mostra preview local se acabou de escolher, senão a URL atual
                temBannerLocal
                    ? Image.file(_novoBanner!, fit: BoxFit.cover)
                    : Image.network(_bannerUrlAtual!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _bannerPlaceholder()),
                Positioned.fill(child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black.withOpacity(0.4)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    )))),
                Positioned(bottom: 10, right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      border: Border.all(color: TabuColors.borderMid, width: 0.6),
                    ),
                    child: const Text('TROCAR',
                      style: TextStyle(fontFamily: TabuTypography.bodyFont,
                          fontSize: 9, letterSpacing: 2,
                          color: TabuColors.branco)))),
                // Badge "NOVO" quando alterou o banner
                if (temBannerLocal)
                  Positioned(top: 10, left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      color: TabuColors.rosaPrincipal,
                      child: const Text('NOVO',
                        style: TextStyle(fontFamily: TabuTypography.bodyFont,
                            fontSize: 8, fontWeight: FontWeight.w700,
                            letterSpacing: 2, color: Colors.white)))),
              ])
            : _bannerPlaceholder(),
      ),
    );
  }

  Widget _bannerPlaceholder() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(width: 44, height: 44,
        decoration: BoxDecoration(color: TabuColors.bgAlt,
            border: Border.all(color: TabuColors.border, width: 0.8)),
        child: const Icon(Icons.add_photo_alternate_outlined,
            color: TabuColors.rosaPrincipal, size: 20)),
      const SizedBox(height: 12),
      const Text('ADICIONAR BANNER',
        style: TextStyle(fontFamily: TabuTypography.bodyFont,
            fontSize: 10, fontWeight: FontWeight.w700,
            letterSpacing: 3, color: TabuColors.subtle)),
      const SizedBox(height: 4),
      const Text('Recomendado: 1200 × 600px',
        style: TextStyle(fontFamily: TabuTypography.bodyFont,
            fontSize: 9, letterSpacing: 0.5, color: TabuColors.border)),
    ],
  );

  // ── Section label ──────────────────────────────────────────────────────────
  Widget _buildSectionLabel(String label, IconData icon) {
    return Row(children: [
      Icon(icon, color: TabuColors.rosaPrincipal, size: 12),
      const SizedBox(width: 7),
      Text(label,
        style: const TextStyle(fontFamily: TabuTypography.bodyFont,
            fontSize: 9, fontWeight: FontWeight.w700,
            letterSpacing: 3, color: TabuColors.rosaPrincipal)),
      const SizedBox(width: 10),
      Expanded(child: Container(height: 0.5,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [TabuColors.border, Colors.transparent])))),
    ]);
  }

  // ── Local section label ────────────────────────────────────────────────────
  Widget _buildLocalSectionLabel() {
    return Row(children: [
      Icon(Icons.location_on_outlined,
          color: _temLocal ? TabuColors.rosaPrincipal : TabuColors.subtle,
          size: 12),
      const SizedBox(width: 7),
      Text('LOCAL',
        style: TextStyle(fontFamily: TabuTypography.bodyFont,
            fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 3,
            color: _temLocal ? TabuColors.rosaPrincipal : TabuColors.subtle)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: TabuColors.bgCard,
          border: Border.all(color: TabuColors.border, width: 0.6),
        ),
        child: const Text('OPCIONAL',
          style: TextStyle(fontFamily: TabuTypography.bodyFont,
              fontSize: 7, fontWeight: FontWeight.w600,
              letterSpacing: 1.5, color: TabuColors.subtle)),
      ),
      const SizedBox(width: 8),
      Expanded(child: Container(height: 0.5,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [TabuColors.border, Colors.transparent])))),
      if (_temLocal)
        GestureDetector(
          onTap: _limparLocal,
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.close_rounded,
                  color: TabuColors.subtle.withOpacity(0.6), size: 12),
              const SizedBox(width: 3),
              Text('LIMPAR',
                style: TextStyle(fontFamily: TabuTypography.bodyFont,
                    fontSize: 8, letterSpacing: 1.5,
                    color: TabuColors.subtle.withOpacity(0.6))),
            ]),
          )),
    ]);
  }

  // ── Google Places autocomplete ─────────────────────────────────────────────
  Widget _buildLocalField() {
    return GooglePlaceAutoCompleteTextField(
      textEditingController: _localCtrl,
      googleAPIKey: _kPlacesApiKey,
      focusNode: _localFocus,
      inputDecoration: InputDecoration(
        hintText: 'Ex: Club Noir, São Paulo  (opcional)',
        hintStyle: const TextStyle(fontFamily: TabuTypography.bodyFont,
            fontSize: 13, color: TabuColors.subtle),
        filled: true,
        fillColor: const Color(0xFF0D0115),
        prefixIcon: const Icon(Icons.search_rounded,
            color: TabuColors.subtle, size: 18),
        suffixIcon: _mapaConfirmado
            ? const Icon(Icons.check_circle_rounded,
                color: TabuColors.rosaPrincipal, size: 18)
            : _latitude != null
                ? const Icon(Icons.touch_app_rounded,
                    color: TabuColors.subtle, size: 18)
                : null,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: const OutlineInputBorder(borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: TabuColors.border, width: 0.8)),
        enabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: TabuColors.border, width: 0.8)),
        focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: TabuColors.rosaPrincipal, width: 1.5)),
      ),
      textStyle: const TextStyle(fontFamily: TabuTypography.bodyFont,
          fontSize: 15, fontWeight: FontWeight.w400,
          letterSpacing: 0.3, color: TabuColors.branco),
      debounceTime: 400,
      countries: const ['br'],
      isLatLngRequired: true,
      getPlaceDetailWithLatLng: (Prediction prediction) {
        final lat = double.tryParse(prediction.lat ?? '');
        final lng = double.tryParse(prediction.lng ?? '');
        if (lat != null && lng != null) {
          setState(() {
            _latitude       = lat;
            _longitude      = lng;
            _mapaConfirmado = false;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _animateMap(lat, lng);
          });
        }
      },
      itemClick: (Prediction prediction) {
        _localCtrl
          ..text = prediction.description ?? ''
          ..selection = TextSelection.fromPosition(
              TextPosition(offset: _localCtrl.text.length));
      },
      containerHorizontalPadding: 0,
      itemBuilder: (context, index, prediction) => Column(children: [
        Container(
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
                Text(prediction.structuredFormatting?.mainText ?? '',
                  style: const TextStyle(fontFamily: TabuTypography.bodyFont,
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: TabuColors.branco)),
                if ((prediction.structuredFormatting?.secondaryText ?? '').isNotEmpty)
                  Text(prediction.structuredFormatting!.secondaryText!,
                    style: const TextStyle(fontFamily: TabuTypography.bodyFont,
                        fontSize: 11, color: TabuColors.subtle)),
              ])),
          ])),
        Container(height: 0.5, color: TabuColors.border),
      ]),
    );
  }

  // ── Mini-mapa com pin arrastável ───────────────────────────────────────────
  Widget _buildMiniMap() {
    final pos = LatLng(_latitude!, _longitude!);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      height: 220,
      decoration: BoxDecoration(
        border: Border.all(
          color: _mapaConfirmado ? TabuColors.rosaPrincipal : TabuColors.borderMid,
          width: _mapaConfirmado ? 1.5 : 0.8,
        )),
      child: Stack(children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: pos, zoom: 16),
          onMapCreated: (ctrl) => _mapController = ctrl,
          markers: {
            Marker(
              markerId: const MarkerId('festa'),
              position: pos,
              draggable: true,
              onDragEnd: _onPinDragged,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueRose),
            ),
          },
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
          style: _mapStyle,
        ),

        if (!_mapaConfirmado)
          Positioned(top: 10, left: 0, right: 0,
            child: Center(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.65),
                border: Border.all(color: TabuColors.borderMid, width: 0.6),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.open_with_rounded, color: TabuColors.subtle, size: 11),
                SizedBox(width: 5),
                Text('Arraste o pin para ajustar',
                  style: TextStyle(fontFamily: TabuTypography.bodyFont,
                      fontSize: 10, letterSpacing: 1,
                      color: TabuColors.subtle)),
              ])))),

        Positioned(bottom: 10, right: 10,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _mapaConfirmado = true);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _mapaConfirmado
                    ? TabuColors.rosaPrincipal
                    : Colors.black.withOpacity(0.75),
                border: Border.all(
                  color: _mapaConfirmado
                      ? TabuColors.rosaPrincipal
                      : TabuColors.borderMid,
                  width: 0.8,
                )),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  _mapaConfirmado
                      ? Icons.check_circle_rounded
                      : Icons.check_rounded,
                  color: Colors.white, size: 12),
                const SizedBox(width: 6),
                Text(_mapaConfirmado ? 'CONFIRMADO' : 'CONFIRMAR',
                  style: const TextStyle(fontFamily: TabuTypography.bodyFont,
                      fontSize: 9, fontWeight: FontWeight.w700,
                      letterSpacing: 2, color: Colors.white)),
              ]),
            ),
          )),

        Positioned(bottom: 10, left: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            color: Colors.black.withOpacity(0.6),
            child: Text(
              '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}',
              style: const TextStyle(fontFamily: TabuTypography.bodyFont,
                  fontSize: 8, letterSpacing: 0.3,
                  color: TabuColors.subtle)))),
      ]),
    );
  }

  // ── Text field ─────────────────────────────────────────────────────────────
  Widget _buildField({
    required TextEditingController ctrl,
    required FocusNode focus,
    required String hint,
    FocusNode? nextFocus,
    int maxLines = 1,
    int? maxLength,
    TextCapitalization capitalize = TextCapitalization.none,
    TextInputAction action = TextInputAction.next,
  }) {
    return TextFormField(
      controller: ctrl, focusNode: focus,
      maxLines: maxLines, maxLength: maxLength,
      textCapitalization: capitalize, textInputAction: action,
      onEditingComplete: nextFocus != null
          ? () => FocusScope.of(context).requestFocus(nextFocus)
          : () => FocusScope.of(context).unfocus(),
      style: const TextStyle(fontFamily: TabuTypography.bodyFont,
          fontSize: 15, fontWeight: FontWeight.w400,
          letterSpacing: 0.3, color: TabuColors.branco),
      cursorColor: TabuColors.rosaPrincipal, cursorWidth: 1,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontFamily: TabuTypography.bodyFont,
            fontSize: 13, color: TabuColors.subtle),
        filled: true, fillColor: const Color(0xFF0D0115),
        counterStyle: const TextStyle(fontFamily: TabuTypography.bodyFont,
            fontSize: 9, color: TabuColors.subtle),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: const OutlineInputBorder(borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: TabuColors.border, width: 0.8)),
        enabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: TabuColors.border, width: 0.8)),
        focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: TabuColors.rosaPrincipal, width: 1.5)),
      ),
    );
  }

  // ── Date tile ──────────────────────────────────────────────────────────────
  Widget _buildDateTile({
    required String label,
    required DateTime value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0115),
          border: Border.all(
              color: TabuColors.rosaPrincipal.withOpacity(0.5), width: 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
            style: const TextStyle(fontFamily: TabuTypography.bodyFont,
                fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 2,
                color: TabuColors.rosaPrincipal)),
          const SizedBox(height: 6),
          Text(_formatDate(value),
            style: const TextStyle(fontFamily: TabuTypography.bodyFont,
                fontSize: 13, fontWeight: FontWeight.w600,
                color: TabuColors.branco, letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(_formatTime(value),
            style: TextStyle(fontFamily: TabuTypography.bodyFont,
                fontSize: 11,
                color: TabuColors.rosaPrincipal.withOpacity(0.7))),
        ]),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const meses = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
                   'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    return '${dt.day.toString().padLeft(2, '0')} ${meses[dt.month - 1]}';
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// ── Background painter ─────────────────────────────────────────────────────────
class _EditFestaBg extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = TabuColors.bg);
    canvas.drawCircle(
      Offset(size.width * 0.15, size.height * 0.08), size.width * 0.65,
      Paint()
        ..shader = RadialGradient(colors: [
          TabuColors.rosaPrincipal.withOpacity(0.06),
          Colors.transparent,
        ]).createShader(Rect.fromCircle(
            center: Offset(size.width * 0.15, size.height * 0.08),
            radius: size.width * 0.65)),
    );
  }

  @override
  bool shouldRepaint(_EditFestaBg _) => false;
}

// ── Map style (dark theme) ─────────────────────────────────────────────────────
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

// ── Shared picker tile ─────────────────────────────────────────────────────────
class _PickerTile extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final VoidCallback onTap;
  final Color        color;

  const _PickerTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = TabuColors.branco,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 16),
        Text(label,
          style: TextStyle(fontFamily: TabuTypography.bodyFont,
              fontSize: 14, fontWeight: FontWeight.w600,
              letterSpacing: 2.5, color: color)),
      ]),
    ),
  );
}