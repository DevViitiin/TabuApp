import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/services/services_app/invite_request_service.dart';

// ─── Request Invite Screen ───────────────────────────────────────────────────
class RequestInviteScreen extends StatefulWidget {
  const RequestInviteScreen({super.key});
  @override
  State<RequestInviteScreen> createState() => _RequestInviteScreenState();
}

class _RequestInviteScreenState extends State<RequestInviteScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgController;
  late AnimationController _entryController;
  late AnimationController _pulseController;
  late AnimationController _successController;
  late AnimationController _errorShakeController;

  late Animation<double> _fade;
  late Animation<Offset> _slide;
  late Animation<double> _pulse;
  late Animation<double> _successScale;
  late Animation<double> _successFade;
  late Animation<double> _shakeAnim;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();

  bool _nameFocused = false;
  bool _emailFocused = false;
  bool _phoneFocused = false;

  bool _isLoading = false;
  bool _hasError = false;
  bool _isSuccess = false;
  String _errorMsg = '';

  final _inviteService = InviteRequestService();

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _errorShakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
    );

    _slide = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
    ));

    _pulse = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _successScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _successController, curve: Curves.elasticOut),
    );

    _successFade = CurvedAnimation(
      parent: _successController,
      curve: Curves.easeOut,
    );

    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _errorShakeController, curve: Curves.elasticOut),
    );

    _nameFocus.addListener(() {
      if (mounted) setState(() => _nameFocused = _nameFocus.hasFocus);
    });
    _emailFocus.addListener(() {
      if (mounted) setState(() => _emailFocused = _emailFocus.hasFocus);
    });
    _phoneFocus.addListener(() {
      if (mounted) setState(() => _phoneFocused = _phoneFocus.hasFocus);
    });
  }

  @override
  void dispose() {
    _bgController.dispose();
    _entryController.dispose();
    _pulseController.dispose();
    _successController.dispose();
    _errorShakeController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMsg = '';
    });

    try {
      await _inviteService.createInviteRequest(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isSuccess = true;
      });
      _successController.forward();
      HapticFeedback.heavyImpact();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMsg = e.toString();
      });
      HapticFeedback.vibrate();
      _errorShakeController.forward(from: 0);

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        setState(() => _hasError = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: TabuColors.bg,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            // Fundo escuro animado
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _bgController,
                builder: (_, __) => CustomPaint(
                  painter: _FundoEscuroPainter(progress: _bgController.value),
                ),
              ),
            ),
            // Linha neon rosa no topo
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 3,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.transparent,
                    TabuColors.rosaPrincipal,
                    TabuColors.rosaClaro,
                    TabuColors.rosaPrincipal,
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
            SafeArea(
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: _isSuccess
                      ? _buildSuccessState(theme)
                      : _buildRequestForm(theme),
                ),
              ),
            ),
            // Loading overlay
            if (_isLoading)
              Positioned.fill(
                child: Container(
                  color: TabuColors.bg.withOpacity(0.7),
                  child: Center(
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: TabuColors.bgCard,
                        border: Border.all(color: TabuColors.border, width: 0.8),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(15),
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: TabuColors.rosaPrincipal,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestForm(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.only(
            left: 28,
            right: 28,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: h),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: TabuColors.subtle, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      Text(
                        'SOLICITAÇÃO DE CONVITE',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 11,
                          letterSpacing: 4,
                          color: TabuColors.subtle,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48),
                    ],
                  ),

                  const Spacer(flex: 1),

                  // Ícone envelope animado
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) => Transform.scale(
                      scale: _pulse.value,
                      child: SizedBox(
                        width: 64,
                        height: 64,
                        child: CustomPaint(painter: _EnvelopeRosaIcon()),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    'SOLICITAR ACESSO',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontSize: 20,
                      letterSpacing: 4,
                      color: TabuColors.branco,
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    'Preencha o formulário para\nreceber seu código de acesso.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: TabuColors.subtle,
                      fontSize: 12,
                      height: 1.7,
                      letterSpacing: 0.4,
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Formulário com shake
                  AnimatedBuilder(
                    animation: _shakeAnim,
                    builder: (_, child) {
                      final offset = _hasError
                          ? math.sin(_shakeAnim.value * math.pi * 5) * 8.0
                          : 0.0;
                      return Transform.translate(
                          offset: Offset(offset, 0), child: child);
                    },
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildTextField(
                            controller: _nameController,
                            focusNode: _nameFocus,
                            isFocused: _nameFocused,
                            label: 'NOME COMPLETO',
                            hint: 'Digite seu nome',
                            icon: Icons.person_outline,
                            keyboardType: TextInputType.name,
                            textCapitalization: TextCapitalization.words,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Nome é obrigatório';
                              }
                              if (value.trim().split(' ').length < 2) {
                                return 'Digite nome e sobrenome';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _emailFocus.requestFocus(),
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _emailController,
                            focusNode: _emailFocus,
                            isFocused: _emailFocused,
                            label: 'E-MAIL',
                            hint: 'Digite seu e-mail',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'E-mail é obrigatório';
                              }
                              final emailRegex = RegExp(
                                r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                              );
                              if (!emailRegex.hasMatch(value.trim())) {
                                return 'E-mail inválido';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _phoneFocus.requestFocus(),
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _phoneController,
                            focusNode: _phoneFocus,
                            isFocused: _phoneFocused,
                            label: 'TELEFONE',
                            hint: '(00) 00000-0000',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [_PhoneMaskFormatter()],
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Telefone é obrigatório';
                              }
                              final cleanPhone = value.replaceAll(RegExp(r'\D'), '');
                              if (cleanPhone.length < 10) {
                                return 'Telefone inválido';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _submitRequest(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Mensagem de erro
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _hasError
                        ? Padding(
                            key: const ValueKey('error'),
                            padding: const EdgeInsets.only(top: 14),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: const BoxDecoration(
                                    color: TabuColors.rosaPrincipal,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _errorMsg,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: TabuColors.rosaPrincipal,
                                      fontSize: 11,
                                      letterSpacing: 1,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: const BoxDecoration(
                                    color: TabuColors.rosaPrincipal,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox(key: ValueKey('no-error'), height: 14),
                  ),

                  const Spacer(flex: 1),

                  _ActionButton(
                    label: 'SOLICITAR CONVITE',
                    enabled: !_isLoading,
                    onTap: _submitRequest,
                  ),

                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(width: 1, height: 12, color: TabuColors.border),
                      const SizedBox(width: 10),
                      Text(
                        'Enviaremos o código por e-mail e WhatsApp',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: TabuColors.subtle,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(width: 1, height: 12, color: TabuColors.border),
                    ],
                  ),

                  const Spacer(flex: 1),

                  Column(
                    children: [
                      Container(width: 24, height: 0.5, color: TabuColors.subtle),
                      const SizedBox(height: 8),
                      Text(
                        'TABU BAR & LOUNGE',
                        style: theme.textTheme.labelSmall?.copyWith(
                          letterSpacing: 5,
                          color: TabuColors.subtle,
                          fontSize: 7,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool isFocused,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    void Function(String)? onFieldSubmitted,
  }) {
    final hasValue = controller.text.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 2,
            color: isFocused ? TabuColors.rosaPrincipal : TabuColors.subtle,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _hasError
                ? TabuColors.rosaPrincipal.withOpacity(0.15)
                : hasValue
                    ? const Color(0x22E85D8A)
                    : isFocused
                        ? const Color(0x14E85D8A)
                        : TabuColors.bgCard,
            border: Border.all(
              color: _hasError
                  ? TabuColors.rosaPrincipal.withOpacity(0.8)
                  : isFocused
                      ? TabuColors.rosaPrincipal
                      : hasValue
                          ? TabuColors.borderMid
                          : TabuColors.border,
              width: isFocused ? 1.5 : _hasError ? 1.2 : 0.8,
            ),
            boxShadow: isFocused
                ? [
                    BoxShadow(
                        color: TabuColors.glow.withOpacity(0.3), blurRadius: 16)
                  ]
                : hasValue && !_hasError
                    ? [
                        BoxShadow(
                            color: TabuColors.glow.withOpacity(0.15),
                            blurRadius: 8)
                      ]
                    : [],
          ),
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            inputFormatters: inputFormatters,
            validator: validator,
            onFieldSubmitted: onFieldSubmitted,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
              color: _hasError
                  ? TabuColors.rosaPrincipal
                  : hasValue
                      ? TabuColors.branco
                      : TabuColors.subtle,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: 14,
                color: TabuColors.subtle.withOpacity(0.6),
                letterSpacing: 0.3,
              ),
              prefixIcon: Icon(
                icon,
                color: isFocused
                    ? TabuColors.rosaPrincipal
                    : hasValue
                        ? TabuColors.subtle
                        : TabuColors.subtle.withOpacity(0.5),
                size: 20,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorStyle: const TextStyle(height: 0, fontSize: 0),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 16,
              ),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessState(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),
          FadeTransition(
            opacity: _successFade,
            child: ScaleTransition(
              scale: _successScale,
              child: SizedBox(
                width: 96,
                height: 96,
                child: CustomPaint(painter: _SuccessRosaIcon()),
              ),
            ),
          ),
          const SizedBox(height: 32),
          FadeTransition(
            opacity: _successFade,
            child: Text(
              'SOLICITAÇÃO ENVIADA',
              style: theme.textTheme.headlineLarge?.copyWith(
                fontSize: 19,
                letterSpacing: 6,
                color: TabuColors.branco,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FadeTransition(
            opacity: _successFade,
            child: Text(
              'Seu convite será enviado em breve.\nVerifique seu e-mail e WhatsApp.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: TabuColors.subtle,
                fontSize: 12,
                height: 1.8,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const Spacer(flex: 2),
          FadeTransition(
            opacity: _successFade,
            child: _ActionButton(
              label: 'VOLTAR',
              enabled: true,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          const Spacer(flex: 1),
          FadeTransition(
            opacity: _successFade,
            child: Text(
              'TABU BAR & LOUNGE',
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 5,
                color: TabuColors.subtle,
                fontSize: 7,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── Phone Mask Formatter ─────────────────────────────────────────────────────
class _PhoneMaskFormatter extends TextInputFormatter {
  static final _digitOnly = RegExp(r'\d+');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Se não mudou, retorna diretamente
    if (newValue.text == oldValue.text) return newValue;

    // Extrai apenas dígitos
    final digits = _getOnlyDigits(newValue.text);

    // Limita a 11 dígitos (DDD + 9 dígitos)
    final limited = digits.length > 11 ? digits.substring(0, 11) : digits;

    final formatted = _applyMask(limited);

    // Calcula nova posição do cursor de forma robusta:
    // Conta quantos dígitos existem antes da posição do cursor no novo texto
    int digitCursorPosition = 0;
    for (int i = 0; i < newValue.selection.end && i < newValue.text.length; i++) {
      if (RegExp(r'\d').hasMatch(newValue.text[i])) digitCursorPosition++;
    }
    // A partir do número de dígitos antes do cursor, calcula a posição correspondente no texto formatado
    final newCursor = _cursorPositionFromDigitIndex(digitCursorPosition, formatted);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newCursor),
    );
  }

  String _getOnlyDigits(String input) {
    final sb = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final ch = input[i];
      if (ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57) {
        sb.write(ch);
      }
    }
    return sb.toString();
  }

  String _applyMask(String digits) {
    // Máscara: (00) 00000-0000
    final buf = StringBuffer();
    final len = digits.length;

    if (len == 0) return '';

    if (len >= 1) {
      buf.write('(');
      if (len >= 2) {
        buf.write(digits.substring(0, 2));
      } else {
        buf.write(digits.substring(0, 1));
      }
    }

    if (len >= 3) {
      buf.write(') ');
      if (len >= 7) {
        buf.write(digits.substring(2, 7));
      } else {
        buf.write(digits.substring(2));
      }
    }

    if (len >= 8) {
      buf.write('-');
      buf.write(digits.substring(7));
    }

    return buf.toString();
  }

  int _cursorPositionFromDigitIndex(int digitIndex, String formatted) {
    // Percorre o formatted e conta dígitos até alcançar digitIndex, então retorna a posição +1
    int digitsSeen = 0;
    for (int i = 0; i < formatted.length; i++) {
      if (RegExp(r'\d').hasMatch(formatted[i])) {
        digitsSeen++;
        if (digitsSeen >= digitIndex) {
          // cursor pos deve ficar logo após este dígito
          return i + 1;
        }
      }
    }
    // Se digitIndex é 0 retorna 0, ou se ultrapassou, retorna o fim
    return formatted.length;
  }
}

// ─── Botão de ação ────────────────────────────────────────────────────────────
class _ActionButton extends StatefulWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  const _ActionButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });
  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap();
            }
          : null,
      onTapCancel: widget.enabled ? () => setState(() => _pressed = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: double.infinity,
        height: 54,
        transform: Matrix4.identity()..scale(_pressed ? 0.975 : 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: widget.enabled
              ? LinearGradient(
                  colors: _pressed
                      ? [TabuColors.rosaDeep, TabuColors.rosaPrincipal]
                      : [TabuColors.rosaPrincipal, TabuColors.rosaClaro],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: widget.enabled ? null : TabuColors.bgCard,
          border: Border.all(
            color: widget.enabled ? Colors.transparent : TabuColors.border,
            width: 0.8,
          ),
          boxShadow: widget.enabled && !_pressed
              ? [
                  BoxShadow(
                      color: TabuColors.glow,
                      blurRadius: 24,
                      offset: const Offset(0, 6)),
                  BoxShadow(
                      color: TabuColors.rosaPrincipal.withOpacity(0.25),
                      blurRadius: 32,
                      offset: const Offset(0, 12)),
                ]
              : [],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.enabled)
              AnimatedBuilder(
                animation: _shimmer,
                builder: (_, __) => CustomPaint(
                  painter: _ShimmerPainter(
                    progress: _shimmer.value,
                    color: Colors.white.withOpacity(0.2),
                  ),
                  size: const Size(double.infinity, 54),
                ),
              ),
            Text(
              widget.label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontSize: 12,
                letterSpacing: 5,
                fontWeight: FontWeight.w700,
                color: widget.enabled ? TabuColors.branco : TabuColors.subtle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Ícone: Envelope Rosa ──────────────────────────────────────────────────────
class _EnvelopeRosaIcon extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Halo de fundo
    canvas.drawCircle(
        Offset(cx, cy),
        cx,
        Paint()
          ..color = TabuColors.rosaPrincipal.withOpacity(0.12)
          ..style = PaintingStyle.fill);
    canvas.drawCircle(
        Offset(cx, cy),
        cx,
        Paint()
          ..color = TabuColors.rosaPrincipal.withOpacity(0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

    final bodyPaint = Paint()
      ..color = TabuColors.rosaPrincipal
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Corpo do envelope
    final envelopeRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy + 2), width: 28, height: 20),
      const Radius.circular(2),
    );
    canvas.drawRRect(envelopeRect, bodyPaint);

    // Tampa do envelope
    final topPath = Path()
      ..moveTo(cx - 14, cy - 8)
      ..lineTo(cx, cy + 2)
      ..lineTo(cx + 14, cy - 8);
    canvas.drawPath(topPath, bodyPaint);

    // Glow
    canvas.drawRRect(
        envelopeRect,
        Paint()
          ..color = TabuColors.glow
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
  }

  @override
  bool shouldRepaint(_EnvelopeRosaIcon old) => false;
}

// ─── Ícone: Check Sucesso Rosa ────────────────────────────────────────────────
class _SuccessRosaIcon extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Círculo de fundo
    canvas.drawCircle(
        Offset(cx, cy),
        cx,
        Paint()
          ..color = TabuColors.rosaPrincipal.withOpacity(0.15)
          ..style = PaintingStyle.fill);
    // Borda com glow
    canvas.drawCircle(
        Offset(cx, cy),
        cx,
        Paint()
          ..color = TabuColors.rosaPrincipal
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    // Borda fina branca
    canvas.drawCircle(
        Offset(cx, cy),
        cx,
        Paint()
          ..color = TabuColors.branco.withOpacity(0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0);

    final check = Path()
      ..moveTo(cx - 18, cy)
      ..lineTo(cx - 5, cy + 13)
      ..lineTo(cx + 18, cy - 15);

    // Glow do check
    canvas.drawPath(
        check,
        Paint()
          ..color = TabuColors.glow
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    // Check branco
    canvas.drawPath(
        check,
        Paint()
          ..color = TabuColors.branco
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(_SuccessRosaIcon old) => false;
}

// ─── Shimmer ──────────────────────────────────────────────────────────────────
class _ShimmerPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _ShimmerPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width * (progress * 1.6 - 0.3);
    canvas.drawRect(
      Rect.fromLTWH(x - 60, 0, 120, size.height),
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            color,
            color.withOpacity(0.5),
            color,
            Colors.transparent
          ],
          stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
          transform: GradientRotation(math.pi / 8),
        ).createShader(Rect.fromLTWH(x - 60, 0, 120, size.height)),
    );
  }

  @override
  bool shouldRepaint(_ShimmerPainter old) => old.progress != progress;
}

// ─── Fundo Escuro Animado ─────────────────────────────────────────────────────
class _FundoEscuroPainter extends CustomPainter {
  final double progress;
  const _FundoEscuroPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // Base escura
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = TabuColors.bg);

    // Halo rosa superior animado
    final neonRadius = size.width * (0.85 + progress * 0.18);
    canvas.drawCircle(
      Offset(size.width * 0.55, -size.height * 0.06),
      neonRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            TabuColors.rosaPrincipal.withOpacity(0.18 - progress * 0.05),
            TabuColors.rosaDeep.withOpacity(0.06),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(
          center: Offset(size.width * 0.55, -size.height * 0.06),
          radius: neonRadius,
        )),
    );

    // Halo bgAlt inferior
    final sombraRadius = size.width * (0.5 + (1 - progress) * 0.12);
    canvas.drawCircle(
      Offset(size.width * 1.1, size.height * 0.85),
      sombraRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [TabuColors.bgAlt.withOpacity(0.9), Colors.transparent],
        ).createShader(Rect.fromCircle(
          center: Offset(size.width * 1.1, size.height * 0.85),
          radius: sombraRadius,
        )),
    );

    // Brilho central suave
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.0, -0.2),
          radius: 0.65,
          colors: [
            TabuColors.rosaDeep.withOpacity(0.10 + progress * 0.04),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
  }

  @override
  bool shouldRepaint(_FundoEscuroPainter old) => old.progress != progress;
}