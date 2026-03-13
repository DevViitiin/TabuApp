import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/screens/screens_auth/register_screen/register_screen.dart';
import 'package:tabuapp/screens/screens_home/home_screen/home_screen.dart';
import 'package:tabuapp/services/services_app/auth_service.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  late AnimationController _bgController;
  late AnimationController _entryController;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  bool _obscurePassword = true;
  bool _emailFocused    = false;
  bool _passwordFocused = false;
  bool _isLoading       = false;
  String? _errorMsg;

  Map<String, dynamic>? _userData;

  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus         = FocusNode();
  final _passwordFocus      = FocusNode();
  final _authService        = AuthService();

  @override
  void initState() {
    super.initState();
    _bgController    = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat(reverse: true);
    _entryController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();
    _fade  = CurvedAnimation(parent: _entryController, curve: const Interval(0.15, 1.0, curve: Curves.easeOut));
    _slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
      CurvedAnimation(parent: _entryController, curve: const Interval(0.15, 1.0, curve: Curves.easeOut)),
    );
    _emailFocus.addListener(()    => setState(() => _emailFocused    = _emailFocus.hasFocus));
    _passwordFocus.addListener(() => setState(() => _passwordFocused = _passwordFocus.hasFocus));
  }

  @override
  void dispose() {
    _bgController.dispose();
    _entryController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final senha = _passwordController.text;

    if (email.isEmpty || senha.isEmpty) {
      setState(() => _errorMsg = 'Preencha todos os campos.');
      return;
    }

    setState(() { _isLoading = true; _errorMsg = null; _userData = null; });

    try {
      final credential = await _authService.signInWithEmail(email: email, password: senha);
      final uid = credential?.user?.uid;
      print('✅ Login efetuado — UID: $uid');

      if (uid != null && mounted) {
        final dados = await _authService.getUserData(uid);
        print('📦 Dados do usuário: $dados');

        if (mounted && dados != null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => HomeScreen(userData: dados)),
          );
        }
      }
    } catch (e) {
      print('❌ Erro no login: $e');
      if (mounted) setState(() => _errorMsg = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToRegister() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => const RegisterScreen(),
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
              .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size  = MediaQuery.of(context).size;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: TabuColors.bg,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _bgController,
                builder: (_, __) => CustomPaint(painter: _FundoEscuroPainter(progress: _bgController.value)),
              ),
            ),
            // Linha neon rosa no topo
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                height: 3,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [
                    TabuColors.rosaDeep, TabuColors.rosaPrincipal, TabuColors.rosaClaro, TabuColors.rosaPrincipal, TabuColors.rosaDeep,
                  ]),
                ),
              ),
            ),
            SafeArea(
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
                        SizedBox(height: size.height * 0.07),
                        const _LogoSection(),
                        SizedBox(height: size.height * 0.05),

                        Text('Bem-vindo de volta', style: theme.textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic, letterSpacing: 2, fontSize: 13, color: TabuColors.dim,
                        )),
                        const SizedBox(height: 36),

                        _TabuTextField(
                          label: 'E-MAIL', hint: 'seu@email.com',
                          keyboardType: TextInputType.emailAddress,
                          controller: _emailController,
                          focusNode: _emailFocus, isFocused: _emailFocused,
                          prefixIcon: Icons.mail_outline,
                        ),
                        const SizedBox(height: 16),

                        _TabuTextField(
                          label: 'SENHA', hint: 'sua senha',
                          obscureText: _obscurePassword,
                          controller: _passwordController,
                          focusNode: _passwordFocus, isFocused: _passwordFocused,
                          prefixIcon: Icons.lock_outline,
                          suffixIcon: _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          onSuffixTap: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        const SizedBox(height: 12),

                        Align(
                          alignment: Alignment.centerRight,
                          child: Text('Esqueceu a senha?', style: theme.textTheme.bodySmall?.copyWith(
                            color: TabuColors.rosaClaro, fontStyle: FontStyle.italic, letterSpacing: 1, fontSize: 11,
                          )),
                        ),

                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _errorMsg != null
                              ? Padding(
                                  key: const ValueKey('error'),
                                  padding: const EdgeInsets.only(top: 16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(width: 4, height: 4, decoration: const BoxDecoration(color: TabuColors.rosaPrincipal, shape: BoxShape.circle)),
                                      const SizedBox(width: 8),
                                      Flexible(child: Text(_errorMsg!, style: theme.textTheme.bodySmall?.copyWith(color: TabuColors.rosaPrincipal, fontSize: 11, letterSpacing: 1))),
                                      const SizedBox(width: 8),
                                      Container(width: 4, height: 4, decoration: const BoxDecoration(color: TabuColors.rosaPrincipal, shape: BoxShape.circle)),
                                    ],
                                  ),
                                )
                              : const SizedBox(key: ValueKey('no-error')),
                        ),

                        const SizedBox(height: 36),
                        _LoginButton(isLoading: _isLoading, onTap: _login),

                        if (_userData != null) ...[
                          const SizedBox(height: 24),
                          _UserDataCard(userData: _userData!),
                        ],

                        const SizedBox(height: 28),

                        GestureDetector(
                          onTap: _goToRegister,
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: RichText(
                              text: TextSpan(
                                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12, letterSpacing: 0.5),
                                children: [
                                  const TextSpan(text: 'Novo membro?  '),
                                  TextSpan(
                                    text: 'Criar uma conta',
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: TabuColors.rosaPrincipal, letterSpacing: 1, fontSize: 12,
                                      decoration: TextDecoration.underline,
                                      decorationColor: TabuColors.rosaPrincipal.withOpacity(0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 48),
                        Text('— TABU BAR & LOUNGE —', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 4, color: TabuColors.subtle, fontSize: 8)),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),

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
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: TabuColors.rosaPrincipal),
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
}

