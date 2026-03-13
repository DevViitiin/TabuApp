// lib/screens/screens_home/perfil_screen/edit_perfil_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/services/services_app/edit_perfil_service.dart';

class EditPerfilScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final void Function(Map<String, dynamic> updatedData)? onSaved;

  const EditPerfilScreen({
    super.key,
    required this.userData,
    this.onSaved,
  });

  @override
  State<EditPerfilScreen> createState() => _EditPerfilScreenState();
}

class _EditPerfilScreenState extends State<EditPerfilScreen> {
  final _service   = EditPerfilService();
  final _formKey   = GlobalKey<FormState>();
  final _nameFocus = FocusNode();
  final _bioFocus  = FocusNode();

  late TextEditingController _nameCtrl;
  late TextEditingController _bioCtrl;

  File?   _imageFile;
  String  _currentAvatar = '';
  bool    _uploading  = false;
  bool    _saving     = false;
  double  _uploadProgress = 0;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text: widget.userData['name'] as String? ?? '',
    );
    // 'bio' = valor editado, 'bio ' = valor original do cadastro
    _bioCtrl = TextEditingController(
      text: ((widget.userData['bio']  as String?)
          ?? (widget.userData['bio '] as String?)
          ?? '').trim(),
    );
    _currentAvatar = widget.userData['avatar'] as String? ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _nameFocus.dispose();
    _bioFocus.dispose();
    super.dispose();
  }

  // ── Seleciona imagem ────────────────────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context);
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _imageFile = File(picked.path));
  }

  // ── Salva via serviço ───────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() { _saving = true; _uploading = _imageFile != null; });

    try {
      final updated = await _service.updateProfile(
        name:             _nameCtrl.text,
        bio:              _bioCtrl.text,
        currentAvatarUrl: _currentAvatar,
        newImageFile:     _imageFile,
        onUploadProgress: (p) {
          if (mounted) setState(() => _uploadProgress = p);
        },
      );

      if (mounted) {
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor:
            success ? TabuColors.rosaDeep : const Color(0xFF3D0A0A),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(),
        content: Text(
          msg,
          style: const TextStyle(
            fontFamily: TabuTypography.bodyFont,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.5,
            color: TabuColors.branco,
          ),
        ),
      ),
    );
  }

  // ── Bottom sheet fonte da foto ──────────────────────────────────────────────
  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: TabuColors.bgAlt,
      shape: const RoundedRectangleBorder(),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 3,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(
                color: TabuColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'TROCAR FOTO',
              style: TextStyle(
                fontFamily: TabuTypography.displayFont,
                fontSize: 18,
                letterSpacing: 5,
                color: TabuColors.branco,
              ),
            ),
            const SizedBox(height: 16),
            Container(height: 0.5, color: TabuColors.border),
            _SheetOption(
              icon: Icons.photo_camera_outlined,
              label: 'CÂMERA',
              onTap: () => _pickImage(ImageSource.camera),
            ),
            Container(height: 0.5, color: TabuColors.border),
            _SheetOption(
              icon: Icons.photo_library_outlined,
              label: 'GALERIA',
              onTap: () => _pickImage(ImageSource.gallery),
            ),
            if (_currentAvatar.isNotEmpty || _imageFile != null) ...[
              Container(height: 0.5, color: TabuColors.border),
              _SheetOption(
                icon: Icons.delete_outline,
                label: 'REMOVER FOTO',
                color: const Color(0xFFE85D5D),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _imageFile = null;
                    _currentAvatar = '';
                  });
                },
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final busy = _saving || _uploading;

    return Scaffold(
      backgroundColor: TabuColors.bg,
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _EditBg())),

          // Linha neon
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: 3,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [
                  TabuColors.rosaDeep,
                  TabuColors.rosaPrincipal,
                  TabuColors.rosaClaro,
                  TabuColors.rosaPrincipal,
                  TabuColors.rosaDeep,
                ]),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── App bar ────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new,
                            color: TabuColors.dim, size: 18),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          'EDITAR PERFIL',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: TabuTypography.displayFont,
                            fontSize: 20,
                            letterSpacing: 5,
                            color: TabuColors.branco,
                          ),
                        ),
                      ),
                      // Salvar rápido no header
                      GestureDetector(
                        onTap: busy ? null : _save,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: busy
                                ? TabuColors.bgCard
                                : TabuColors.rosaPrincipal,
                            border: Border.all(
                                color: TabuColors.rosaPrincipal, width: 0.8),
                          ),
                          child: Text(
                            busy ? '...' : 'SALVAR',
                            style: TextStyle(
                              fontFamily: TabuTypography.bodyFont,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.5,
                              color: busy
                                  ? TabuColors.subtle
                                  : TabuColors.branco,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Container(height: 0.5, color: TabuColors.border),

                // ── Form ───────────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 36),

                          // Avatar
                          _AvatarPicker(
                            imageFile: _imageFile,
                            avatarUrl: _currentAvatar,
                            uploading: _uploading,
                            uploadProgress: _uploadProgress,
                            onTap: _showImagePicker,
                          ),

                          const SizedBox(height: 36),

                          // Nome
                          _SectionLabel(label: 'DADOS PESSOAIS'),
                          const SizedBox(height: 14),

                          _TabuField(
                            controller: _nameCtrl,
                            focusNode: _nameFocus,
                            label: 'NOME',
                            icon: Icons.person_outline,
                            hint: 'Seu nome',
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Nome é obrigatório'
                                : null,
                            onEditingComplete: () => FocusScope.of(context)
                                .requestFocus(_bioFocus),
                          ),

                          const SizedBox(height: 14),

                          _TabuField(
                            controller: _bioCtrl,
                            focusNode: _bioFocus,
                            label: 'BIO',
                            icon: Icons.edit_note_outlined,
                            hint: 'Conte um pouco sobre você...',
                            maxLines: 3,
                            maxLength: 120,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                          ),

                          const SizedBox(height: 28),

                          // Conta (read-only)
                          _SectionLabel(label: 'CONTA'),
                          const SizedBox(height: 14),

                          _ReadOnlyField(
                            label: 'E-MAIL',
                            value: widget.userData['email'] as String? ?? '',
                            icon: Icons.mail_outline,
                          ),

                          const SizedBox(height: 8),
                          _InfoBox(
                            text: 'O e-mail não pode ser alterado por aqui.',
                          ),

                          const SizedBox(height: 40),

                          // Botão salvar principal
                          _SaveButton(
                            saving: _saving,
                            uploading: _uploading,
                            progress: _uploadProgress,
                            onTap: _save,
                          ),

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════
//  AVATAR PICKER
// ════════════════════════════════════════════
class _AvatarPicker extends StatelessWidget {
  final File? imageFile;
  final String avatarUrl;
  final bool uploading;
  final double uploadProgress;
  final VoidCallback onTap;

  const _AvatarPicker({
    required this.imageFile,
    required this.avatarUrl,
    required this.uploading,
    required this.uploadProgress,
    required this.onTap,
  });

  Widget _placeholder() => Container(
        color: TabuColors.bgAlt,
        child: const Icon(Icons.person_outline,
            color: TabuColors.rosaPrincipal, size: 40),
      );

  @override
  Widget build(BuildContext context) {
    final hasImage = imageFile != null || avatarUrl.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Glow ring
              Container(
                width: 108, height: 108,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: TabuColors.glow,
                        blurRadius: 24,
                        spreadRadius: 2)
                  ],
                  gradient: const LinearGradient(
                    colors: [TabuColors.rosaDeep, TabuColors.rosaPrincipal],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),

              // Foto
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: TabuColors.bg, width: 3),
                ),
                child: ClipOval(
                  child: imageFile != null
                      ? Image.file(imageFile!, fit: BoxFit.cover)
                      : avatarUrl.isNotEmpty
                          ? Image.network(
                              avatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _placeholder(),
                            )
                          : _placeholder(),
                ),
              ),

              // Overlay câmera
              if (hasImage)
                Positioned.fill(
                  child: ClipOval(
                    child: Container(
                      color: Colors.black.withOpacity(0.38),
                      child: const Center(
                        child: Icon(Icons.photo_camera,
                            color: TabuColors.branco, size: 26),
                      ),
                    ),
                  ),
                ),

              // Progress ring
              if (uploading)
                SizedBox(
                  width: 108, height: 108,
                  child: CircularProgressIndicator(
                    value: uploadProgress,
                    strokeWidth: 3,
                    color: TabuColors.rosaPrincipal,
                    backgroundColor: TabuColors.border,
                  ),
                ),

              // Badge editar
              if (!uploading)
                Positioned(
                  bottom: 2, right: 2,
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: TabuColors.rosaPrincipal,
                      shape: BoxShape.circle,
                      border: Border.all(color: TabuColors.bg, width: 2),
                    ),
                    child: const Icon(Icons.edit,
                        color: TabuColors.branco, size: 13),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            uploading
                ? 'ENVIANDO ${(uploadProgress * 100).toInt()}%'
                : 'TOQUE PARA ALTERAR',
            style: TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
              color: uploading
                  ? TabuColors.rosaPrincipal
                  : TabuColors.subtle,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════
