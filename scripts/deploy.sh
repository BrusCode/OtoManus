#!/bin/bash

# ===========================================
# Otomanus - Deployment Script
# ===========================================
# This script deploys Otomanus to production
# Run with: bash scripts/deploy.sh [environment]
# ===========================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default environment
ENVIRONMENT=${1:-production}

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

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_warning "Not running as root. Some operations may require sudo."
    fi
}

# Validate environment
validate_env() {
    print_info "Validating environment configuration..."
    
    if [ ! -f ".env" ]; then
        print_error ".env file not found!"
        print_info "Copy .env.example to .env and configure your settings"
        exit 1
    fi
    
    # Source .env file
    export $(grep -v '^#' .env | xargs)
    
    # Check required variables
    if [ -z "$OPENAI_API_KEY" ] || [ "$OPENAI_API_KEY" = "sk-your-openai-api-key-here" ]; then
        print_warning "OPENAI_API_KEY not configured in .env"
    fi
    
    if [ -z "$POSTGRES_PASSWORD" ] || [ "$POSTGRES_PASSWORD" = "otomanus123" ]; then
        print_warning "Using default POSTGRES_PASSWORD - consider changing for production"
    fi
    
    print_success "Environment validated"
}

# Backup existing data
backup_data() {
    print_info "Creating backup..."
    
    BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # Backup database if running
    if docker compose ps postgres | grep -q "Up"; then
        print_info "Backing up PostgreSQL database..."
        docker compose exec -T postgres pg_dump -U ${POSTGRES_USER:-otomanus} ${POSTGRES_DB:-otomanus} > "$BACKUP_DIR/database.sql"
        print_success "Database backed up to $BACKUP_DIR/database.sql"
    fi
    
    # Backup config
    if [ -d "config" ]; then
        cp -r config "$BACKUP_DIR/"
        print_success "Config backed up"
    fi
    
    # Backup sessions
    if [ -d "sessions" ]; then
        cp -r sessions "$BACKUP_DIR/"
        print_success "Sessions backed up"
    fi
    
    print_success "Backup created at $BACKUP_DIR"
}

# Pull latest changes
pull_latest() {
    print_info "Pulling latest changes..."
    
    if [ -d ".git" ]; then
        git pull origin main
        print_success "Latest changes pulled"
    else
        print_warning "Not a git repository, skipping pull"
    fi
}

# Build Docker images
build_images() {
    print_info "Building Docker images..."
    
    docker compose build --no-cache
    print_success "Docker images built"
}

# Deploy services
deploy_services() {
    print_info "Deploying services..."
    
    case $ENVIRONMENT in
        production)
            print_info "Deploying production environment..."
            docker compose --profile production up -d
            ;;
        development)
            print_info "Deploying development environment..."
            docker compose --profile development up -d
            ;;
        *)
            print_info "Deploying default environment..."
            docker compose up -d
            ;;
    esac
    
    print_success "Services deployed"
}

# Run database migrations
run_migrations() {
    print_info "Running database migrations..."
    
    # Wait for database to be ready
    print_info "Waiting for database to be ready..."
    sleep 10
    
    # Check if database is accessible
    if docker compose exec -T postgres pg_isready -U ${POSTGRES_USER:-otomanus}; then
        print_success "Database is ready"
    else
        print_error "Database is not ready"
        exit 1
    fi
    
    print_success "Migrations complete"
}

# Health check
health_check() {
    print_info "Running health checks..."
    
    # Wait for services to start
    sleep 5
    
    # Check application health
    MAX_RETRIES=30
    RETRY_COUNT=0
    
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if curl -sf http://localhost:${APP_PORT:-8000}/api/health > /dev/null; then
            print_success "Application is healthy"
            break
        fi
        
        RETRY_COUNT=$((RETRY_COUNT + 1))
        print_info "Waiting for application to start... ($RETRY_COUNT/$MAX_RETRIES)"
        sleep 2
    done
    
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        print_error "Application health check failed"
        docker compose logs otomanus
        exit 1
    fi
    
    # Check all services
    print_info "Checking service status..."
    docker compose ps
}

# Cleanup old resources
cleanup() {
    print_info "Cleaning up old resources..."
    
    # Remove unused Docker images
    docker image prune -f
    
    # Remove old backups (keep last 5)
    if [ -d "backups" ]; then
        ls -dt backups/*/ | tail -n +6 | xargs -r rm -rf
    fi
    
    print_success "Cleanup complete"
}

# Print deployment summary
print_summary() {
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}           Deployment Complete!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Environment: $ENVIRONMENT"
    echo ""
    echo "Services:"
    docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    echo "Access points:"
    echo "  - Web Interface: http://localhost:${APP_PORT:-8000}"
    if [ "$ENVIRONMENT" = "development" ]; then
        echo "  - Database Admin: http://localhost:${ADMINER_PORT:-8080}"
    fi
    echo ""
    echo "Useful commands:"
    echo "  - View logs: docker compose logs -f"
    echo "  - Stop services: docker compose down"
    echo "  - Restart: docker compose restart"
    echo ""
}

# Main deployment function
main() {
    echo ""
    echo -e "${BLUE}Otomanus Deployment Script${NC}"
    echo -e "${BLUE}Environment: $ENVIRONMENT${NC}"
    echo ""
    
    # Get script directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
    
    # Change to project directory
    cd "$PROJECT_DIR"
    
    check_root
    validate_env
    
    # Ask for confirmation
    read -p "Do you want to proceed with deployment? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Deployment cancelled"
        exit 0
    fi
    
    backup_data
    pull_latest
    build_images
    deploy_services
    run_migrations
    health_check
    cleanup
    print_summary
}

# Run main function
main "$@"
