import 'dart:math' as math;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/screens/screens_auth/login_screen/login_screen.dart';

// ─── Access Code Screen ───────────────────────────────────────────────────────
class AccessCodeScreen extends StatefulWidget {
  const AccessCodeScreen({super.key});
  @override
  State<AccessCodeScreen> createState() => _AccessCodeScreenState();
}

class _AccessCodeScreenState extends State<AccessCodeScreen>
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

  static const int _codeLength = 6;
  final List<TextEditingController> _controllers =
      List.generate(_codeLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_codeLength, (_) => FocusNode());
  final List<bool> _focused = List.filled(_codeLength, false);

  bool _isLoading = false;
  bool _hasError  = false;
  bool _isSuccess = false;
  String _errorMsg = '';

  String get _fullCode => _controllers.map((c) => c.text).join();

  bool get _codeComplete =>
      _fullCode.length == _codeLength &&
      _controllers.every((c) => c.text.isNotEmpty);

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

    for (int i = 0; i < _codeLength; i++) {
      _focusNodes[i].addListener(() {
        if (mounted) setState(() => _focused[i] = _focusNodes[i].hasFocus);
      });
    }
  }

  @override
  void dispose() {
    _bgController.dispose();
    _entryController.dispose();
    _pulseController.dispose();
    _successController.dispose();
    _errorShakeController.dispose();
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  Future<void> _validateCode() async {
    if (!_codeComplete || _isLoading) return;
    setState(() {
      _isLoading = true;
      _hasError  = false;
      _errorMsg  = '';
    });

    try {
      // Busca o código diretamente do banco
      final snapshot = await FirebaseDatabase.instance
          .ref('Invitation_code')
          .get();

      if (!mounted) return;

      final validCode = snapshot.value?.toString().toUpperCase() ?? '';
      final inputCode = _fullCode.toUpperCase();

      if (inputCode == validCode) {
        setState(() { _isLoading = false; _isSuccess = true; });
        _successController.forward();
        HapticFeedback.heavyImpact();
      } else {
        setState(() {
          _isLoading = false;
          _hasError  = true;
          _errorMsg  = 'Código inválido ou expirado';
        });
        HapticFeedback.vibrate();
        _errorShakeController.forward(from: 0);
        Future.delayed(const Duration(milliseconds: 900), () {
          if (!mounted) return;
          for (final c in _controllers) c.clear();
          _focusNodes[0].requestFocus();
          setState(() => _hasError = false);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError  = true;
        _errorMsg  = 'Erro ao verificar código';
      });
    }
  }

  void _onDigitChanged(int index, String value) {
    if (mounted) setState(() => _hasError = false);
    if (value.isNotEmpty) {
      if (index < _codeLength - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _validateCode();
      }
    }
  }

  void _onKeyDown(int index, RawKeyEvent event) {
    if (event is RawKeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      resizeToAvoidBottomInset: false,
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
              top: 0, left: 0, right: 0,
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
                      : _buildCodeEntry(theme),
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
                      width: 52, height: 52,
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

  Widget _buildCodeEntry(ThemeData theme) {
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
                      const Spacer(),
                      Text(
                        'ACESSO EXCLUSIVO',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 12, letterSpacing: 5, color: TabuColors.subtle,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 40),
                    ],
                  ),

                  const Spacer(flex: 2),

                  // Ícone cadeado animado
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) => Transform.scale(
                      scale: _pulse.value,
                      child: SizedBox(
                        width: 64, height: 64,
                        child: CustomPaint(painter: _LockRosaIcon()),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    'CÓDIGO DE ACESSO',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontSize: 20, letterSpacing: 4,
                      color: TabuColors.branco, fontWeight: FontWeight.w400,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    'Insira o código recebido para\nacessar o TABU Lounge.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: TabuColors.subtle, fontSize: 12,
                      height: 1.7, letterSpacing: 0.4,
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Campos do código com shake
                  AnimatedBuilder(
                    animation: _shakeAnim,
                    builder: (_, child) {
                      final offset = _hasError
                          ? math.sin(_shakeAnim.value * math.pi * 5) * 8.0
                          : 0.0;
                      return Transform.translate(offset: Offset(offset, 0), child: child);
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(_codeLength, (i) => _buildDigitBox(i, theme)),
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
                                Container(width: 4, height: 4,
                                  decoration: const BoxDecoration(color: TabuColors.rosaPrincipal, shape: BoxShape.circle)),
                                const SizedBox(width: 8),
                                Text(_errorMsg,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: TabuColors.rosaPrincipal, fontSize: 11, letterSpacing: 1,
                                  )),
                                const SizedBox(width: 8),
                                Container(width: 4, height: 4,
                                  decoration: const BoxDecoration(color: TabuColors.rosaPrincipal, shape: BoxShape.circle)),
                              ],
                            ),
                          )
                        : const SizedBox(key: ValueKey('no-error'), height: 14),
                  ),

                  const Spacer(flex: 2),

                  _ActionButton(
                    label: 'VALIDAR CÓDIGO',
                    enabled: _codeComplete && !_isLoading,
                    onTap: _validateCode,
                  ),

                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(width: 1, height: 12, color: TabuColors.border),
                      const SizedBox(width: 10),
                      Text(
                        'Código enviado via WhatsApp ou e-mail',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: TabuColors.subtle, fontSize: 10, letterSpacing: 0.5,
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
                          letterSpacing: 5, color: TabuColors.subtle, fontSize: 7,
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

  Widget _buildDigitBox(int index, ThemeData theme) {
    final isFocused = _focused[index];
    final hasValue  = _controllers[index].text.isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 44, height: 54,
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
            ? [BoxShadow(color: TabuColors.glow.withOpacity(0.3), blurRadius: 16)]
            : hasValue && !_hasError
                ? [BoxShadow(color: TabuColors.glow.withOpacity(0.15), blurRadius: 8)]
                : [],
      ),
      child: RawKeyboardListener(
        focusNode: FocusNode(),
        onKey: (event) => _onKeyDown(index, event),
        child: Center(
          child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          textAlign: TextAlign.center,
          maxLength: 1,
          keyboardType: TextInputType.text,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
            LengthLimitingTextInputFormatter(1),
          ],
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 0,
            color: _hasError
                ? TabuColors.rosaPrincipal
                : hasValue ? TabuColors.branco : TabuColors.subtle,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            counterText: '',
            contentPadding: EdgeInsets.symmetric(vertical: 16),
            isDense: true,
            isCollapsed: false,
          ),
          onChanged: (v) => _onDigitChanged(index, v),
        ),
        ),
      ),
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
                width: 96, height: 96,
                child: CustomPaint(painter: _SuccessRosaIcon()),
              ),
            ),
          ),
          const SizedBox(height: 32),
          FadeTransition(
            opacity: _successFade,
            child: Text(
              'ACESSO LIBERADO',
              style: theme.textTheme.headlineLarge?.copyWith(
                fontSize: 19, letterSpacing: 6,
                color: TabuColors.branco, fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FadeTransition(
            opacity: _successFade,
            child: Text(
              'Bem-vindo ao TABU Lounge.\nSua experiência exclusiva começa agora.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: TabuColors.subtle, fontSize: 12, height: 1.8, letterSpacing: 0.3,
              ),
            ),
          ),
          const Spacer(flex: 2),
          FadeTransition(
            opacity: _successFade,
            child: _ActionButton(
              label: 'IDENTIFICAR-SE',
              enabled: true,
              onTap: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            ),
          ),
          const Spacer(flex: 1),
          FadeTransition(
            opacity: _successFade,
            child: Text(
              'TABU BAR & LOUNGE',
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 5, color: TabuColors.subtle, fontSize: 7,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── Botão de ação ────────────────────────────────────────────────────────────
class _ActionButton extends StatefulWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  const _ActionButton({required this.label, required this.enabled, required this.onTap});
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
    _shimmer = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() { _shimmer.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.enabled ? (_) { setState(() => _pressed = false); widget.onTap(); } : null,
      onTapCancel: widget.enabled ? () => setState(() => _pressed = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: double.infinity, height: 54,
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
                  BoxShadow(color: TabuColors.glow, blurRadius: 24, offset: const Offset(0, 6)),
                  BoxShadow(color: TabuColors.rosaPrincipal.withOpacity(0.25), blurRadius: 32, offset: const Offset(0, 12)),
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
                fontSize: 12, letterSpacing: 5, fontWeight: FontWeight.w700,
                color: widget.enabled ? TabuColors.branco : TabuColors.subtle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Ícone: Cadeado Rosa ──────────────────────────────────────────────────────
class _LockRosaIcon extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Halo de fundo
    canvas.drawCircle(Offset(cx, cy), cx,
        Paint()..color = TabuColors.rosaPrincipal.withOpacity(0.12)..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(cx, cy), cx,
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

    final arcRect = Rect.fromCenter(center: Offset(cx, cy - 3), width: 18, height: 16);
    canvas.drawArc(arcRect, math.pi, math.pi, false, bodyPaint);

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy + 7), width: 24, height: 18),
      const Radius.circular(3),
    );
    canvas.drawRRect(bodyRect, bodyPaint);
    canvas.drawCircle(Offset(cx, cy + 7), 3,
        Paint()..color = TabuColors.rosaPrincipal..style = PaintingStyle.fill);

    // Glow
    canvas.drawRRect(bodyRect,
        Paint()
          ..color = TabuColors.glow
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
  }

  @override
  bool shouldRepaint(_LockRosaIcon old) => false;
}

// ─── Ícone: Check Sucesso Rosa ────────────────────────────────────────────────
class _SuccessRosaIcon extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Círculo de fundo
    canvas.drawCircle(Offset(cx, cy), cx,
        Paint()..color = TabuColors.rosaPrincipal.withOpacity(0.15)..style = PaintingStyle.fill);
    // Borda com glow
    canvas.drawCircle(Offset(cx, cy), cx,
        Paint()
          ..color = TabuColors.rosaPrincipal
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    // Borda fina branca
    canvas.drawCircle(Offset(cx, cy), cx,
        Paint()..color = TabuColors.branco.withOpacity(0.4)..style = PaintingStyle.stroke..strokeWidth = 1.0);

    final check = Path()
      ..moveTo(cx - 18, cy)
      ..lineTo(cx - 5, cy + 13)
      ..lineTo(cx + 18, cy - 15);

    // Glow do check
    canvas.drawPath(check,
        Paint()
          ..color = TabuColors.glow
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    // Check branco
    canvas.drawPath(check,
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
          colors: [Colors.transparent, color, color.withOpacity(0.5), color, Colors.transparent],
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