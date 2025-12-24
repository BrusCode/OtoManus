#!/bin/bash

# ===========================================
# Otomanus - Service Management Script
# ===========================================
# Usage: bash scripts/manage.sh [command]
# Commands: start, stop, restart, status, logs, backup, restore, update
# ===========================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

COMMAND=${1:-help}

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
cd "$PROJECT_DIR"

# Start services
cmd_start() {
    print_info "Starting Otomanus services..."
    docker compose up -d
    print_success "Services started"
    cmd_status
}

# Stop services
cmd_stop() {
    print_info "Stopping Otomanus services..."
    docker compose down
    print_success "Services stopped"
}

# Restart services
cmd_restart() {
    print_info "Restarting Otomanus services..."
    docker compose restart
    print_success "Services restarted"
    cmd_status
}

# Show service status
cmd_status() {
    print_info "Service Status:"
    echo ""
    docker compose ps
    echo ""
    
    # Health check
    if curl -sf http://localhost:${APP_PORT:-8000}/api/health > /dev/null 2>&1; then
        print_success "Application is healthy"
    else
        print_warning "Application may not be ready yet"
    fi
}

# Show logs
cmd_logs() {
    SERVICE=${2:-}
    if [ -n "$SERVICE" ]; then
        docker compose logs -f "$SERVICE"
    else
        docker compose logs -f
    fi
}

# Create backup
cmd_backup() {
    print_info "Creating backup..."
    
    BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # Backup database
    if docker compose ps postgres | grep -q "Up"; then
        print_info "Backing up database..."
        docker compose exec -T postgres pg_dump -U ${POSTGRES_USER:-otomanus} ${POSTGRES_DB:-otomanus} > "$BACKUP_DIR/database.sql"
    fi
    
    # Backup config
    cp -r config "$BACKUP_DIR/" 2>/dev/null || true
    
    # Backup sessions
    cp -r sessions "$BACKUP_DIR/" 2>/dev/null || true
    
    # Backup workspace
    cp -r workspace "$BACKUP_DIR/" 2>/dev/null || true
    
    print_success "Backup created at $BACKUP_DIR"
}

# Restore from backup
cmd_restore() {
    BACKUP_PATH=${2:-}
    
    if [ -z "$BACKUP_PATH" ]; then
        print_info "Available backups:"
        ls -la backups/ 2>/dev/null || echo "No backups found"
        echo ""
        read -p "Enter backup directory name: " BACKUP_PATH
        BACKUP_PATH="backups/$BACKUP_PATH"
    fi
    
    if [ ! -d "$BACKUP_PATH" ]; then
        print_error "Backup directory not found: $BACKUP_PATH"
        exit 1
    fi
    
    print_warning "This will overwrite current data!"
    read -p "Are you sure? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Restore cancelled"
        exit 0
    fi
    
    print_info "Restoring from $BACKUP_PATH..."
    
    # Restore database
    if [ -f "$BACKUP_PATH/database.sql" ]; then
        print_info "Restoring database..."
        docker compose exec -T postgres psql -U ${POSTGRES_USER:-otomanus} ${POSTGRES_DB:-otomanus} < "$BACKUP_PATH/database.sql"
    fi
    
    # Restore config
    if [ -d "$BACKUP_PATH/config" ]; then
        cp -r "$BACKUP_PATH/config/"* config/
    fi
    
    # Restore sessions
    if [ -d "$BACKUP_PATH/sessions" ]; then
        cp -r "$BACKUP_PATH/sessions/"* sessions/
    fi
    
    print_success "Restore complete"
}

# Update application
cmd_update() {
    print_info "Updating Otomanus..."
    
    # Pull latest changes
    if [ -d ".git" ]; then
        git pull origin main
    fi
    
    # Rebuild and restart
    docker compose build
    docker compose up -d
    
    print_success "Update complete"
    cmd_status
}

# Shell into container
cmd_shell() {
    SERVICE=${2:-otomanus}
    print_info "Opening shell in $SERVICE container..."
    docker compose exec "$SERVICE" /bin/bash
}

# Database shell
cmd_db() {
    print_info "Opening database shell..."
    docker compose exec postgres psql -U ${POSTGRES_USER:-otomanus} ${POSTGRES_DB:-otomanus}
}

# Redis CLI
cmd_redis() {
    print_info "Opening Redis CLI..."
    docker compose exec redis redis-cli
}

# Clean up resources
cmd_cleanup() {
    print_info "Cleaning up resources..."
    
    # Remove stopped containers
    docker compose rm -f
    
    # Remove unused images
    docker image prune -f
    
    # Remove unused volumes (careful!)
    read -p "Remove unused volumes? This may delete data! [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker volume prune -f
    fi
    
    print_success "Cleanup complete"
}

# Show help
cmd_help() {
    echo ""
    echo -e "${BLUE}Otomanus Management Script${NC}"
    echo ""
    echo "Usage: bash scripts/manage.sh [command]"
    echo ""
    echo "Commands:"
    echo "  start       Start all services"
    echo "  stop        Stop all services"
    echo "  restart     Restart all services"
    echo "  status      Show service status"
    echo "  logs [svc]  Show logs (optionally for specific service)"
    echo "  backup      Create a backup"
    echo "  restore     Restore from backup"
    echo "  update      Update and restart services"
    echo "  shell [svc] Open shell in container (default: otomanus)"
    echo "  db          Open database shell"
    echo "  redis       Open Redis CLI"
    echo "  cleanup     Clean up unused resources"
    echo "  help        Show this help message"
    echo ""
}

# Main
case $COMMAND in
    start)
        cmd_start
        ;;
    stop)
        cmd_stop
        ;;
    restart)
        cmd_restart
        ;;
    status)
        cmd_status
        ;;
    logs)
        cmd_logs "$@"
        ;;
    backup)
        cmd_backup
        ;;
    restore)
        cmd_restore "$@"
        ;;
    update)
        cmd_update
        ;;
    shell)
        cmd_shell "$@"
        ;;
    db)
        cmd_db
        ;;
    redis)
        cmd_redis
        ;;
    cleanup)
        cmd_cleanup
        ;;
    help|*)
        cmd_help
        ;;
esac
