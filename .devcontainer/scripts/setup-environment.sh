#!/bin/bash

# Gupii Development Environment Setup
# Automatically detects and configures local vs Codespaces environment

set -e

echo "🐹 Gupii Development Environment Setup"
echo "======================================"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Environment detection
if [ "$CODESPACES" = "true" ]; then
    echo -e "${BLUE}🌐 GitHub Codespaces Environment Detected${NC}"
    echo "Setting up port-based access for code review and QA..."
    
    # Run Codespaces setup
    if [ -f "$SCRIPT_DIR/setup-codespaces.sh" ]; then
        bash "$SCRIPT_DIR/setup-codespaces.sh"
    else
        echo -e "${YELLOW}⚠️  Codespaces setup script not found, using basic configuration${NC}"
        echo "Access URLs:"
        echo "• Rails App: Use VS Code port forwarding for port 3000"
        echo "• Services: Individual port forwarding as needed"
    fi
    
elif [ "$GITHUB_ACTIONS" = "true" ]; then
    echo -e "${BLUE}🤖 GitHub Actions CI Environment Detected${NC}"
    echo "Using CI-appropriate configuration..."
    
else
    echo -e "${GREEN}💻 Local Development Environment Detected${NC}"
    echo "Setting up production-like domain configuration..."
    
    # Run local development setup
    if [ -f "$SCRIPT_DIR/setup-local-domains.sh" ]; then
        bash "$SCRIPT_DIR/setup-local-domains.sh"
    else
        echo -e "${RED}❌ Local setup script not found!${NC}"
        exit 1
    fi
fi

echo ""
echo -e "${GREEN}✅ Environment setup complete!${NC}"
echo "======================================"