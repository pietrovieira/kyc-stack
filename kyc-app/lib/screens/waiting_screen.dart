import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/obsidian_theme.dart';
import '../services/customer_service.dart';

/// Tela 3/3 - Aguardando status do backoffice
/// Mostra resumo do cadastro e status, polling a cada 10s
/// Backoffice aprova/reprova -> app atualiza ao abrir novamente
class WaitingScreen extends StatefulWidget {
  final String cpf;
  final CustomerService customerService;
  const WaitingScreen({super.key, required this.cpf, required this.customerService});

  @override
  State<WaitingScreen> createState() => _WaitingScreenState();
}

class _WaitingScreenState extends State<WaitingScreen> {
  Map<String, dynamic>? _customer;
  String? _status;
  bool _loading = true;
  String? _error;
  Timer? _pollTimer;

  String _statusLabel(String s) {
    switch (s) {
      case 'draft':
        return 'Rascunho';
      case 'profile_completed':
        return 'Aguardando análise';
      case 'kyc_pending':
        return 'Em análise';
      case 'kyc_approved':
        return 'Aprovado';
      case 'kyc_rejected':
        return 'Reprovado';
      case 'account_active':
        return 'Conta ativa';
      default:
        return s;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'kyc_approved':
      case 'account_active':
        return Colors.green;
      case 'kyc_rejected':
        return Colors.red;
      case 'kyc_pending':
      case 'profile_completed':
        return ObsidianTheme.purple;
      default:
        return Colors.grey;
    }
  }

  String _statusMessage(String s) {
    switch (s) {
      case 'profile_completed':
      case 'kyc_pending':
        return 'Seu cadastro e documentos foram enviados. O backoffice do Banco Obsidian irá analisar e aprovar ou reprovar em breve.';
      case 'kyc_approved':
        return 'Parabéns! Seu cadastro foi aprovado. Sua conta está sendo ativada.';
      case 'account_active':
        return 'Conta ativa! Bem-vindo ao Banco Obsidian.';
      case 'kyc_rejected':
        return 'Seu cadastro foi reprovado pelo backoffice. Entre em contato com o suporte.';
      default:
        return 'Aguardando processamento.';
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'kyc_approved':
      case 'account_active':
        return Icons.check_circle;
      case 'kyc_rejected':
        return Icons.cancel;
      case 'kyc_pending':
      case 'profile_completed':
        return Icons.hourglass_top;
      default:
        return Icons.info;
    }
  }

  Future<void> _fetchStatus() async {
    try {
      final res = await widget.customerService.getStatus(widget.cpf);
      if (!mounted) return;
      final cust = res['customer'] as Map<String, dynamic>?;
      String? status;
      Map<String, dynamic>? customerData;
      if (cust != null) {
        if (cust['customer'] is Map) {
          final inner = cust['customer'] as Map<String, dynamic>;
          status = inner['status']?.toString();
          customerData = inner;
        } else {
          status = cust['status']?.toString();
          customerData = cust;
        }
      }
      status ??= res['status']?.toString();
      const statusMap = {
        '0': 'draft',
        '1': 'profile_completed',
        '2': 'kyc_pending',
        '3': 'kyc_approved',
        '4': 'kyc_rejected',
        '5': 'account_active',
      };
      if (status != null && statusMap.containsKey(status)) status = statusMap[status]!;
      setState(() {
        _customer = customerData ?? cust;
        _status = status;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _fetchCustomer() async {
    try {
      final res = await widget.customerService.getCustomer(widget.cpf);
      if (!mounted) return;
      final cust = res['customer'] as Map<String, dynamic>?;
      if (cust != null) setState(() => _customer = cust);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _fetchStatus();
    _fetchCustomer();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_status == 'profile_completed' || _status == 'kyc_pending') _fetchStatus();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = _status ?? 'profile_completed';
    final color = _statusColor(status);
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
                const Text('Etapa 3 • Aguardando', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                  child: Row(children: [
                    Icon(_statusIcon(status), size: 14, color: color),
                    const SizedBox(width: 6),
                    Text(_statusLabel(status), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ]),
              const SizedBox(height: 8),
              // Indicador de steps 1-2-3
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _StepDot(label: 'Cadastro', done: true),
                _StepLine(done: true),
                _StepDot(label: 'Documentos', done: true),
                _StepLine(done: true),
                _StepDot(label: 'Aguardando', done: true, current: true),
              ]),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(16), border: Border.all(color: ObsidianTheme.purple.withOpacity(0.15))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.badge, color: ObsidianTheme.purple, size: 18),
                    const SizedBox(width: 8),
                    Text('CPF: ${widget.cpf}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
                  ]),
                  if (_customer != null) ...[
                    const SizedBox(height: 12),
                    const Divider(color: Colors.white10, height: 1),
                    const SizedBox(height: 12),
                    _InfoRow(label: 'Nome', value: '${_customer!['nome'] ?? ''} ${_customer!['sobrenome'] ?? ''}'),
                    if (_customer!['email'] != null && _customer!['email'].toString().isNotEmpty) _InfoRow(label: 'Email', value: _customer!['email'].toString()),
                    if (_customer!['telefone'] != null && _customer!['telefone'].toString().isNotEmpty) _InfoRow(label: 'Telefone', value: _customer!['telefone'].toString()),
                    _InfoRow(label: 'Cidade', value: '${_customer!['cidade'] ?? ''}/${_customer!['estado'] ?? ''}'),
                    _InfoRow(label: 'CEP', value: _customer!['cep']?.toString() ?? ''),
                  ] else if (_loading)
                    const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator(color: ObsidianTheme.purple)),
                ]),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.3))),
                child: Column(children: [
                  Container(width: 72, height: 72, decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle), child: Icon(_statusIcon(status), size: 40, color: color)),
                  const SizedBox(height: 16),
                  Text(_statusLabel(status), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
                  const SizedBox(height: 8),
                  Text(_statusMessage(status), style: const TextStyle(color: Colors.white70, fontSize: 13), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  if (_loading)
                    const LinearProgressIndicator(color: ObsidianTheme.purple)
                  else
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() => _loading = true);
                          _fetchStatus();
                          _fetchCustomer();
                        },
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Atualizar status'),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: const BorderSide(color: Colors.white24)),
                      ),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 11))),
                  ],
                ]),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
                child: const Row(children: [
                  Icon(Icons.info_outline, color: Colors.white54, size: 16),
                  SizedBox(width: 8),
                  Expanded(child: Text('O backoffice irá analisar e aprovar ou reprovar. Feche e abra o app novamente para atualizar.', style: TextStyle(color: Colors.white54, fontSize: 11))),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12))),
        Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
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
        decoration: BoxDecoration(
          color: current ? ObsidianTheme.purple : (done ? ObsidianTheme.purple : Colors.white12),
          shape: BoxShape.circle,
          border: Border.all(color: ObsidianTheme.purple.withOpacity(0.3)),
        ),
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