//  SAVE BUTTON
// ════════════════════════════════════════════
class _SaveButton extends StatelessWidget {
  final bool saving;
  final bool uploading;
  final double progress;
  final VoidCallback onTap;

  const _SaveButton({
    required this.saving,
    required this.uploading,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final busy  = saving || uploading;
    final label = uploading
        ? 'ENVIANDO FOTO ${(progress * 100).toInt()}%'
        : saving
            ? 'SALVANDO...'
            : 'SALVAR ALTERAÇÕES';

    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        width: double.infinity, height: 52,
        decoration: BoxDecoration(
          color: busy ? TabuColors.bgCard : TabuColors.rosaPrincipal,
          border: Border.all(
            color: busy ? TabuColors.border : TabuColors.rosaPrincipal,
            width: 0.8,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (uploading)
              Positioned.fill(
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Container(
                    color: TabuColors.rosaPrincipal.withOpacity(0.25),
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                        color: TabuColors.rosaPrincipal, strokeWidth: 1.5),
                  )
                else
                  const Icon(Icons.check, color: TabuColors.branco, size: 16),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                    color: busy ? TabuColors.subtle : TabuColors.branco,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════
//  SECTION LABEL
// ════════════════════════════════════════════
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 5, height: 5,
          decoration: const BoxDecoration(
              color: TabuColors.rosaPrincipal, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
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
    );
  }
}

// ════════════════════════════════════════════
//  TABU TEXT FIELD
// ════════════════════════════════════════════
class _TabuField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;
  final int? maxLength;
  final TextCapitalization textCapitalization;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;
  final VoidCallback? onEditingComplete;

  const _TabuField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.onEditingComplete,
  });

