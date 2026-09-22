import 'package:flutter/material.dart';
import '../theme/obsidian_theme.dart';
import '../services/customer_service.dart';

class ProfileStepScreen extends StatefulWidget {
  final CustomerService customerService;
  final Function(String cpf, Map<String, dynamic> data) onProfileCreated;
  const ProfileStepScreen({super.key, required this.customerService, required this.onProfileCreated});

  @override
  State<ProfileStepScreen> createState() => _ProfileStepScreenState();
}

class _ProfileStepScreenState extends State<ProfileStepScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cpf = TextEditingController();
  final _nome = TextEditingController();
  final _sobrenome = TextEditingController();
  final _dob = TextEditingController();
  final _email = TextEditingController();
  final _telefone = TextEditingController();
  final _logradouro = TextEditingController();
  final _numero = TextEditingController();
  final _complemento = TextEditingController();
  final _bairro = TextEditingController();
  final _cidade = TextEditingController();
  final _estado = TextEditingController();
  final _cep = TextEditingController();
  final _pais = TextEditingController(text: 'Brasil');
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _cpf.dispose();
    _nome.dispose();
    _sobrenome.dispose();
    _dob.dispose();
    _email.dispose();
    _telefone.dispose();
    _logradouro.dispose();
    _numero.dispose();
    _complemento.dispose();
    _bairro.dispose();
    _cidade.dispose();
    _estado.dispose();
    _cep.dispose();
    _pais.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final res = await widget.customerService.createProfile(
        cpf: _cpf.text,
        nome: _nome.text,
        sobrenome: _sobrenome.text,
        dataNascimento: _dob.text,
        email: _email.text,
        telefone: _telefone.text,
        logradouro: _logradouro.text,
        numero: _numero.text,
        complemento: _complemento.text,
        bairro: _bairro.text,
        cidade: _cidade.text,
        estado: _estado.text,
        cep: _cep.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil criado! Indo para KYC'), backgroundColor: ObsidianTheme.purple));
      widget.onProfileCreated(_cpf.text, res);
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
                  const SizedBox(width: 8),
                  const Text('Etapa 1 • Perfil e Endereço', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: ObsidianTheme.purple.withOpacity(0.2), borderRadius: BorderRadius.circular(20)), child: const Text('1/2', style: TextStyle(color: ObsidianTheme.purpleLight, fontSize: 12))),
                ]),
                const SizedBox(height: 16),
                if (_error != null)
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
                const SizedBox(height: 12),
                _Section(title: 'Dados pessoais', children: [
                  _Field(
                    controller: _cpf,
                    label: 'CPF (apenas números, único) *',
                    prefix: Icons.badge,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'CPF é obrigatório';
                      final digits = v.replaceAll(RegExp(r'\D'), '');
                      if (digits.length != 11) return 'CPF deve ter 11 dígitos';
                      return null;
                    },
                  ),
                  Row(children: [
                    Expanded(child: _Field(controller: _nome, label: 'Nome *', prefix: Icons.person)),
                    const SizedBox(width: 12),
                    Expanded(child: _Field(controller: _sobrenome, label: 'Sobrenome *', prefix: Icons.person_outline)),
                  ]),
                  _Field(
                    controller: _dob,
                    label: 'Data nascimento (YYYY-MM-DD) *',
                    prefix: Icons.cake,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Data é obrigatória';
                      if (DateTime.tryParse(v) == null) return 'Use YYYY-MM-DD';
                      return null;
                    },
                  ),
                  _Field(
                    controller: _email,
                    label: 'Email (opcional)',
                    prefix: Icons.email,
                    required: false,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) return 'Email inválido';
                      return null;
                    },
                  ),
                  _Field(
                    controller: _telefone,
                    label: 'Telefone (opcional)',
                    prefix: Icons.phone,
                    required: false,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final digits = v.replaceAll(RegExp(r'\D'), '');
                      if (digits.length < 10) return 'Telefone inválido';
                      return null;
                    },
                  ),
                ]),
                const SizedBox(height: 16),
                _Section(title: 'Endereço completo', children: [
                  Row(children: [
                    Expanded(flex: 3, child: _Field(controller: _logradouro, label: 'Logradouro *', prefix: Icons.location_on)),
                    const SizedBox(width: 12),
                    Expanded(child: _Field(controller: _numero, label: 'Número *')),
                  ]),
                  _Field(controller: _complemento, label: 'Complemento (opcional)', required: false),
                  _Field(controller: _bairro, label: 'Bairro *', prefix: Icons.map),
                  Row(children: [
                    Expanded(flex: 2, child: _Field(controller: _cidade, label: 'Cidade *')),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Field(
                        controller: _estado,
                        label: 'UF *',
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Obrigatório';
                          if (v.trim().length != 2) return '2 letras';
                          return null;
                        },
                      ),
                    ),
                  ]),
                  Row(children: [
                    Expanded(
                      child: _Field(
                        controller: _cep,
                        label: 'CEP (00000-000) *',
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'CEP é obrigatório';
                          if (!RegExp(r'^\d{5}-?\d{3}$').hasMatch(v.trim())) return 'CEP inválido';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _Field(controller: _pais, label: 'País', enabled: false)),
                  ]),
                ]),
                const SizedBox(height: 20),
                if (_loading) const LinearProgressIndicator(color: ObsidianTheme.purple),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: _loading ? null : _submit, child: Text(_loading ? 'ENVIANDO...' : 'SALVAR E IR PARA KYC →')),
                const SizedBox(height: 8),
                const Text('Idempotência: mesmo CPF + mesmo payload retorna 200; CPF duplicado com dados diferentes retorna 409.', style: TextStyle(color: Colors.white38, fontSize: 10), textAlign: TextAlign.center),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(16), border: Border.all(color: ObsidianTheme.purple.withOpacity(0.15))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: ObsidianTheme.purpleLight, letterSpacing: 0.6)),
        const SizedBox(height: 12),
        ...children.map((w) => Padding(padding: const EdgeInsets.only(bottom: 12), child: w)),
      ]),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData? prefix;
  final String? Function(String?)? validator;
  final bool required;
  final bool enabled;
  const _Field({required this.controller, required this.label, this.prefix, this.validator, this.required = true, this.enabled = true});
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      validator: validator ?? (required ? (v) => v == null || v.isEmpty ? 'Obrigatório' : null : null),
      decoration: InputDecoration(labelText: label, prefixIcon: prefix != null ? Icon(prefix, size: 18) : null),
      style: const TextStyle(color: Colors.white),
    );
  }
}
