import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'hmac_service.dart';

class CustomerService {
  final http.Client _client;
  CustomerService({http.Client? client}) : _client = client ?? http.Client();

  // Etapa 1: cadastro perfil + endereço (idempotente por CPF)
  Future<Map<String, dynamic>> createProfile({
    required String cpf,
    required String nome,
    required String sobrenome,
    required String dataNascimento, // YYYY-MM-DD
    String? email,
    String? telefone,
    required String logradouro,
    required String numero,
    String? complemento,
    required String bairro,
    required String cidade,
    required String estado,
    required String cep,
    String? pais,
  }) async {
    final body = jsonEncode({
      'customer': {
        'cpf': cpf,
        'nome': nome,
        'sobrenome': sobrenome,
        'data_nascimento': dataNascimento,
        'email': email,
        'telefone': telefone,
        'logradouro': logradouro,
        'numero': numero,
        'complemento': complemento,
        'bairro': bairro,
        'cidade': cidade,
        'estado': estado,
        'cep': cep,
        'pais': pais ?? 'Brasil',
      }
    });
    final path = '/api/v1/customers';
    final headers = HmacService.signedHeaders(method: 'POST', path: path, body: body);
    final res = await _client.post(
      Uri.parse(AppConfig.v1Customers),
      headers: headers,
      body: body,
    );
    // Detecção de HTML (ex: 404 de outro serviço na porta errada)
    if (res.body.trimLeft().startsWith('<!DOCTYPE') || res.body.trimLeft().startsWith('<html')) {
      throw Exception(
        'Backend retornou HTML em vez de JSON (${res.statusCode}). '
        'Verifique BACKEND_URL=${AppConfig.backendBaseUrl} — esperado http://localhost:3002 (kyc-go). '
        'Porta 3000 colide com outro projeto. Reinicie o app com --dart-define=BACKEND_URL=http://localhost:3002',
      );
    }
    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Resposta inválida do servidor (${res.statusCode}): ${res.body.substring(0, res.body.length > 300 ? 300 : res.body.length)}');
    }
    if (res.statusCode >= 400 && res.statusCode != 409) {
      throw Exception(json['error'] ?? json['message'] ?? 'Erro ao criar perfil (${res.statusCode})');
    }
    return json;
  }

  Future<Map<String, dynamic>> getCustomer(String cpf) async {
    final path = '/api/v1/customers/$cpf';
    final headers = HmacService.signedHeaders(method: 'GET', path: path, body: '');
    final res = await _client.get(Uri.parse(AppConfig.v1Customer(cpf)), headers: headers);
    if (res.body.trimLeft().startsWith('<!DOCTYPE')) {
      throw Exception('Backend HTML em ${AppConfig.v1Customer(cpf)} — porta incorreta?');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getStatus(String cpf) async {
    final path = '/api/v1/customers/$cpf/status';
    final headers = HmacService.signedHeaders(method: 'GET', path: path, body: '');
    final res = await _client.get(Uri.parse(AppConfig.v1CustomerStatus(cpf)), headers: headers);
    if (res.body.trimLeft().startsWith('<!DOCTYPE')) {
      throw Exception('Backend HTML em ${AppConfig.v1CustomerStatus(cpf)} — porta incorreta?');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // Etapa 2: KYC documentos + selfie (requestBlob FaceTec) - async via Redis
  Future<Map<String, dynamic>> submitKyc({
    required String cpf,
    required String requestBlob,
    String documentType = 'rg',
  }) async {
    final body = jsonEncode({
      'requestBlob': requestBlob,
      'documentType': documentType,
    });
    final path = '/api/v1/customers/$cpf/kyc';
    final headers = HmacService.signedHeaders(method: 'POST', path: path, body: body);
    final res = await _client.post(
      Uri.parse(AppConfig.v1CustomerKyc(cpf)),
      headers: headers,
      body: body,
    );
    if (res.body.trimLeft().startsWith('<!DOCTYPE')) {
      throw Exception('Backend HTML em KYC — verifique BACKEND_URL');
    }
    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Resposta KYC inválida (${res.statusCode}): ${res.body.substring(0, 200)}');
    }
    if (res.statusCode >= 400) throw Exception(json['error'] ?? 'Erro KYC');
    return json;
  }

  void dispose() => _client.close();
}
