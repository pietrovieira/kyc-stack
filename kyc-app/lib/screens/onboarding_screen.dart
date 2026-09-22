import 'package:flutter/material.dart';
import '../theme/obsidian_theme.dart';

class OnboardingScreen extends StatelessWidget {
  final VoidCallback onStart;
  const OnboardingScreen({super.key, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: ObsidianTheme.gradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [ObsidianTheme.purple, ObsidianTheme.purpleDark]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(child: Text('◈', style: TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w900))),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('BANCO OBSIDIAN', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 16, color: Colors.white)),
                          Text('Seu futuro em roxo e preto', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: ObsidianTheme.purple.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(color: ObsidianTheme.purple.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                        child: const Icon(Icons.account_balance, size: 40, color: ObsidianTheme.purpleLight),
                      ),
                      const SizedBox(height: 16),
                      const Text('Abra sua conta em 3 minutos', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white), textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      const Text('Cadastro 100% digital com validação KYC, FaceTec e segurança ponta a ponta (HASH KEY).', style: TextStyle(color: Colors.white70, fontSize: 13), textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _StepDot(label: 'Perfil', done: true),
                          _StepLine(),
                          _StepDot(label: 'Documento'),
                          _StepLine(),
                          _StepDot(label: 'Conta'),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: onStart,
                  style: ElevatedButton.styleFrom(backgroundColor: ObsidianTheme.purple, padding: const EdgeInsets.symmetric(vertical: 18)),
                  child: const Text('COMEÇAR CADASTRO', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                ),
                const SizedBox(height: 12),
                const Text('Protegido com HMAC-SHA256 • Idempotência • Anti-fraude', style: TextStyle(color: Colors.white38, fontSize: 10), textAlign: TextAlign.center),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final String label;
  final bool done;
  const _StepDot({required this.label, this.done = false});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(color: done ? ObsidianTheme.purple : Colors.white12, shape: BoxShape.circle, border: Border.all(color: ObsidianTheme.purple.withOpacity(0.3))),
        child: Icon(done ? Icons.check : Icons.circle, size: 14, color: Colors.white),
      ),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.white60)),
    ]);
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine();
  @override
  Widget build(BuildContext context) {
    return Container(width: 30, height: 2, margin: const EdgeInsets.only(bottom: 18, left: 4, right: 4), color: Colors.white12);
  }
}
