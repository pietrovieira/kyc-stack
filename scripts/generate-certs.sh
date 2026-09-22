#!/bin/bash
set -e
# Gera cert self-signed SAN IP para HTTPS direto no IP sem domínio
# Uso: ./scripts/generate-certs.sh [IP]
IP=${1:-191.252.204.221}
DAYS=825
CERTS_DIR="$(dirname "$0")/../certs"
mkdir -p "$CERTS_DIR"

echo ">> Gerando cert self-signed para IP $IP (SAN IP:$IP, validade ${DAYS}d) em $CERTS_DIR"

# Key + Cert com SAN IP (requerido por Chrome/Safari para IP)
openssl req -x509 -nodes -days $DAYS -newkey rsa:4096 \
  -keyout "$CERTS_DIR/privkey.pem" \
  -out "$CERTS_DIR/fullchain.pem" \
  -addext "subjectAltName=IP:$IP,DNS:$IP" \
  -subj "/C=BR/ST=SP/L=SaoPaulo/O=Banco Obsidian/CN=$IP"

# Verificar SAN
openssl x509 -in "$CERTS_DIR/fullchain.pem" -text -noout | grep -A1 "Subject Alternative Name" || true

echo ">> Cert gerado:"
echo "   $CERTS_DIR/privkey.pem"
echo "   $CERTS_DIR/fullchain.pem"
echo ">> SHA256 fingerprint:"
openssl x509 -in "$CERTS_DIR/fullchain.pem" -noout -fingerprint -sha256
echo ""
echo ">> Para VPS: scp certs/* user@$IP:/opt/kyc-stack/certs/ && docker compose restart nginx"
