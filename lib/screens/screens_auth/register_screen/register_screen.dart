import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/screens/screens_home/home_screen/home_screen.dart';
import 'package:tabuapp/services/services_app/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgController;
  late AnimationController _entryController;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  bool _obscurePassword = true;
  bool _obscureConfirm  = true;
  bool _nameFocused     = false;
  bool _emailFocused    = false;
  bool _passwordFocused = false;
  bool _confirmFocused  = false;
  bool _acceptedTerms   = false;
  bool _isLoading       = false;
  String? _errorMsg;

  final _nameController     = TextEditingController();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController  = TextEditingController();

  final _nameFocus     = FocusNode();
  final _emailFocus    = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus  = FocusNode();

  final _authService = AuthService();

  String _password = '';
  bool get _passwordHasLength => _password.length >= 8;
  bool get _passwordHasUpper  => _password.contains(RegExp(r'[A-Z]'));
  bool get _passwordHasNumber => _password.contains(RegExp(r'[0-9]'));

  @override
  void initState() {
    super.initState();
    _bgController    = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat(reverse: true);
    _entryController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..forward();
    _fade  = CurvedAnimation(parent: _entryController, curve: const Interval(0.1, 1.0, curve: Curves.easeOut));
    _slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
      CurvedAnimation(parent: _entryController, curve: const Interval(0.1, 1.0, curve: Curves.easeOut)),
    );
    _nameFocus.addListener(()     => setState(() => _nameFocused     = _nameFocus.hasFocus));
    _emailFocus.addListener(()    => setState(() => _emailFocused    = _emailFocus.hasFocus));
    _passwordFocus.addListener(() => setState(() => _passwordFocused = _passwordFocus.hasFocus));
    _confirmFocus.addListener(()  => setState(() => _confirmFocused  = _confirmFocus.hasFocus));
  }

  @override
  void dispose() {
    _bgController.dispose();
    _entryController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _register() async {
  final nome     = _nameController.text.trim();
  final email    = _emailController.text.trim();
  final senha    = _passwordController.text;
  final confirma = _confirmController.text;

  if (nome.isEmpty || email.isEmpty || senha.isEmpty || confirma.isEmpty) {
    setState(() => _errorMsg = 'Preencha todos os campos.');
    return;
  }
  if (senha != confirma) {
    setState(() => _errorMsg = 'As senhas não coincidem.');
    return;
  }
  if (!_passwordHasLength || !_passwordHasUpper || !_passwordHasNumber) {
    setState(() => _errorMsg = 'A senha não atende aos requisitos.');
    return;
  }

  setState(() { _isLoading = true; _errorMsg = null; });

  try {
    final credential = await _authService.registerWithEmail(
      email: email,
      password: senha,
      displayName: nome,
    );

    final uid = credential?.user?.uid;
    print('✅ Cadastro efetuado — UID: $uid');

    if (uid != null && mounted) {
      final dados = await _authService.getUserData(uid);
      print('📦 Dados salvos: $dados');

      if (mounted && dados != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HomeScreen(userData: dados), // 👈
          ),
        );
      }
    }
  } catch (e) {
    print('❌ Erro no cadastro: $e');
    if (mounted) setState(() => _errorMsg = e.toString());
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  @override
  Widget build(BuildContext context) {
    final size  = MediaQuery.of(context).size;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: TabuColors.rosaPrincipal,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bgController,
              builder: (_, __) => CustomPaint(painter: _FundoRosaPainter(progress: _bgController.value)),
            ),
          ),
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: 4,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [
                  TabuColors.neonGlow, TabuColors.neonCyan, TabuColors.neonBright, TabuColors.neonCyan, TabuColors.neonGlow,
                ]),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).maybePop(),
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0x22FFFFFF),
                            border: Border.all(color: TabuColors.border, width: 0.8),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new, color: TabuColors.branco, size: 16),
                        ),
                      ),
                      const Spacer(),
                      Text('CRIAR CONTA', style: theme.textTheme.labelLarge?.copyWith(fontSize: 11, letterSpacing: 5, color: TabuColors.textoSecundario)),
                      const Spacer(),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: FadeTransition(
                      opacity: _fade,
                      child: SlideTransition(
                        position: _slide,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(height: size.height * 0.03),
                            const _HeaderSection(),
                            SizedBox(height: size.height * 0.04),

                            _TabuTextField(
                              label: 'NOME COMPLETO',
                              hint: 'como quer ser chamado',
                              keyboardType: TextInputType.name,
                              controller: _nameController,
                              focusNode: _nameFocus,
                              isFocused: _nameFocused,
                              prefixIcon: Icons.person_outline,
                            ),
                            const SizedBox(height: 16),

                            _TabuTextField(
                              label: 'E-MAIL',
                              hint: 'seu@email.com',
                              keyboardType: TextInputType.emailAddress,
                              controller: _emailController,
                              focusNode: _emailFocus,
                              isFocused: _emailFocused,
                              prefixIcon: Icons.mail_outline,
                            ),
                            const SizedBox(height: 16),

                            _TabuTextField(
                              label: 'SENHA',
                              hint: 'mínimo 8 caracteres',
                              obscureText: _obscurePassword,
                              controller: _passwordController,
                              focusNode: _passwordFocus,
                              isFocused: _passwordFocused,
                              prefixIcon: Icons.lock_outline,
                              suffixIcon: _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              onSuffixTap: () => setState(() => _obscurePassword = !_obscurePassword),
                              onChanged: (v) => setState(() => _password = v),
                            ),

                            if (_passwordFocused || _password.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              _PasswordStrengthBar(password: _password),
                              const SizedBox(height: 8),
                              _PasswordRules(hasLength: _passwordHasLength, hasUpper: _passwordHasUpper, hasNumber: _passwordHasNumber),
                            ],
                            const SizedBox(height: 16),

                            _TabuTextField(
                              label: 'CONFIRMAR SENHA',
                              hint: 'repita a senha',
                              obscureText: _obscureConfirm,
                              controller: _confirmController,
                              focusNode: _confirmFocus,
                              isFocused: _confirmFocused,
                              prefixIcon: Icons.lock_outline,
                              suffixIcon: _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              onSuffixTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
                            ),
                            const SizedBox(height: 24),

                            _TermsCheckbox(
                              value: _acceptedTerms,
                              onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                            ),

                            // Mensagem de erro
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: _errorMsg != null
                                  ? Padding(
                                      key: const ValueKey('error'),
                                      padding: const EdgeInsets.only(top: 16),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(width: 4, height: 4, decoration: const BoxDecoration(color: TabuColors.rosaVivo, shape: BoxShape.circle)),
                                          const SizedBox(width: 8),
                                          Flexible(child: Text(_errorMsg!, style: theme.textTheme.bodySmall?.copyWith(color: TabuColors.rosaVivo, fontSize: 11, letterSpacing: 1))),
                                          const SizedBox(width: 8),
                                          Container(width: 4, height: 4, decoration: const BoxDecoration(color: TabuColors.rosaVivo, shape: BoxShape.circle)),
                                        ],
                                      ),
                                    )
                                  : const SizedBox(key: ValueKey('no-error')),
                            ),

                            const SizedBox(height: 32),

                            _RegisterButton(
                              enabled: _acceptedTerms && !_isLoading,
                              isLoading: _isLoading,
                              onTap: _register,
                            ),

                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Já tem conta?  ', style: theme.textTheme.bodySmall?.copyWith(fontSize: 12, color: TabuColors.textoSecundario)),
                                GestureDetector(
                                  onTap: () => Navigator.of(context).maybePop(),
                                  child: Text('Entrar', style: theme.textTheme.labelLarge?.copyWith(color: TabuColors.neonGlow, letterSpacing: 1, fontSize: 12)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 40),
                            Text('— TABU BAR & LOUNGE —', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 4, color: TabuColors.textoMuted, fontSize: 8)),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Loading overlay
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: TabuColors.rosaPrincipal.withOpacity(0.35),
                child: Center(
                  child: Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0x28FFFFFF),
                      border: Border.all(color: TabuColors.border, width: 0.8),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(15),
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: TabuColors.branco),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────
class _HeaderSection extends StatelessWidget {
  const _HeaderSection();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        SizedBox(width: 52, height: 52, child: CustomPaint(painter: _NuvemNeonIcon())),
        const SizedBox(height: 16),
        Text(
          'TABU',
          style: theme.textTheme.displaySmall?.copyWith(
            fontSize: 42, letterSpacing: 18, fontWeight: FontWeight.w400, color: TabuColors.branco, height: 1,
            shadows: [Shadow(color: TabuColors.rosaEscuro.withOpacity(0.25), offset: const Offset(2, 3), blurRadius: 6)],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 16, height: 1.5, color: TabuColors.neonCyan),
            const SizedBox(width: 8),
            Text('LOUNGE', style: theme.textTheme.labelSmall?.copyWith(color: TabuColors.neonCyan, letterSpacing: 6, fontSize: 9, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Container(width: 16, height: 1.5, color: TabuColors.neonCyan),
          ],
        ),
        const SizedBox(height: 20),
        Text('Crie sua conta exclusiva', style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, letterSpacing: 1.5, fontSize: 13, color: TabuColors.textoSecundario)),
      ],
    );
  }
}

