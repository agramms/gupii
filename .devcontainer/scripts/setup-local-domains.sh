#!/bin/bash

# Local Development Domain Setup for Gupii
# Validates and guides setup of *.gupii.local domains with HTTPS

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}🔍 Checking Local Development Setup${NC}"
echo "-----------------------------------"

# Check if running on host or inside container
if [ -f /.dockerenv ]; then
    echo -e "${YELLOW}⚠️  Running inside container - some checks may not work as expected${NC}"
    INSIDE_CONTAINER=true
else
    INSIDE_CONTAINER=false
fi

# Define required domains
DOMAINS=(
    "gupii.local"
    "grafana.gupii.local"
    "prometheus.gupii.local"
    "sonar.gupii.local"
    "pgadmin.gupii.local"
    "mail.gupii.local"
    "minio.gupii.local"
    "jaeger.gupii.local"
)

# Check /etc/hosts entries
echo "📋 Checking /etc/hosts configuration..."

HOSTS_FILE="/etc/hosts"
MISSING_DOMAINS=()

for domain in "${DOMAINS[@]}"; do
    if ! grep -q "$domain" "$HOSTS_FILE" 2>/dev/null; then
        MISSING_DOMAINS+=("$domain")
    fi
done

if [ ${#MISSING_DOMAINS[@]} -gt 0 ]; then
    echo -e "${RED}❌ Missing /etc/hosts entries${NC}"
    echo ""
    echo -e "${YELLOW}📝 Required /etc/hosts configuration:${NC}"
    echo "127.0.0.1 ${DOMAINS[*]}"
    echo ""
    echo -e "${GREEN}🔧 Quick setup options:${NC}"
    echo ""
    echo "Option 1 - Automatic (requires sudo):"
    echo "  sudo bash $SCRIPT_DIR/add-hosts-entries.sh"
    echo ""
    echo "Option 2 - Manual:"
    echo "  sudo nano /etc/hosts"
    echo "  Add this line: 127.0.0.1 ${DOMAINS[*]}"
    echo ""
    echo -e "${RED}⚠️  Please configure /etc/hosts before starting the development environment${NC}"
    
    # Offer to run the automatic setup
    if [ "$INSIDE_CONTAINER" = false ] && command -v sudo >/dev/null 2>&1; then
        echo ""
        read -p "Would you like to automatically add the entries? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            bash "$SCRIPT_DIR/add-hosts-entries.sh"
        else
            echo -e "${YELLOW}Manual setup required before proceeding${NC}"
            exit 1
        fi
    else
        exit 1
    fi
else
    echo -e "${GREEN}✅ /etc/hosts configuration is correct${NC}"
fi

# Check DNS resolution
echo ""
echo "🌐 Verifying DNS resolution..."
RESOLUTION_ISSUES=()

for domain in "${DOMAINS[@]}"; do
    if ! nslookup "$domain" >/dev/null 2>&1 && ! host "$domain" >/dev/null 2>&1; then
        # Try ping as fallback
        if ! ping -c 1 -W 1 "$domain" >/dev/null 2>&1; then
            RESOLUTION_ISSUES+=("$domain")
        fi
    fi
done

if [ ${#RESOLUTION_ISSUES[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Some domains may not resolve properly: ${RESOLUTION_ISSUES[*]}${NC}"
    echo "This might be normal in some environments. Testing with curl..."
else
    echo -e "${GREEN}✅ DNS resolution working${NC}"
fi

# Generate SSL certificates
echo ""
echo "🔒 Setting up SSL certificates..."
if [ -f "$SCRIPT_DIR/generate-ssl-certs.sh" ]; then
    bash "$SCRIPT_DIR/generate-ssl-certs.sh"
else
    echo -e "${YELLOW}⚠️  SSL certificate generation script not found${NC}"
    echo "SSL certificates will be generated during nginx startup"
fi

# Display access information
echo ""
echo -e "${GREEN}🚀 Local Development Environment Ready!${NC}"
echo "======================================"
echo ""
echo -e "${BLUE}🌐 Access URLs (HTTPS):${NC}"
echo "• Main Application: https://gupii.local"
echo "• Grafana Dashboards: https://grafana.gupii.local (admin/admin123)"
echo "• Prometheus Metrics: https://prometheus.gupii.local"
echo "• SonarQube Quality: https://sonar.gupii.local (admin/admin)"
echo "• PostgreSQL Admin: https://pgadmin.gupii.local (admin@gupii.dev/admin123)"
echo "• Email Testing: https://mail.gupii.local"
echo "• S3 Storage Console: https://minio.gupii.local (minioadmin/minioadmin123)"
echo "• Distributed Tracing: https://jaeger.gupii.local"
echo ""
echo -e "${YELLOW}📝 Note: Accept SSL certificate warnings in browser (self-signed for development)${NC}"
echo ""