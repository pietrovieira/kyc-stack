import 'package:flutter/material.dart';
import '../services/facetec_service.dart';

/// KycScreen - Fluxo completo FaceTec para KYC
/// Demonstra: Liveness -> Enrollment -> Verification -> Photo ID Match
/// https://dev.facetec.com/getting-started
class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  final _facetec = FacetecService();
  final _externalIdController = TextEditingController();

  String _log = 'Pronto para iniciar.\n1. Configure backend/.env com chaves de dev.facetec.com\n2. Rode FaceTec Server em :8080\n3. Clique em um fluxo abaixo.';
  bool _loading = false;
  bool _serverOk = false;

  @override
  void initState() {
    super.initState();
    _checkServer();
  }

  Future<void> _checkServer() async {
    final ok = await _facetec.isServerRunning();
    setState(() => _serverOk = ok);
    _appendLog(ok ? '✓ FaceTec Server OK (:8080/status)' : '✗ FaceTec Server OFF - rode ./facetec-server/Deployment-Scripts/run.sh');
  }

  void _appendLog(String msg) => setState(() => _log += '\n\n$msg');

  Future<void> _runFlow(String sessionType) async {
    if (_loading) return;
    if (_externalIdController.text.trim().isEmpty) {
      _appendLog('✗ Erro: externalDatabaseRefID é obrigatório (CPF/UUID)');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe o CPF/UUID (obrigatório)'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _loading = true);
    _appendLog('→ Iniciando $sessionType para ${_externalIdController.text}...');

    try {
      // 1. Buscar config e inicializar SDK
      final config = await _facetec.fetchConfig();
      _appendLog('Config: deviceKey=${config.deviceKeyIdentifier.substring(0, 8)}... env=${config.environment}');
      await _facetec.initializeSdk(config);
      _appendLog('✓ SDK inicializado (mock - instale facetec_sdk para real)');

      // 2. Iniciar sessão - geraria requestBlob via Device SDK
      // Em prod, isso abre a câmera e faz o 3D FaceScan (2-3s)
      try {
        final blob = await _facetec.startLivenessSession(externalDatabaseRefID: _externalIdController.text);
        // 3. Enviar para o backend
        final result = await _facetec.processRequest(
          requestBlob: blob,
          externalDatabaseRefID: _externalIdController.text,
          sessionType: sessionType,
        );
        _appendLog('Resultado: liveness=${result.livenessProven} success=${result.success} match=${result.matchLevel}\n${result.facetec}');
        if (result.isSuccess) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$sessionType OK!'), backgroundColor: Colors.green));
        }
      } on UnimplementedError catch (e) {
        _appendLog('⚠ SDK nativo não instalado (esperado em dev sem ZIP):\n$e\n\nPara testar sem câmera, use o mock do backend:\nPOST /api/facetec/process com requestBlob fake + veja KycSession no Rails.');
        // Demo: chama backend com blob fake para mostrar o fluxo de erro/sucesso
        try {
          final result = await _facetec.processRequest(
            requestBlob: 'dGVzdGZha2VibG9i', // base64 fake - Server vai rejeitar, mas valida o proxy
            externalDatabaseRefID: _externalIdController.text,
            sessionType: sessionType,
          );
          _appendLog('Proxy OK (mesmo com blob fake): ${result.facetec}');
        } catch (e2) {
          _appendLog('Proxy resposta (esperado falhar com blob fake): $e2');
        }
      }
    } catch (e) {
      _appendLog('✗ Erro: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _facetec.dispose();
    _externalIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KYC - FaceTec'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _checkServer),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Chip(
              label: Text(_serverOk ? 'Server ON' : 'Server OFF', style: const TextStyle(fontSize: 10)),
              backgroundColor: _serverOk ? Colors.green[100] : Colors.red[100],
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _externalIdController,
              decoration: const InputDecoration(
                labelText: 'externalDatabaseRefID (CPF/UUID) *',
                helperText: 'Obrigatório para enrollment/verification/photo_id_match',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Obrigatório' : null,
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _flowButton('3D Liveness', 'liveness', Icons.face, Colors.blue),
                _flowButton('Enrollment', 'enrollment', Icons.person_add, Colors.green),
                _flowButton('Verificação 3D:3D', 'verification', Icons.verified_user, Colors.orange),
                _flowButton('Foto + Doc 3D:2D', 'photo_id_match', Icons.document_scanner, Colors.purple),
                _flowButton('ID Scan Only', 'id_scan_only', Icons.credit_card, Colors.teal),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading) const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: SingleChildScrollView(child: Text(_log, style: const TextStyle(fontFamily: 'monospace', fontSize: 11))),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Passos Getting Started: 1) dev.facetec.com → Configuration Wizard  2) Download SDK ZIP  3) ./run.sh → :8080/status  4) Configure .env  5) Instale facetec_sdk no pubspec',
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _flowButton(String label, String type, IconData icon, Color color) {
    return ElevatedButton.icon(
      onPressed: _loading ? null : () => _runFlow(type),
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
    );
  }
}