// ─── Cloud Neon Icon ──────────────────────────────────────────────────────────
class _NuvemNeonIcon extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.drawCircle(Offset(cx, cy), cx, Paint()..color = TabuColors.neonCyan.withOpacity(0.2)..style = PaintingStyle.stroke..strokeWidth = 1.5);
    final cloud = Paint()..color = TabuColors.branco;
    canvas.drawCircle(Offset(cx, cy + 3), 10, cloud);
    canvas.drawCircle(Offset(cx - 8, cy + 6), 7, cloud);
    canvas.drawCircle(Offset(cx + 8, cy + 6), 7, cloud);
    canvas.drawCircle(Offset(cx - 4, cy), 8.5, cloud);
    canvas.drawCircle(Offset(cx + 4, cy), 8.5, cloud);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx - 15, cy + 3, 30, 11), const Radius.circular(3)), cloud);
    final neon = Paint()..color = TabuColors.neonCyan.withOpacity(0.75)..style = PaintingStyle.stroke..strokeWidth = 1.0..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawCircle(Offset(cx - 4, cy), 8.5, neon);
    canvas.drawCircle(Offset(cx + 4, cy), 8.5, neon);
    canvas.drawCircle(Offset(cx, cy + 3), 10, neon);
  }
  @override
  bool shouldRepaint(_NuvemNeonIcon old) => false;
}