  @override
  State<_TabuField> createState() => _TabuFieldState();
}

class _TabuFieldState extends State<_TabuField> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(
        () { if (mounted) setState(() => _focused = widget.focusNode.hasFocus); });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(widget.icon,
                color: _focused ? TabuColors.rosaPrincipal : TabuColors.subtle,
                size: 14),
            const SizedBox(width: 6),
            Text(
              widget.label,
              style: TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.5,
                color: _focused ? TabuColors.rosaPrincipal : TabuColors.subtle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          maxLines: widget.maxLines,
          maxLength: widget.maxLength,
          textCapitalization: widget.textCapitalization,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          validator: widget.validator,
          onEditingComplete: widget.onEditingComplete,
          style: const TextStyle(
            fontFamily: TabuTypography.bodyFont,
            fontSize: 15,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
            color: TabuColors.branco,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 13,
              color: TabuColors.subtle,
            ),
            counterStyle: const TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 9,
              color: TabuColors.subtle,
            ),
            filled: true,
            fillColor: TabuColors.bgCard,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: TabuColors.border, width: 0.8),
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: TabuColors.border, width: 0.8),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide:
                  BorderSide(color: TabuColors.rosaPrincipal, width: 1.5),
            ),
            errorBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: Color(0xFFE85D5D), width: 1),
            ),
            focusedErrorBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: Color(0xFFE85D5D), width: 1.5),
            ),
            errorStyle: const TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 10,
              letterSpacing: 1,
              color: Color(0xFFE85D5D),
            ),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════
//  READ ONLY FIELD
// ════════════════════════════════════════════
class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _ReadOnlyField(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: TabuColors.subtle, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.5,
                color: TabuColors.subtle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: TabuColors.bgCard,
            border: Border.all(color: TabuColors.border, width: 0.8),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: TabuColors.subtle,
            ),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════
//  INFO BOX
// ════════════════════════════════════════════
class _InfoBox extends StatelessWidget {
  final String text;
  const _InfoBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: TabuColors.rosaPrincipal.withOpacity(0.06),
        border: Border.all(color: TabuColors.border, width: 0.8),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: TabuColors.subtle, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 11,
                letterSpacing: 0.5,
                color: TabuColors.subtle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════
//  SHEET OPTION
// ════════════════════════════════════════════
class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _SheetOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = TabuColors.branco,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.5,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════
//  BACKGROUND
// ════════════════════════════════════════════
class _EditBg extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = TabuColors.bg);
    canvas.drawCircle(
      Offset(size.width * 0.9, size.height * 0.08),
      size.width * 0.6,
      Paint()
        ..shader = RadialGradient(
          colors: [
            TabuColors.rosaPrincipal.withOpacity(0.07),
            Colors.transparent
          ],
        ).createShader(Rect.fromCircle(
          center: Offset(size.width * 0.9, size.height * 0.08),
          radius: size.width * 0.6,
        )),
    );
  }

  @override
  bool shouldRepaint(_EditBg old) => false;
}
