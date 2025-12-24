#!/bin/bash

# ===========================================
# OtoManus - Quick Install Script
# ===========================================
# Este script baixa e instala o OtoManus do GitHub
# Uso: curl -fsSL https://raw.githubusercontent.com/BrusCode/OtoManus/main/scripts/quick-install.sh | bash
# ===========================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_banner() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                                                           ║"
    echo "║     ██████╗ ████████╗ ██████╗ ███╗   ███╗ █████╗ ███╗   ██╗██╗   ██╗███████╗"
    echo "║    ██╔═══██╗╚══██╔══╝██╔═══██╗████╗ ████║██╔══██╗████╗  ██║██║   ██║██╔════╝"
    echo "║    ██║   ██║   ██║   ██║   ██║██╔████╔██║███████║██╔██╗ ██║██║   ██║███████╗"
    echo "║    ██║   ██║   ██║   ██║   ██║██║╚██╔╝██║██╔══██║██║╚██╗██║██║   ██║╚════██║"
    echo "║    ╚██████╔╝   ██║   ╚██████╔╝██║ ╚═╝ ██║██║  ██║██║ ╚████║╚██████╔╝███████║"
    echo "║     ╚═════╝    ╚═╝    ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚══════╝"
    echo "║                                                           ║"
    echo "║     Quick Install Script                                  ║"
    echo "║                                                           ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

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

# Check for required commands
check_requirements() {
    print_info "Verificando requisitos..."
    
    if ! command -v git &> /dev/null; then
        print_error "Git não encontrado. Por favor, instale o Git e tente novamente."
        exit 1
    fi
    print_success "Git encontrado"
    
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 não encontrado. Por favor, instale o Python 3.11+ e tente novamente."
        exit 1
    fi
    print_success "Python 3 encontrado"
}

# Clone the repository
clone_repo() {
    print_info "Clonando repositório OtoManus..."
    
    INSTALL_DIR="${INSTALL_DIR:-$HOME/OtoManus}"
    
    if [ -d "$INSTALL_DIR" ]; then
        print_warning "Diretório $INSTALL_DIR já existe."
        read -p "Deseja sobrescrever? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$INSTALL_DIR"
        else
            print_info "Instalação cancelada."
            exit 0
        fi
    fi
    
    git clone https://github.com/BrusCode/OtoManus.git "$INSTALL_DIR"
    print_success "Repositório clonado para $INSTALL_DIR"
}

# Run the main install script
run_install() {
    print_info "Executando script de instalação..."
    
    cd "$INSTALL_DIR"
    chmod +x scripts/install.sh
    ./scripts/install.sh
}

# Main
main() {
    print_banner
    check_requirements
    clone_repo
    run_install
}

main "$@"