// ─── Text Field ───────────────────────────────────────────────────────────────
class _TabuTextField extends StatelessWidget {
  final String label;
  final String hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool isFocused;
  final IconData prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final ValueChanged<String>? onChanged;

  const _TabuTextField({
    required this.label,
    required this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.controller,
    this.focusNode,
    required this.isFocused,
    required this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelSmall?.copyWith(fontSize: 9, letterSpacing: 3, fontWeight: FontWeight.w700, color: isFocused ? TabuColors.branco : TabuColors.textoMuted)),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isFocused ? const Color(0x33FFFFFF) : const Color(0x1AFFFFFF),
            border: Border.all(color: isFocused ? TabuColors.branco : TabuColors.border, width: isFocused ? 1.5 : 0.8),
            boxShadow: isFocused ? [
              BoxShadow(color: Colors.white.withOpacity(0.15), blurRadius: 14, offset: const Offset(0, 4)),
              BoxShadow(color: TabuColors.neonCyan.withOpacity(0.08), blurRadius: 22),
            ] : [],
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            obscureText: obscureText,
            keyboardType: keyboardType,
            onChanged: onChanged,
            style: theme.textTheme.bodyLarge?.copyWith(fontSize: 14, letterSpacing: 0.3, color: TabuColors.branco),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: theme.inputDecorationTheme.hintStyle,
              prefixIcon: Icon(prefixIcon, color: isFocused ? TabuColors.branco : TabuColors.textoMuted, size: 18),
              suffixIcon: suffixIcon != null
                  ? GestureDetector(onTap: onSuffixTap, child: Icon(suffixIcon, color: TabuColors.textoMuted, size: 18))
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Barra de força da senha ──────────────────────────────────────────────────
class _PasswordStrengthBar extends StatelessWidget {
  final String password;
  const _PasswordStrengthBar({required this.password});

  int get _strength {
    int s = 0;
    if (password.length >= 8) s++;
    if (password.contains(RegExp(r'[A-Z]'))) s++;
    if (password.contains(RegExp(r'[0-9]'))) s++;
    if (password.contains(RegExp(r'[!@#\$%^&*]'))) s++;
    return s;
  }

  Color get _color {
    switch (_strength) {
      case 0: case 1: return TabuColors.rosaVivo;
      case 2: return TabuColors.rosaClaro;
      case 3: return TabuColors.neonCyan;
      case 4: return TabuColors.neonBright;
      default: return TabuColors.border;
    }
  }

  String get _label {
    switch (_strength) {
      case 0: case 1: return 'FRACA';
      case 2: return 'MÉDIA';
      case 3: return 'BOA';
      case 4: return 'FORTE';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: List.generate(4, (i) {
              final filled = i < _strength;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 3,
                  margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                  decoration: BoxDecoration(color: filled ? _color : Colors.white.withOpacity(0.2)),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(_label, key: ValueKey(_label), style: TextStyle(fontFamily: 'Outfit', fontSize: 9, letterSpacing: 2, fontWeight: FontWeight.w700, color: _color)),
        ),
      ],
    );
  }
}

// ─── Regras de senha ──────────────────────────────────────────────────────────
class _PasswordRules extends StatelessWidget {
  final bool hasLength;
  final bool hasUpper;
  final bool hasNumber;
  const _PasswordRules({required this.hasLength, required this.hasUpper, required this.hasNumber});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Rule(label: '8+ caracteres', ok: hasLength),
        const SizedBox(width: 12),
        _Rule(label: 'Maiúscula', ok: hasUpper),
        const SizedBox(width: 12),
        _Rule(label: 'Número', ok: hasNumber),
      ],
    );
  }
}

