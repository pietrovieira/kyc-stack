import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../config/app_config.dart';

class HmacService {
  static Map<String, String> signedHeaders({
    required String method,
    required String path,
    required String body,
    String? nonceOverride,
  }) {
    final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final nonce = nonceOverride ?? _uuid();
    final bodyHash = sha256.convert(utf8.encode(body)).toString();
    final canonical = [timestamp, nonce, method.toUpperCase(), path, bodyHash].join('\n');
    final hmac = Hmac(sha256, utf8.encode(AppConfig.hmacSecret));
    final signature = hmac.convert(utf8.encode(canonical)).toString();

    return {
      'X-API-Key': AppConfig.hmacKeyId,
      'X-Timestamp': timestamp,
      'X-Nonce': nonce,
      'X-Signature': signature,
      'Content-Type': 'application/json',
      'Idempotency-Key': _uuid(),
    };
  }

  /// Assina headers para corpo binário (ex: multipart). O hash é calculado
  /// diretamente sobre os bytes enviados, sem conversão UTF-8 destrutiva.
  static Map<String, String> signedBytesHeaders({
    required String method,
    required String path,
    required List<int> body,
    required String contentType,
    String? nonceOverride,
  }) {
    final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final nonce = nonceOverride ?? _uuid();
    final bodyHash = sha256.convert(body).toString();
    final canonical = [timestamp, nonce, method.toUpperCase(), path, bodyHash].join('\n');
    final hmac = Hmac(sha256, utf8.encode(AppConfig.hmacSecret));
    final signature = hmac.convert(utf8.encode(canonical)).toString();

    return {
      'X-API-Key': AppConfig.hmacKeyId,
      'X-Timestamp': timestamp,
      'X-Nonce': nonce,
      'X-Signature': signature,
      'Content-Type': contentType,
      'Idempotency-Key': _uuid(),
    };
  }

  static String _uuid() {
    final now = DateTime.now().microsecondsSinceEpoch.toString();
    final rnd = (now.hashCode ^ DateTime.now().millisecond).toString();
    return '${now.substring(0, 8)}-${now.substring(8, 12)}-4${rnd.substring(0, 3)}-a${rnd.substring(3, 6)}-${now.substring(0, 12)}';
  }
}
