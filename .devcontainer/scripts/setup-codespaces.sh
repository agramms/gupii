#!/bin/bash

# GitHub Codespaces Environment Setup for Gupii
# Configures simple port-based access for code review and QA

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🌐 Setting up GitHub Codespaces Environment${NC}"
echo "============================================="

# Get Codespace URL if available
if [ -n "$CODESPACE_NAME" ]; then
    CODESPACE_URL="https://${CODESPACE_NAME}-3000.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"
    echo -e "${GREEN}📍 Codespace detected: $CODESPACE_NAME${NC}"
else
    CODESPACE_URL="[Use VS Code port forwarding]"
    echo -e "${YELLOW}⚠️  Codespace URL not detected, using manual port forwarding${NC}"
fi

echo ""
echo -e "${BLUE}🔧 Configuring services for Codespaces...${NC}"

# Create simple environment file for Codespaces
cat > /tmp/codespaces-env << EOF
# Codespaces Environment Configuration
export CODESPACES_MODE=true
export RAILS_ENV=development
export DISABLE_SSL_VERIFY=true
export FORCE_SSL=false
EOF

echo -e "${GREEN}✅ Codespaces configuration ready${NC}"

echo ""
echo -e "${GREEN}🚀 Codespaces Access Information${NC}"
echo "================================="
echo ""
echo -e "${BLUE}📱 Service Access (Port Forwarding):${NC}"
echo "• Rails Application: $CODESPACE_URL"

if [ -n "$CODESPACE_NAME" ]; then
    echo "• Grafana: https://${CODESPACE_NAME}-3001.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"
    echo "• Prometheus: https://${CODESPACE_NAME}-9090.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"
    echo "• pgAdmin: https://${CODESPACE_NAME}-5050.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"
    echo "• MailHog: https://${CODESPACE_NAME}-8025.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"
    echo "• MinIO: https://${CODESPACE_NAME}-9002.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"
    echo "• Jaeger: https://${CODESPACE_NAME}-16686.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"
else
    echo "• Grafana: Use VS Code to forward port 3001"
    echo "• Prometheus: Use VS Code to forward port 9090"
    echo "• pgAdmin: Use VS Code to forward port 5050"
    echo "• MailHog: Use VS Code to forward port 8025"
    echo "• MinIO: Use VS Code to forward port 9002"
    echo "• Jaeger: Use VS Code to forward port 16686"
fi

echo ""
echo -e "${YELLOW}📝 Default Credentials:${NC}"
echo "• Grafana: admin / admin123"
echo "• pgAdmin: admin@gupii.dev / admin123"
echo "• MinIO: minioadmin / minioadmin123"
echo ""

echo -e "${BLUE}💡 Codespaces Tips:${NC}"
echo "• Use the VS Code Ports tab to manage port forwarding"
echo "• Set ports to 'Public' for external access (QA/demo)"
echo "• Use 'Private' for secure development work"
echo "• Codespaces automatically handles HTTPS for forwarded ports"
echo ""

echo -e "${GREEN}✅ Codespaces setup complete!${NC}"
echo "Perfect for code review, QA testing, and demonstrations."
echo ""