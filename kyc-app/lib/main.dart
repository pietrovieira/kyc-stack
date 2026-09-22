import 'package:flutter/material.dart';
import 'theme/obsidian_theme.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profile_step_screen.dart';
import 'screens/document_step_screen.dart';
import 'screens/waiting_screen.dart';
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
    // Fluxo 3 steps: 1 Cadastro -> 2 Documentos -> 3 Aguardando (sem tabs, sem Facetec no app)
    return OnboardingScreen(
      onStart: () async {
        final cpf = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileStepScreen(
              customerService: _customerService,
              onProfileCreated: (cpf, data) {
                Navigator.pop(context, cpf);
              },
            ),
          ),
        );
        if (cpf == null || !mounted) return;
        // Etapa 2: Enviar documentos
        final docsSent = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => DocumentStepScreen(
              cpf: cpf,
              customerService: _customerService,
              onDocumentsSent: () => Navigator.pop(context, true),
            ),
          ),
        );
        if (docsSent == true && mounted) {
          // Etapa 3: Aguardando backoffice
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => WaitingScreen(cpf: cpf, customerService: _customerService)),
          );
        } else if (docsSent == null && mounted) {
          // Se voltou sem enviar, ainda vai para aguardando para mostrar status profile_completed
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => WaitingScreen(cpf: cpf, customerService: _customerService)),
          );
        }
      },
    );
  }
}
