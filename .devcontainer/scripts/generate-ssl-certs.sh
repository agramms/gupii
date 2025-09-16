#!/bin/bash

# SSL Certificate Generation for Gupii Development
# Creates self-signed wildcard certificate for *.gupii.local

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔒 Generating SSL Certificates for Gupii Development${NC}"
echo "===================================================="

# Get script directory and SSL directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSL_DIR="$(dirname "$SCRIPT_DIR")/ssl"

# Ensure SSL directory exists
mkdir -p "$SSL_DIR"

# Certificate configuration
CERT_NAME="gupii.local"
KEY_FILE="$SSL_DIR/$CERT_NAME.key"
CERT_FILE="$SSL_DIR/$CERT_NAME.crt"
CSR_FILE="$SSL_DIR/$CERT_NAME.csr"
CONF_FILE="$SSL_DIR/$CERT_NAME.conf"

# Check if certificates already exist and are valid
if [ -f "$CERT_FILE" ] && [ -f "$KEY_FILE" ]; then
    # Check if certificate is still valid (not expired)
    if openssl x509 -checkend 86400 -noout -in "$CERT_FILE" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Valid SSL certificates already exist${NC}"
        echo "Certificate: $CERT_FILE"
        echo "Private Key: $KEY_FILE"
        
        # Show certificate info
        echo ""
        echo -e "${BLUE}📋 Certificate Information:${NC}"
        openssl x509 -in "$CERT_FILE" -text -noout | grep -E "(Subject:|DNS:|Not After)"
        
        return 0
    else
        echo -e "${YELLOW}⚠️  Existing certificates are expired, regenerating...${NC}"
    fi
fi

echo -e "${BLUE}🔧 Generating new SSL certificates...${NC}"

# Create OpenSSL configuration file for the certificate
cat > "$CONF_FILE" << EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = v3_req

[dn]
C=BR
ST=São Paulo
L=São Paulo
O=Gupii Development
OU=Development Team
CN=gupii.local

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = gupii.local
DNS.2 = *.gupii.local
DNS.3 = grafana.gupii.local
DNS.4 = prometheus.gupii.local
DNS.5 = sonar.gupii.local
DNS.6 = pgadmin.gupii.local
DNS.7 = mail.gupii.local
DNS.8 = minio.gupii.local
DNS.9 = jaeger.gupii.local
DNS.10 = localhost
IP.1 = 127.0.0.1
IP.2 = ::1
EOF

echo "📝 OpenSSL configuration created"

# Generate private key
echo "🔑 Generating private key..."
openssl genrsa -out "$KEY_FILE" 2048

# Generate certificate signing request
echo "📄 Generating certificate signing request..."
openssl req -new -key "$KEY_FILE" -out "$CSR_FILE" -config "$CONF_FILE"

# Generate self-signed certificate
echo "🏆 Generating self-signed certificate..."
openssl x509 -req -in "$CSR_FILE" -signkey "$KEY_FILE" -out "$CERT_FILE" -days 365 -extensions v3_req -extfile "$CONF_FILE"

# Set appropriate permissions
chmod 600 "$KEY_FILE"
chmod 644 "$CERT_FILE"

# Clean up temporary files
rm "$CSR_FILE" "$CONF_FILE"

echo ""
echo -e "${GREEN}✅ SSL certificates generated successfully!${NC}"
echo "Certificate: $CERT_FILE"
echo "Private Key: $KEY_FILE"

# Display certificate information
echo ""
echo -e "${BLUE}📋 Certificate Details:${NC}"
openssl x509 -in "$CERT_FILE" -text -noout | grep -E "(Subject:|Issuer:|Not Before|Not After|DNS:|IP Address)"

echo ""
echo -e "${YELLOW}📝 Important Notes:${NC}"
echo "• These are self-signed certificates for development only"
echo "• Browsers will show security warnings - this is normal"
echo "• Click 'Advanced' → 'Proceed to site' to accept"
echo "• For teams: Consider adding the CA to trusted certificates"
echo ""

echo -e "${BLUE}🔧 To trust these certificates system-wide (optional):${NC}"
echo "macOS: sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain $CERT_FILE"
echo "Linux: sudo cp $CERT_FILE /usr/local/share/ca-certificates/ && sudo update-ca-certificates"
echo "Windows: Import $CERT_FILE to 'Trusted Root Certification Authorities'"
echo ""

echo -e "${GREEN}🚀 Ready for HTTPS development with Gupii!${NC}"