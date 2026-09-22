import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'hmac_service.dart';

/// FaceTecService - integra o Device SDK (Flutter) com o kyc-backend (Rails proxy)
/// https://dev.facetec.com/getting-started
/// https://dev.facetec.com/api-guide
///
/// Fluxo:
/// 1. App chama GET /api/facetec/config para obter deviceKeyIdentifier + publicKey
/// 2. App inicializa FaceTecSDK: initializeInDevelopmentMode(deviceKey, publicKey, callback)
/// 3. Usuário faz 3D FaceScan -> Device SDK gera requestBlob (Base64)
/// 4. App chama POST /api/facetec/process {requestBlob, externalDatabaseRefID, sessionType}
/// 5. Rails proxy encaminha para FaceTec Server SDK POST /process-request
/// 6. Resultado: livenessProven, matchLevel, documentData, success
///
/// Este arquivo NÃO depende do plugin nativo diretamente para permitir build sem SDK.
/// Quando o plugin facetec_sdk estiver instalado, substitua os TODOs abaixo.
class FacetecService {
  final http.Client _client;

  FacetecService({http.Client? client}) : _client = client ?? http.Client();

  /// Busca config pública para inicializar o Device SDK
  /// O Device SDK precisa de deviceKeyIdentifier + publicFaceScanEncryptionKey
  Future<FacetecConfig> fetchConfig() async {
    final uri = Uri.parse(AppConfig.facetecConfigEndpoint);
    final headers = HmacService.signedHeaders(method: 'GET', path: uri.path, body: '');
    final resp = await _client.get(uri, headers: headers);
    if (resp.statusCode != 200) {
      throw Exception('Falha ao buscar FaceTec config: ${resp.statusCode} ${resp.body}');
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    return FacetecConfig.fromJson(json);
  }

  /// Healthcheck - valida Step 3 do Getting Started (Server SDK rodando)
  Future<bool> isServerRunning() async {
    try {
      final uri = Uri.parse(AppConfig.facetecStatusEndpoint);
      final headers = HmacService.signedHeaders(method: 'GET', path: uri.path, body: '');
      final resp = await _client.get(uri, headers: headers);
      if (resp.statusCode != 200) return false;
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      return json['success'] == true && json['running'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Envia o requestBlob gerado pelo Device SDK para o backend
  /// sessionType: liveness | enrollment | verification | photo_id_match | id_scan_only
  Future<FacetecResult> processRequest({
    required String requestBlob,
    String? externalDatabaseRefID,
    String sessionType = 'liveness', // default: 3D Liveness
  }) async {
    final body = <String, dynamic>{
      'requestBlob': requestBlob,
      if (externalDatabaseRefID != null) 'externalDatabaseRefID': externalDatabaseRefID,
      'sessionType': sessionType,
    };

    final uri = Uri.parse(AppConfig.facetecProcessEndpoint);
    final bodyStr = jsonEncode(body);
    final hmacHeaders = HmacService.signedHeaders(method: 'POST', path: uri.path, body: bodyStr);
    final resp = await _client.post(
      uri,
      headers: {...hmacHeaders, 'Content-Type': 'application/json'},
      body: bodyStr,
    );

    final json = jsonDecode(resp.body) as Map<String, dynamic>;

    // O backend retorna {kycSessionId, facetec: {...}, livenessProven, success}
    // Mesmo em 422 (falha de liveness), o JSON vem com success:false
    return FacetecResult.fromJson(json);
  }

  // TODO: picks abaixo quando instalar o plugin nativo:

  /// Inicializa o FaceTec SDK no device
  /// ```dart
  /// import 'package:facetec_sdk/facetec_sdk.dart';
  /// await FaceTecSDK.initializeInDevelopmentMode(
  ///   config.deviceKeyIdentifier,
  ///   config.publicFaceScanEncryptionKey,
  /// );
  /// ```
  Future<void> initializeSdk(FacetecConfig config) async {
    // Placeholder - sem plugin, apenas valida config
    if (config.deviceKeyIdentifier.contains('placeholder')) {
      throw Exception(
        'Configure FACETEC_DEVICE_KEY_IDENTIFIER no backend (.env) - veja dev.facetec.com/getting-started',
      );
    }
    // Quando plugin instalado:
    // await FaceTecSDK.initializeInDevelopmentMode(
    //   config.deviceKeyIdentifier,
    //   config.publicFaceScanEncryptionKey,
    // );
    await Future.delayed(const Duration(milliseconds: 100));
  }

  /// Inicia uma sessão FaceTec e retorna o requestBlob
  /// Substitua este mock pelo processor real do Device SDK:
  /// ```dart
  /// final processor = FaceTecFaceScanProcessor(sessionToken, externalDatabaseRefID);
  /// FaceTecSession(processor, sessionToken);
  /// // processor.onFaceScanResult -> requestBlob
  /// ```
  Future<String> startLivenessSession({String? externalDatabaseRefID}) async {
    // MOCK para desenvolvimento sem SDK nativo
    // Em prod, este método é o callback do FaceTecFaceScanProcessor / FaceTecIDScanProcessor
    throw UnimplementedError(
      'Instale o FaceTec Device SDK (facetec_sdk) e implemente FaceTecSession. '
      'Veja lib/services/facetec_service.dart:initializeSdk TODO e docs em dev.facetec.com/getting-started#additional-run-steps',
    );
  }

  void dispose() => _client.close();
}

class FacetecConfig {
  final String deviceKeyIdentifier;
  final String publicFaceScanEncryptionKey;
  final String serverUrl;
  final String environment;

  FacetecConfig({
    required this.deviceKeyIdentifier,
    required this.publicFaceScanEncryptionKey,
    required this.serverUrl,
    required this.environment,
  });

  factory FacetecConfig.fromJson(Map<String, dynamic> json) => FacetecConfig(
        deviceKeyIdentifier: json['deviceKeyIdentifier'] as String? ?? '',
        publicFaceScanEncryptionKey: json['publicFaceScanEncryptionKey'] as String? ?? '',
        serverUrl: json['serverUrl'] as String? ?? '',
        environment: json['environment'] as String? ?? '',
      );
}

class FacetecResult {
  final int? kycSessionId;
  final String? externalDatabaseRefID;
  final String? sessionType;
  final String? status;
  final bool? livenessProven;
  final bool? success;
  final int? matchLevel;
  final dynamic documentData;
  final Map<String, dynamic>? facetec;
  final String? error;

  FacetecResult({
    this.kycSessionId,
    this.externalDatabaseRefID,
    this.sessionType,
    this.status,
    this.livenessProven,
    this.success,
    this.matchLevel,
    this.documentData,
    this.facetec,
    this.error,
  });

  factory FacetecResult.fromJson(Map<String, dynamic> json) => FacetecResult(
        kycSessionId: json['kycSessionId'] as int?,
        externalDatabaseRefID: json['externalDatabaseRefID'] as String?,
        sessionType: json['sessionType'] as String?,
        status: json['status'] as String?,
        livenessProven: json['livenessProven'] as bool? ?? json['facetec']?['livenessProven'] as bool?,
        success: json['success'] as bool? ?? json['facetec']?['success'] as bool?,
        matchLevel: json['matchLevel'] as int? ?? json['facetec']?['matchLevel'] as int?,
        documentData: json['documentData'] ?? json['facetec']?['documentData'],
        facetec: json['facetec'] as Map<String, dynamic>?,
        error: json['error'] as String?,
      );

  bool get isSuccess => success == true && livenessProven == true;
}
