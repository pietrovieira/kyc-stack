import 'package:flutter/material.dart';
import '../theme/obsidian_theme.dart';
import '../services/customer_service.dart';
import '../services/facetec_service.dart';

class KycStepScreen extends StatefulWidget {
  final String cpf;
  final CustomerService customerService;
  const KycStepScreen({super.key, required this.cpf, required this.customerService});

  @override
  State<KycStepScreen> createState() => _KycStepScreenState();
}

class _KycStepScreenState extends State<KycStepScreen> {
  final _facetec = FacetecService();
  String _docType = 'rg';
  bool _loading = false;
  String _log = 'Pronto para KYC. Escolha o documento e inicie a captura Facetec (liveness + doc).';
  Map<String, dynamic>? _lastKyc;
  String? _status;

  Future<void> _refreshStatus() async {
    try {
      final res = await widget.customerService.getStatus(widget.cpf);
      setState(() {
        _status = res['customer']?['customer']?['status'] ?? res['customer']?['status']?.toString();
        final kyc = res['kyc'];
        if (kyc != null) _lastKyc = Map<String, dynamic>.from(kyc);
      });
    } catch (e) {
      _append('Erro status: $e');
    }
  }

  void _append(String m) => setState(() => _log += '\n\n$m');

  Future<void> _submitKyc() async {
    if (_loading) return;
    setState(() => _loading = true);
    _append('→ Iniciando KYC para ${widget.cpf} doc=$_docType');

    // Tenta FaceTec real, fallback para blob fake (testa fluxo async)
    String blob = 'dGVzdGZha2VibG9iX2t5Yw==';
    try {
      final config = await _facetec.fetchConfig();
      await _facetec.initializeSdk(config);
      blob = await _facetec.startLivenessSession(externalDatabaseRefID: widget.cpf);
    } on UnimplementedError {
      _append('⚠ SDK nativo não instalado - usando blob fake para testar worker Redis (80% aprova).');
    } catch (e) {
      _append('⚠ Erro facetec init: $e - usando blob fake');
    }

    try {
      final res = await widget.customerService.submitKyc(cpf: widget.cpf, requestBlob: blob, documentType: _docType);
      _append('✓ KYC enviado: ${res['message']} session=${res['kycSessionId']} status=${res['status']} (processamento async no Redis)');
      _lastKyc = {'id': res['kycSessionId'], 'status': res['status']};
      _status = res['status']?.toString();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('KYC em processamento (background)'), backgroundColor: ObsidianTheme.purple));
      // polling simples
      await Future.delayed(const Duration(seconds: 2));
      await _refreshStatus();
    } catch (e) {
      _append('✗ Erro KYC: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: ObsidianTheme.gradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
                const SizedBox(width: 8),
                const Text('Etapa 2 • KYC Documentos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                const Spacer(),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: ObsidianTheme.purple.withOpacity(0.2), borderRadius: BorderRadius.circular(20)), child: const Text('2/2', style: TextStyle(color: ObsidianTheme.purpleLight, fontSize: 12))),
              ]),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12), border: Border.all(color: ObsidianTheme.purple.withOpacity(0.2))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.badge, color: ObsidianTheme.purple, size: 18),
                    const SizedBox(width: 8),
                    Text('CPF: ${widget.cpf}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
                    const Spacer(),
                    if (_status != null)
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: _status == 'kyc_approved' ? Colors.green.withOpacity(0.2) : _status == 'kyc_rejected' ? Colors.red.withOpacity(0.2) : Colors.white10, borderRadius: BorderRadius.circular(20)), child: Text(_status!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700))),
                  ]),
                  if (_lastKyc != null) ...[
                    const SizedBox(height: 8),
                    Text('KYC sessão: ${_lastKyc!['id']} • liveness: ${_lastKyc!['livenessProven']} • match: ${_lastKyc!['matchLevel'] ?? '-'}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ]),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(16), border: Border.all(color: ObsidianTheme.purple.withOpacity(0.15))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Documento', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: ObsidianTheme.purpleLight)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _docType,
                    decoration: const InputDecoration(labelText: 'Tipo de documento'),
                    dropdownColor: const Color(0xFF1A1A1A),
                    items: const [
                      DropdownMenuItem(value: 'rg', child: Text('RG')),
                      DropdownMenuItem(value: 'cnh', child: Text('CNH')),
                      DropdownMenuItem(value: 'passport', child: Text('Passaporte')),
                    ],
                    onChanged: (v) => setState(() => _docType = v!),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 2.2,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _DocCard(icon: Icons.credit_card, label: 'Foto do RG/CNH', desc: 'Frente e verso'),
                      _DocCard(icon: Icons.face, label: 'Selfie 3D', desc: 'Liveness FaceTec'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_loading) const LinearProgressIndicator(color: ObsidianTheme.purple),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _submitKyc,
                      icon: const Icon(Icons.document_scanner),
                      label: Text(_loading ? 'PROCESSANDO...' : 'ENVIAR PARA VALIDAÇÃO KYC'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: _refreshStatus, style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: const BorderSide(color: Colors.white24)), child: const Text('Atualizar status')),
                ]),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
                  child: SingleChildScrollView(child: Text(_log, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.white70))),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _DocCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String desc;
  const _DocCard({required this.icon, required this.label, required this.desc});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: ObsidianTheme.purple.withOpacity(0.2))),
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: ObsidianTheme.purple.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: ObsidianTheme.purpleLight, size: 20)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11)),
          Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ])),
      ]),
    );
  }
}
