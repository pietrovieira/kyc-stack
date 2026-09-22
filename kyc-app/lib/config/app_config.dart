// Banco Obsidian - Config
// Backend Go em http://localhost:3002 (docker, host) ou http://10.0.2.2:3002 (emulador Android)
// Correção: porta 3002 (antes era 3000 que colide com fullstack-developer). Use --dart-define=BACKEND_URL para override.

class AppConfig {
  static const String backendBaseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://localhost:3002',
  );

  static const String bankName = 'Banco Obsidian';
  static const String bankTagline = 'Seu futuro em roxo e preto';

  // Endpoints legados (FaceTec direto)
  static const String facetecConfigEndpoint = '$backendBaseUrl/api/facetec/config';
  static const String facetecProcessEndpoint = '$backendBaseUrl/api/facetec/process';
  static const String facetecStatusEndpoint = '$backendBaseUrl/api/facetec/status';

  // Novos endpoints api/v1 com HMAC + idempotência
  static const String v1Customers = '$backendBaseUrl/api/v1/customers';
  static String v1Customer(String cpf) => '$backendBaseUrl/api/v1/customers/$cpf';
  static String v1CustomerKyc(String cpf) => '$backendBaseUrl/api/v1/customers/$cpf/kyc';
  static String v1CustomerStatus(String cpf) => '$backendBaseUrl/api/v1/customers/$cpf/status';
  static String v1CustomerDocuments(String cpf) => '$backendBaseUrl/api/v1/customers/$cpf/documents';
  static String v1Cep(String cep) => '$backendBaseUrl/api/v1/cep/$cep';

  // HMAC - em prod viria de secure storage / env
  static const String hmacKeyId = String.fromEnvironment('HMAC_KEY_ID', defaultValue: 'obsidian_app');
  static const String hmacSecret = String.fromEnvironment('HMAC_SECRET', defaultValue: 'obsidian_hmac_secret_2026_change_me_32bytes!');
}
