import 'package:flutter/material.dart';
import 'theme/obsidian_theme.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profile_step_screen.dart';
import 'screens/kyc_step_screen.dart';
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

  @override
  void dispose() {
    _customerService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fluxo somente por navegação: Onboarding -> Perfil -> KYC (sem tabs)
    return OnboardingScreen(
      onStart: () async {
        final cpf = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileStepScreen(
              customerService: _customerService,
              onProfileCreated: (cpf, data) {
                // Fecha o Profile e retorna o CPF para o Onboarding
                Navigator.pop(context, cpf);
              },
            ),
          ),
        );
        if (cpf != null && mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => KycStepScreen(cpf: cpf, customerService: _customerService)),
          );
        }
      },
    );
  }
}