class _Rule extends StatelessWidget {
  final String label;
  final bool ok;
  const _Rule({required this.label, required this.ok});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 12, height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ok ? TabuColors.neonCyan : Colors.transparent,
            border: Border.all(color: ok ? TabuColors.neonCyan : TabuColors.textoMuted, width: 1),
          ),
          child: ok ? const Icon(Icons.check, size: 8, color: Colors.white) : null,
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontFamily: 'Outfit', fontSize: 9, letterSpacing: 0.5, color: ok ? TabuColors.neonCyan : TabuColors.textoMuted)),
      ],
    );
  }
}

// ─── Checkbox de Termos ───────────────────────────────────────────────────────
class _TermsCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  const _TermsCheckbox({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 20, height: 20,
            decoration: BoxDecoration(
              color: value ? TabuColors.branco : Colors.transparent,
              border: Border.all(color: value ? TabuColors.branco : TabuColors.border, width: 1.5),
            ),
            child: value ? Icon(Icons.check, size: 13, color: TabuColors.rosaPrincipal) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, letterSpacing: 0.3, color: TabuColors.textoSecundario, height: 1.5),
                children: [
                  const TextSpan(text: 'Li e aceito os '),
                  TextSpan(text: 'Termos de Uso', style: TextStyle(color: TabuColors.neonGlow, fontWeight: FontWeight.w600, decoration: TextDecoration.underline, decorationColor: TabuColors.neonCyan.withOpacity(0.5))),
                  const TextSpan(text: ' e a '),
                  TextSpan(text: 'Política de Privacidade', style: TextStyle(color: TabuColors.neonGlow, fontWeight: FontWeight.w600, decoration: TextDecoration.underline, decorationColor: TabuColors.neonCyan.withOpacity(0.5))),
                  const TextSpan(text: ' do TABU Lounge'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Botão Criar Conta ────────────────────────────────────────────────────────
class _RegisterButton extends StatefulWidget {
  final bool enabled;
  final bool isLoading;
  final VoidCallback onTap;
  const _RegisterButton({required this.enabled, required this.isLoading, required this.onTap});
  @override
  State<_RegisterButton> createState() => _RegisterButtonState();
}

class _RegisterButtonState extends State<_RegisterButton> with SingleTickerProviderStateMixin {
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
    final theme   = Theme.of(context);
    final enabled = widget.enabled;

    return GestureDetector(
      onTapDown:   enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp:     enabled ? (_) { setState(() => _pressed = false); widget.onTap(); } : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: double.infinity, height: 56,
        transform: Matrix4.identity()..scale(_pressed ? 0.98 : 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: enabled ? LinearGradient(
            colors: _pressed ? [TabuColors.neonGlow, TabuColors.branco] : [TabuColors.branco, TabuColors.neonGlow],
            begin: Alignment.centerLeft, end: Alignment.centerRight,
          ) : null,
          color: enabled ? null : Colors.white.withOpacity(0.15),
          border: Border.all(color: enabled ? Colors.transparent : TabuColors.border, width: 0.8),
          boxShadow: enabled && !_pressed ? [
            BoxShadow(color: Colors.white.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 6)),
            BoxShadow(color: TabuColors.neonCyan.withOpacity(0.25), blurRadius: 32, offset: const Offset(0, 12)),
          ] : [],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (enabled)
              AnimatedBuilder(
                animation: _shimmer,
                builder: (_, __) => CustomPaint(
                  painter: _ShimmerPainter(progress: _shimmer.value, color: TabuColors.neonCyan.withOpacity(0.25)),
                  size: const Size(double.infinity, 56),
                ),
              ),
            widget.isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: TabuColors.rosaPrincipal))
                : Text('CRIAR CONTA', style: theme.textTheme.labelLarge?.copyWith(
                    fontSize: 14, letterSpacing: 5, fontWeight: FontWeight.w700,
                    color: enabled ? TabuColors.rosaPrincipal : TabuColors.textoMuted,
                  )),
          ],
        ),
      ),
    );
  }
}