// ─── Card de dados do usuário ─────────────────────────────────────────────────
class _UserDataCard extends StatelessWidget {
  final Map<String, dynamic> userData;
  const _UserDataCard({required this.userData});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: TabuColors.bgCard,
        border: Border.all(color: TabuColors.borderMid, width: 0.8),
        boxShadow: [BoxShadow(color: TabuColors.glow.withOpacity(0.15), blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 6, height: 6, decoration: const BoxDecoration(color: TabuColors.rosaPrincipal, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text('DADOS DO USUÁRIO', style: theme.textTheme.labelSmall?.copyWith(color: TabuColors.rosaPrincipal, letterSpacing: 3, fontSize: 9)),
          ]),
          const SizedBox(height: 16),
          Container(height: 0.5, color: TabuColors.border),
          const SizedBox(height: 16),
          _DataRow(label: 'UID',    value: userData['uid']      ?? '—'),
          _DataRow(label: 'NOME',   value: userData['nome']     ?? '—'),
          _DataRow(label: 'E-MAIL', value: userData['email']    ?? '—'),
          _DataRow(label: 'CRIADO', value: userData['criadoEm'] ?? '—'),
          _DataRow(label: 'ATIVO',  value: userData['ativo'].toString()),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final String label;
  final String value;
  const _DataRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(label, style: theme.textTheme.labelSmall?.copyWith(color: TabuColors.subtle, fontSize: 8, letterSpacing: 2)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value, style: theme.textTheme.bodySmall?.copyWith(color: TabuColors.branco, fontSize: 11, letterSpacing: 0.3)),
          ),
        ],
      ),
    );
  }
}

// ─── Logo ─────────────────────────────────────────────────────────────────────
class _LogoSection extends StatelessWidget {
  const _LogoSection();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        SizedBox(width: 64, height: 64, child: CustomPaint(painter: _RosaGlowIcon())),
        const SizedBox(height: 20),
        Text(
          'TABU',
          style: theme.textTheme.displayMedium?.copyWith(
            fontSize: 60, letterSpacing: 24, fontWeight: FontWeight.w400, color: TabuColors.branco, height: 1,
            shadows: [Shadow(color: TabuColors.glow, offset: const Offset(0, 0), blurRadius: 24)],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 20, height: 1.5, color: TabuColors.rosaPrincipal),
            const SizedBox(width: 10),
            Text('LOUNGE', style: theme.textTheme.labelSmall?.copyWith(color: TabuColors.rosaPrincipal, letterSpacing: 6, fontSize: 10, fontWeight: FontWeight.w700)),
            const SizedBox(width: 10),
            Container(width: 20, height: 1.5, color: TabuColors.rosaPrincipal),
          ],
        ),
      ],
    );
  }
}

// ─── Rosa Glow Icon ───────────────────────────────────────────────────────────
class _RosaGlowIcon extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    // Halo externo
    canvas.drawCircle(Offset(cx, cy), cx, Paint()
      ..color = TabuColors.rosaPrincipal.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);
    // Ícone rosa
    final rosa = Paint()..color = TabuColors.rosaPrincipal;
    canvas.drawCircle(Offset(cx, cy + 3), 11, rosa);
    canvas.drawCircle(Offset(cx - 9, cy + 6), 8, rosa);
    canvas.drawCircle(Offset(cx + 9, cy + 6), 8, rosa);
    canvas.drawCircle(Offset(cx - 4, cy - 1), 9, rosa);
    canvas.drawCircle(Offset(cx + 4, cy - 1), 9, rosa);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx - 17, cy + 3, 34, 12), const Radius.circular(3)), rosa);
    // Glow
    final glow = Paint()
      ..color = TabuColors.glow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(Offset(cx - 4, cy - 1), 9, glow);
    canvas.drawCircle(Offset(cx + 4, cy - 1), 9, glow);
    canvas.drawCircle(Offset(cx, cy + 3), 11, glow);
  }
  @override
  bool shouldRepaint(_RosaGlowIcon old) => false;
}

