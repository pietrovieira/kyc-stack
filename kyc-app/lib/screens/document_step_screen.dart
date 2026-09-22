import 'package:flutter/material.dart';
import '../theme/obsidian_theme.dart';
import '../services/customer_service.dart';

/// Etapa 2/3 - Enviar documentos
/// App não comunica com Facetec; apenas envia documentos para o backoffice analisar
class DocumentStepScreen extends StatefulWidget {
  final String cpf;
  final CustomerService customerService;
  final VoidCallback onDocumentsSent;
  const DocumentStepScreen({super.key, required this.cpf, required this.customerService, required this.onDocumentsSent});

  @override
  State<DocumentStepScreen> createState() => _DocumentStepScreenState();
}

class _DocumentStepScreenState extends State<DocumentStepScreen> {
  String _docType = 'rg';
  bool _loading = false;
  String? _error;

  Future<void> _submitDocuments() async {
    if (_loading) return;
    setState(() => _loading = true);
    _error = null;
    try {
      // Envia documentos sem Facetec: usa blob fake; backoffice fará análise manual
      // O worker irá simular 80% aprova, mas o backoffice tem poder final de aprovar/reprovar
      const fakeBlob = 'dGVzdGZha2VibG9iX2RvY3VtZW50cw==';
      final res = await widget.customerService.submitKyc(cpf: widget.cpf, requestBlob: fakeBlob, documentType: _docType);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Documentos enviados'), backgroundColor: ObsidianTheme.purple));
      widget.onDocumentsSent();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
                const Text('Etapa 2 • Enviar documentos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                const Spacer(),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: ObsidianTheme.purple.withOpacity(0.2), borderRadius: BorderRadius.circular(20)), child: const Text('2/3', style: TextStyle(color: ObsidianTheme.purpleLight, fontSize: 12))),
              ]),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _StepDot(label: 'Cadastro', done: true),
                _StepLine(done: true),
                _StepDot(label: 'Documentos', done: false, current: true),
                _StepLine(),
                _StepDot(label: 'Aguardando'),
              ]),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12), border: Border.all(color: ObsidianTheme.purple.withOpacity(0.2))),
                child: Row(children: [
                  const Icon(Icons.badge, color: ObsidianTheme.purple, size: 18),
                  const SizedBox(width: 8),
                  Text('CPF: ${widget.cpf}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
                  const Spacer(),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(20)), child: const Text('Documentos', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white70))),
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
                      _DocCard(icon: Icons.face, label: 'Selfie', desc: 'Foto do rosto'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 11))),
                  if (_error != null) const SizedBox(height: 12),
                  if (_loading) const LinearProgressIndicator(color: ObsidianTheme.purple),
                  if (_loading) const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _submitDocuments,
                      icon: const Icon(Icons.send),
                      label: Text(_loading ? 'ENVIANDO...' : 'ENVIAR DOCUMENTOS'),
                      style: ElevatedButton.styleFrom(backgroundColor: ObsidianTheme.purple, padding: const EdgeInsets.symmetric(vertical: 16)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Seus documentos serão analisados pelo backoffice. O status será atualizado na próxima etapa.', style: TextStyle(color: Colors.white38, fontSize: 11), textAlign: TextAlign.center),
                ]),
              ),
              const Spacer(),
              const Text('Etapa 2 de 3 • Sem Facetec no app', style: TextStyle(color: Colors.white30, fontSize: 11), textAlign: TextAlign.center),
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

class _StepDot extends StatelessWidget {
  final String label;
  final bool done;
  final bool current;
  const _StepDot({required this.label, this.done = false, this.current = false});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(color: current ? ObsidianTheme.purple : (done ? ObsidianTheme.purple : Colors.white12), shape: BoxShape.circle, border: Border.all(color: ObsidianTheme.purple.withOpacity(0.3))),
        child: Icon(done ? Icons.check : Icons.circle, size: 14, color: Colors.white),
      ),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.white60)),
    ]);
  }
}

class _StepLine extends StatelessWidget {
  final bool done;
  const _StepLine({this.done = false});
  @override
  Widget build(BuildContext context) {
    return Container(width: 30, height: 2, margin: const EdgeInsets.only(bottom: 18, left: 4, right: 4), color: done ? ObsidianTheme.purple.withOpacity(0.5) : Colors.white12);
  }
}
