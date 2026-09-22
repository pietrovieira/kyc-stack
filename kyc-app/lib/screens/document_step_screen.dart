import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/obsidian_theme.dart';
import '../services/customer_service.dart';

/// Etapa 2/3 - Enviar documentos com câmera/galeria e FaceTec
class DocumentStepScreen extends StatefulWidget {
  final String cpf;
  final CustomerService customerService;
  final VoidCallback onDocumentsSent;
  const DocumentStepScreen({super.key, required this.cpf, required this.customerService, required this.onDocumentsSent});

  @override
  State<DocumentStepScreen> createState() => _DocumentStepScreenState();
}

class _DocumentStepScreenState extends State<DocumentStepScreen> {
  final ImagePicker _picker = ImagePicker();
  String _docType = 'rg';
  bool _loading = false;
  String? _error;
  XFile? _docImage;
  XFile? _selfieImage;

  Future<void> _pickDoc(ImageSource source) async {
    try {
      final xfile = await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 1200);
      if (xfile != null) {
        setState(() => _docImage = xfile);
      }
    } catch (e) {
      setState(() => _error = 'Erro ao capturar documento: $e');
    }
  }

  Future<void> _pickSelfie(ImageSource source) async {
    try {
      final xfile = await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 800, preferredCameraDevice: CameraDevice.front);
      if (xfile != null) {
        setState(() => _selfieImage = xfile);
      }
    } catch (e) {
      setState(() => _error = 'Erro ao capturar selfie: $e');
    }
  }

  Future<void> _submitDocuments() async {
    if (_docImage == null) {
      setState(() => _error = 'Selecione a foto do RG/CNH');
      return;
    }
    if (_selfieImage == null) {
      setState(() => _error = 'Capture a selfie');
      return;
    }
    if (_loading) return;
    setState(() => _loading = true);
    _error = null;
    try {
      // Converte selfie para base64 para enviar ao Facetec (liveness)
      // Documento também pode ser enviado como base64 adicional se necessário
      final selfieBytes = await File(_selfieImage!.path).readAsBytes();
      final docBytes = await File(_docImage!.path).readAsBytes();
      // Usa selfie como requestBlob principal; doc é enviado junto como base64 concatenado para o worker
      // O Go irá criar KycSession com digest do blob e enfileirar para Facetec
      final selfieB64 = base64Encode(selfieBytes);
      final docB64 = base64Encode(docBytes);
      // Combina ambos para garantir que o backend receba dados (simulação aprova 80%)
      final combinedBlob = '$selfieB64|$docB64';
      final res = await widget.customerService.submitKyc(cpf: widget.cpf, requestBlob: combinedBlob, documentType: _docType);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Documentos enviados'), backgroundColor: ObsidianTheme.purple));
      widget.onDocumentsSent();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildImagePreview(XFile? file, IconData placeholder) {
    if (file == null) {
      return Icon(placeholder, color: ObsidianTheme.purpleLight, size: 28);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(File(file.path), fit: BoxFit.cover, width: 60, height: 60),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: ObsidianTheme.gradient),
        child: SafeArea(
          child: SingleChildScrollView(
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
                    ],
                    onChanged: (v) => setState(() => _docType = v!),
                  ),
                  const SizedBox(height: 20),
                  // Card RG/CNH com 2 botões: Câmera / Galeria
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: ObsidianTheme.purple.withOpacity(0.2))),
                    child: Column(children: [
                      Row(children: [
                        Container(width: 56, height: 56, decoration: BoxDecoration(color: ObsidianTheme.purple.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Center(child: _buildImagePreview(_docImage, Icons.credit_card))),
                        const SizedBox(width: 12),
                        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Foto do RG/CNH', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                          Text('Frente e verso', style: TextStyle(color: Colors.white54, fontSize: 11)),
                        ])),
                        if (_docImage != null) const Icon(Icons.check_circle, color: Colors.green, size: 20),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: OutlinedButton.icon(onPressed: () => _pickDoc(ImageSource.camera), icon: const Icon(Icons.photo_camera, size: 16), label: const Text('Câmera'), style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: ObsidianTheme.purple)))),
                        const SizedBox(width: 8),
                        Expanded(child: OutlinedButton.icon(onPressed: () => _pickDoc(ImageSource.gallery), icon: const Icon(Icons.photo_library, size: 16), label: const Text('Galeria'), style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: const BorderSide(color: Colors.white24)))),
                      ]),
                      if (_docImage != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Selecionado: ${_docImage!.name}', style: const TextStyle(color: Colors.green, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  // Card Selfie com câmera ao clicar
                  GestureDetector(
                    onTap: () => _pickSelfie(ImageSource.camera),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: ObsidianTheme.purple.withOpacity(0.2))),
                      child: Row(children: [
                        Container(width: 56, height: 56, decoration: BoxDecoration(color: ObsidianTheme.purple.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Center(child: _buildImagePreview(_selfieImage, Icons.face))),
                        const SizedBox(width: 12),
                        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Selfie 3D', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                          Text('Toque para abrir câmera', style: TextStyle(color: Colors.white54, fontSize: 11)),
                        ])),
                        if (_selfieImage != null) const Icon(Icons.check_circle, color: Colors.green, size: 20) else const Icon(Icons.camera_alt, color: Colors.white54),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(child: TextButton.icon(onPressed: () => _pickSelfie(ImageSource.gallery), icon: const Icon(Icons.photo_library, size: 14), label: const Text('ou selecionar da galeria', style: TextStyle(fontSize: 11)), style: TextButton.styleFrom(foregroundColor: Colors.white54))),
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
                      label: Text(_loading ? 'ENVIANDO...' : 'ENVIAR PARA VALIDAÇÃO KYC'),
                      style: ElevatedButton.styleFrom(backgroundColor: ObsidianTheme.purple, padding: const EdgeInsets.symmetric(vertical: 16)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Fotos serão enviadas ao serviço Facetec via API. O backoffice analisará.', style: TextStyle(color: Colors.white38, fontSize: 11), textAlign: TextAlign.center),
                ]),
              ),
            ]),
          ),
        ),
      ),
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