// ─── TextField ────────────────────────────────────────────────────────────────
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

  const _TabuTextField({
    required this.label, required this.hint,
    this.obscureText = false, this.keyboardType,
    this.controller, this.focusNode,
    required this.isFocused, required this.prefixIcon,
    this.suffixIcon, this.onSuffixTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 9, letterSpacing: 3, fontWeight: FontWeight.w700,
          color: isFocused ? TabuColors.rosaPrincipal : TabuColors.subtle,
        )),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isFocused ? const Color(0x14E85D8A) : TabuColors.bgCard,
            border: Border.all(
              color: isFocused ? TabuColors.borderMid : TabuColors.border,
              width: isFocused ? 1.5 : 0.8,
            ),
            boxShadow: isFocused ? [
              BoxShadow(color: TabuColors.glow.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4)),
            ] : [],
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: theme.textTheme.bodyLarge?.copyWith(fontSize: 14, letterSpacing: 0.3, color: TabuColors.branco),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: theme.inputDecorationTheme.hintStyle,
              prefixIcon: Icon(prefixIcon, color: isFocused ? TabuColors.rosaPrincipal : TabuColors.subtle, size: 18),
              suffixIcon: suffixIcon != null
                  ? GestureDetector(onTap: onSuffixTap, child: Icon(suffixIcon, color: TabuColors.subtle, size: 18))
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

// ─── Botão Login ──────────────────────────────────────────────────────────────
class _LoginButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback onTap;
  const _LoginButton({required this.isLoading, required this.onTap});
  @override
  State<_LoginButton> createState() => _LoginButtonState();
}

class _LoginButtonState extends State<_LoginButton> with SingleTickerProviderStateMixin {
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
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp:   (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: double.infinity, height: 56,
        transform: Matrix4.identity()..scale(_pressed ? 0.98 : 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: _pressed
              ? const LinearGradient(colors: [TabuColors.rosaDeep, TabuColors.rosaPrincipal])
              : const LinearGradient(
                  colors: [TabuColors.rosaPrincipal, TabuColors.rosaClaro],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          boxShadow: _pressed ? [] : [
            BoxShadow(color: TabuColors.glow, blurRadius: 20, offset: const Offset(0, 6)),
            BoxShadow(color: TabuColors.rosaPrincipal.withOpacity(0.3), blurRadius: 30, offset: const Offset(0, 10)),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _shimmer,
              builder: (_, __) => CustomPaint(
                painter: _ShimmerPainter(progress: _shimmer.value, color: Colors.white.withOpacity(0.2)),
                size: const Size(double.infinity, 56),
              ),
            ),
            widget.isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('ENTRAR', style: theme.textTheme.labelLarge?.copyWith(fontSize: 14, letterSpacing: 7, fontWeight: FontWeight.w700, color: TabuColors.branco)),
          ],
        ),
      ),
    );
  }
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

// ─── Fundo Escuro Animado ─────────────────────────────────────────────────────
class _FundoEscuroPainter extends CustomPainter {
  final double progress;
  const _FundoEscuroPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = TabuColors.bg);

    // Halo rosa superior
    final neonRadius = size.width * (0.9 + progress * 0.15);
    canvas.drawCircle(
      Offset(size.width * 0.6, -size.height * 0.08), neonRadius,
      Paint()..shader = RadialGradient(
        colors: [TabuColors.rosaPrincipal.withOpacity(0.20 - progress * 0.06), TabuColors.rosaDeep.withOpacity(0.08), Colors.transparent],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(size.width * 0.6, -size.height * 0.08), radius: neonRadius)),
    );

    // Sombra bgAlt lateral
    final sombraRadius = size.width * (0.55 + (1 - progress) * 0.1);
    canvas.drawCircle(
      Offset(size.width * 1.05, size.height * 0.15), sombraRadius,
      Paint()..shader = RadialGradient(
        colors: [TabuColors.bgAlt.withOpacity(0.9), Colors.transparent],
      ).createShader(Rect.fromCircle(center: Offset(size.width * 1.05, size.height * 0.15), radius: sombraRadius)),
    );

    // Brilho central
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = RadialGradient(
        center: const Alignment(0.0, 0.0), radius: 0.7,
        colors: [TabuColors.rosaDeep.withOpacity(0.10 + progress * 0.06), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
  }
  @override
  bool shouldRepaint(_FundoEscuroPainter old) => old.progress != progress;
}