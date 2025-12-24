#!/bin/bash

# ===========================================
# OtoManus - Download Script
# ===========================================
# Este script baixa a última versão do OtoManus do GitHub
# Uso: bash download.sh [diretório_destino]
# ===========================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

REPO_URL="https://github.com/BrusCode/OtoManus"
DOWNLOAD_DIR="${1:-$HOME/OtoManus}"

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Download using git
download_with_git() {
    print_info "Baixando OtoManus usando Git..."
    
    if [ -d "$DOWNLOAD_DIR" ]; then
        print_warning "Diretório $DOWNLOAD_DIR já existe."
        print_info "Atualizando repositório existente..."
        cd "$DOWNLOAD_DIR"
        git pull origin main
    else
        git clone "$REPO_URL" "$DOWNLOAD_DIR"
    fi
    
    print_success "Download concluído em $DOWNLOAD_DIR"
}

# Download using curl (fallback)
download_with_curl() {
    print_info "Baixando OtoManus usando curl..."
    
    ARCHIVE_URL="$REPO_URL/archive/refs/heads/main.zip"
    TMP_FILE="/tmp/otomanus.zip"
    
    curl -L -o "$TMP_FILE" "$ARCHIVE_URL"
    
    if [ -d "$DOWNLOAD_DIR" ]; then
        rm -rf "$DOWNLOAD_DIR"
    fi
    
    unzip -q "$TMP_FILE" -d "/tmp"
    mv "/tmp/OtoManus-main" "$DOWNLOAD_DIR"
    rm "$TMP_FILE"
    
    print_success "Download concluído em $DOWNLOAD_DIR"
}

# Main
main() {
    echo ""
    echo -e "${BLUE}OtoManus Download Script${NC}"
    echo ""
    
    if command -v git &> /dev/null; then
        download_with_git
    elif command -v curl &> /dev/null; then
        download_with_curl
    else
        print_error "Nem Git nem curl foram encontrados. Por favor, instale um deles."
        exit 1
    fi
    
    echo ""
    print_info "Para instalar, execute:"
    echo "  cd $DOWNLOAD_DIR"
    echo "  chmod +x scripts/install.sh"
    echo "  ./scripts/install.sh"
    echo ""
}

main "$@"
