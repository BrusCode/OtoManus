#!/bin/bash

# ===========================================
# OtoManus - Update Script
# ===========================================
# Este script atualiza o OtoManus para a última versão
# Uso: bash scripts/update.sh
# ===========================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Backup configuration
backup_config() {
    print_info "Fazendo backup das configurações..."
    
    BACKUP_DIR="$PROJECT_DIR/backups/config_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    if [ -f "$PROJECT_DIR/config/config.toml" ]; then
        cp "$PROJECT_DIR/config/config.toml" "$BACKUP_DIR/"
    fi
    
    if [ -f "$PROJECT_DIR/.env" ]; then
        cp "$PROJECT_DIR/.env" "$BACKUP_DIR/"
    fi
    
    if [ -f "$PROJECT_DIR/config/mcp.json" ]; then
        cp "$PROJECT_DIR/config/mcp.json" "$BACKUP_DIR/"
    fi
    
    print_success "Backup salvo em $BACKUP_DIR"
}

# Pull latest changes
pull_latest() {
    print_info "Baixando atualizações do GitHub..."
    
    cd "$PROJECT_DIR"
    
    if [ ! -d ".git" ]; then
        print_error "Este diretório não é um repositório Git."
        print_info "Use o script de download para obter uma nova cópia."
        exit 1
    fi
    
    # Stash local changes
    git stash
    
    # Pull latest
    git pull origin main
    
    # Try to restore stashed changes
    git stash pop 2>/dev/null || true
    
    print_success "Atualização baixada"
}

# Update dependencies
update_deps() {
    print_info "Atualizando dependências..."
    
    cd "$PROJECT_DIR"
    
    if [ -d "venv" ]; then
        source venv/bin/activate
        pip install -r requirements.txt --upgrade
        deactivate
    else
        print_warning "Ambiente virtual não encontrado. Pulando atualização de dependências."
    fi
    
    print_success "Dependências atualizadas"
}

# Rebuild Docker images if using Docker
rebuild_docker() {
    if command -v docker &> /dev/null; then
        read -p "Deseja reconstruir as imagens Docker? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Reconstruindo imagens Docker..."
            cd "$PROJECT_DIR"
            docker compose build --no-cache
            print_success "Imagens Docker reconstruídas"
        fi
    fi
}

# Main
main() {
    echo ""
    echo -e "${BLUE}OtoManus Update Script${NC}"
    echo ""
    
    backup_config
    pull_latest
    update_deps
    rebuild_docker
    
    echo ""
    print_success "Atualização concluída!"
    echo ""
    print_info "Para reiniciar a aplicação:"
    echo "  - Local: python web_run.py"
    echo "  - Docker: docker compose up -d"
    echo ""
}

main "$@"
