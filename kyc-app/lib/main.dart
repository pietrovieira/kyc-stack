import 'package:flutter/material.dart';
import 'theme/obsidian_theme.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profile_step_screen.dart';
import 'screens/kyc_step_screen.dart';
import 'screens/kyc_screen.dart';
import 'services/customer_service.dart';

void main() {
  runApp(const ObsidianApp());
}

class ObsidianApp extends StatelessWidget {
  const ObsidianApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Banco Obsidian',
      debugShowCheckedModeBanner: false,
      theme: ObsidianTheme.dark,
      home: const AppNavigator(),
    );
  }
}

class AppNavigator extends StatefulWidget {
  const AppNavigator({super.key});
  @override
  State<AppNavigator> createState() => _AppNavigatorState();
}

class _AppNavigatorState extends State<AppNavigator> {
  final _customerService = CustomerService();
  String? _cpf;
  int _navIndex = 0;

  @override
  void dispose() {
    _customerService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Mantém kyc_screen.dart preservada como aba "Avançado"
    return Scaffold(
      body: IndexedStack(
        index: _navIndex,
        children: [
          OnboardingScreen(
            onStart: () async {
              final cpf = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileStepScreen(
                    customerService: _customerService,
                    onProfileCreated: (cpf, data) {
                      setState(() => _cpf = cpf);
                      Navigator.pop(context, cpf);
                    },
                  ),
                ),
              );
              if (cpf != null && mounted) {
                setState(() => _cpf = cpf);
                // vai para KYC
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => KycStepScreen(cpf: cpf, customerService: _customerService)),
                );
              }
            },
          ),
          // Fluxo direto para testes rápidos
          ProfileStepScreen(
            customerService: _customerService,
            onProfileCreated: (cpf, data) {
              setState(() => _cpf = cpf);
              Navigator.push(context, MaterialPageRoute(builder: (_) => KycStepScreen(cpf: cpf, customerService: _customerService)));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('CPF $cpf cadastrado'), backgroundColor: ObsidianTheme.purple));
            },
          ),
          if (_cpf != null) KycStepScreen(cpf: _cpf!, customerService: _customerService) else const Center(child: Text('Cadastre o perfil primeiro', style: TextStyle(color: Colors.white70))),
          const KycScreen(), // preservada
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF0A0A0A),
        indicatorColor: ObsidianTheme.purple.withOpacity(0.2),
        selectedIndex: _navIndex,
        onDestinationSelected: (i) => setState(() => _navIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Início'),
          NavigationDestination(icon: Icon(Icons.person_add), label: 'Perfil'),
          NavigationDestination(icon: Icon(Icons.document_scanner), label: 'KYC'),
          NavigationDestination(icon: Icon(Icons.verified_user), label: 'Avançado'),
        ],
      ),
    );
  }
}