// ─── Shimmer Painter ──────────────────────────────────────────────────────────
class _ShimmerPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _ShimmerPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width * (progress * 1.6 - 0.3);
    canvas.drawRect(
      Rect.fromLTWH(x - 70, 0, 140, size.height),
      Paint()..shader = LinearGradient(
        colors: [Colors.transparent, color, color.withOpacity(0.5), color, Colors.transparent],
        stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
        transform: GradientRotation(math.pi / 6),
      ).createShader(Rect.fromLTWH(x - 70, 0, 140, size.height)),
    );
  }

  @override
  bool shouldRepaint(_ShimmerPainter old) => old.progress != progress;
}

// ─── Fundo Rosa Animado ───────────────────────────────────────────────────────
class _FundoRosaPainter extends CustomPainter {
  final double progress;
  const _FundoRosaPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = TabuColors.rosaPrincipal);
    final r1 = size.width * (0.9 + progress * 0.15);
    canvas.drawCircle(Offset(size.width * 0.65, -size.height * 0.06), r1, Paint()..shader = RadialGradient(
      colors: [TabuColors.neonCyan.withOpacity(0.20 - progress * 0.05), TabuColors.neonGlow.withOpacity(0.07), Colors.transparent],
      stops: const [0.0, 0.45, 1.0],
    ).createShader(Rect.fromCircle(center: Offset(size.width * 0.65, -size.height * 0.06), radius: r1)));
    final r2 = size.width * (0.5 + (1 - progress) * 0.1);
    canvas.drawCircle(Offset(size.width * 1.08, size.height * 0.12), r2, Paint()..shader = RadialGradient(
      colors: [TabuColors.rosaEscuro.withOpacity(0.25), Colors.transparent],
    ).createShader(Rect.fromCircle(center: Offset(size.width * 1.08, size.height * 0.12), radius: r2)));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..shader = RadialGradient(
      center: const Alignment(0.0, 0.1), radius: 0.65,
      colors: [TabuColors.rosaClaro.withOpacity(0.08 + progress * 0.05), Colors.transparent],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
  }

  @override
  bool shouldRepaint(_FundoRosaPainter old) => old.progress != progress;
}