import 'package:flutter/material.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/services/services_app/auth_service.dart';

class HomeScreen extends StatelessWidget {
  final Map<String, dynamic> userData;
  const HomeScreen({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authService = AuthService();

    return Scaffold(
      backgroundColor: TabuColors.rosaPrincipal,
      body: Stack(
        children: [
          // Fundo
          Positioned.fill(
            child: CustomPaint(painter: _FundoSimples()),
          ),
          // Barra neon
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 48),

                  // Ícone
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0x28FFFFFF),
                      shape: BoxShape.circle,
                      border: Border.all(color: TabuColors.neonCyan.withOpacity(0.4), width: 1),
                      boxShadow: [BoxShadow(color: TabuColors.neonCyan.withOpacity(0.15), blurRadius: 20)],
                    ),
                    child: const Icon(Icons.person_outline, color: TabuColors.branco, size: 32),
                  ),

                  const SizedBox(height: 20),

                  // Saudação
                  Text(
                    'OLÁ,',
                    style: theme.textTheme.labelSmall?.copyWith(color: TabuColors.textoMuted, letterSpacing: 4, fontSize: 10),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (userData['nome'] as String? ?? 'Usuário').toUpperCase(),
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontSize: 28, letterSpacing: 6, color: TabuColors.branco, fontWeight: FontWeight.w400,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Card de dados
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0x22FFFFFF),
                      border: Border.all(color: TabuColors.border, width: 0.8),
                      boxShadow: [BoxShadow(color: TabuColors.neonCyan.withOpacity(0.08), blurRadius: 20)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(width: 5, height: 5, decoration: const BoxDecoration(color: TabuColors.neonCyan, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Text('INFORMAÇÕES DA CONTA', style: theme.textTheme.labelSmall?.copyWith(color: TabuColors.neonCyan, letterSpacing: 3, fontSize: 8)),
                        ]),
                        const SizedBox(height: 20),
                        Container(height: 0.5, color: TabuColors.borderNeon),
                        const SizedBox(height: 20),

                        _InfoRow(icon: Icons.person_outline,   label: 'NOME',   value: userData['nome']  ?? '—'),
                        const SizedBox(height: 16),
                        _InfoRow(icon: Icons.mail_outline,     label: 'E-MAIL', value: userData['email'] ?? '—'),
                        const SizedBox(height: 16),
                        _InfoRow(icon: Icons.fingerprint,      label: 'UID',    value: userData['uid']   ?? '—', small: true),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Botão logout
                  GestureDetector(
                    onTap: () async {
                      await authService.signOut();
                    },
                    child: Container(
                      width: double.infinity, height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0x22FFFFFF),
                        border: Border.all(color: TabuColors.border, width: 0.8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.logout, color: TabuColors.textoMuted, size: 16),
                          const SizedBox(width: 10),
                          Text('SAIR', style: theme.textTheme.labelLarge?.copyWith(fontSize: 12, letterSpacing: 5, color: TabuColors.textoMuted)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                  Text('— TABU BAR & LOUNGE —', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 4, color: TabuColors.textoMuted, fontSize: 7)),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool small;
  const _InfoRow({required this.icon, required this.label, required this.value, this.small = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: TabuColors.textoMuted, size: 16),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelSmall?.copyWith(color: TabuColors.textoMuted, fontSize: 8, letterSpacing: 2)),
              const SizedBox(height: 4),
              Text(value, style: theme.textTheme.bodySmall?.copyWith(
                color: TabuColors.branco, fontSize: small ? 10 : 13, letterSpacing: small ? 0.2 : 0.5,
              )),
            ],
          ),
        ),
      ],
    );
  }
}

class _FundoSimples extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = TabuColors.rosaPrincipal);
    canvas.drawCircle(Offset(size.width * 0.8, -size.height * 0.05), size.width * 0.9, Paint()
      ..shader = RadialGradient(
        colors: [TabuColors.neonCyan.withOpacity(0.15), Colors.transparent],
      ).createShader(Rect.fromCircle(center: Offset(size.width * 0.8, -size.height * 0.05), radius: size.width * 0.9)));
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.9), size.width * 0.6, Paint()
      ..shader = RadialGradient(
        colors: [TabuColors.rosaEscuro.withOpacity(0.2), Colors.transparent],
      ).createShader(Rect.fromCircle(center: Offset(size.width * 0.1, size.height * 0.9), radius: size.width * 0.6)));
  }
  @override
  bool shouldRepaint(_FundoSimples old) => false;
}