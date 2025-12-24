#!/bin/bash

# ===========================================
# Otomanus - Installation Script
# ===========================================
# This script installs and configures Otomanus
# Run with: bash scripts/install.sh
# ===========================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print banner
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
    echo "║     Installation Script v1.0.0                            ║"
    echo "║                                                           ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Print colored message
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

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check system requirements
check_requirements() {
    print_info "Checking system requirements..."
    
    # Check Python
    if command_exists python3; then
        PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2)
        print_success "Python $PYTHON_VERSION found"
    else
        print_error "Python 3 is required but not installed"
        exit 1
    fi
    
    # Check pip
    if command_exists pip3; then
        print_success "pip3 found"
    else
        print_error "pip3 is required but not installed"
        exit 1
    fi
    
    # Check Docker (optional)
    if command_exists docker; then
        DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | tr -d ',')
        print_success "Docker $DOCKER_VERSION found"
        DOCKER_AVAILABLE=true
    else
        print_warning "Docker not found - Docker installation will be skipped"
        DOCKER_AVAILABLE=false
    fi
    
    # Check Docker Compose (optional)
    if command_exists docker-compose || docker compose version >/dev/null 2>&1; then
        print_success "Docker Compose found"
        COMPOSE_AVAILABLE=true
    else
        print_warning "Docker Compose not found"
        COMPOSE_AVAILABLE=false
    fi
}

# Create virtual environment
setup_venv() {
    print_info "Setting up Python virtual environment..."
    
    if [ ! -d "venv" ]; then
        python3 -m venv venv
        print_success "Virtual environment created"
    else
        print_info "Virtual environment already exists"
    fi
    
    # Activate virtual environment
    source venv/bin/activate
    
    # Upgrade pip
    pip install --upgrade pip
    print_success "pip upgraded"
}

# Install Python dependencies
install_dependencies() {
    print_info "Installing Python dependencies..."
    
    pip install -r requirements.txt
    print_success "Python dependencies installed"
    
    # Install Playwright browsers
    print_info "Installing Playwright browsers..."
    playwright install chromium
    print_success "Playwright browsers installed"
}

# Create necessary directories
create_directories() {
    print_info "Creating necessary directories..."
    
    mkdir -p config
    mkdir -p workspace
    mkdir -p logs
    mkdir -p sessions
    
    print_success "Directories created"
}

# Setup configuration files
setup_config() {
    print_info "Setting up configuration files..."
    
    # Copy example config if not exists
    if [ ! -f "config/config.toml" ]; then
        if [ -f "config/config.example.toml" ]; then
            cp config/config.example.toml config/config.toml
            print_success "config.toml created from example"
        else
            print_warning "config.example.toml not found, creating default config"
            cat > config/config.toml << 'EOF'
# Otomanus Configuration

[llm]
model = "gpt-4o"
base_url = "https://api.openai.com/v1"
api_key = ""
max_tokens = 4096
temperature = 0.0

[browser]
headless = false
disable_security = true

[search]
engine = "Google"
EOF
            print_success "Default config.toml created"
        fi
    else
        print_info "config.toml already exists"
    fi
    
    # Copy example .env if not exists
    if [ ! -f ".env" ]; then
        if [ -f ".env.example" ]; then
            cp .env.example .env
            print_success ".env created from example"
        fi
    else
        print_info ".env already exists"
    fi
}

# Setup Docker environment
setup_docker() {
    if [ "$DOCKER_AVAILABLE" = true ] && [ "$COMPOSE_AVAILABLE" = true ]; then
        print_info "Setting up Docker environment..."
        
        # Build Docker image
        docker compose build
        print_success "Docker image built"
    else
        print_warning "Skipping Docker setup (Docker/Compose not available)"
    fi
}

# Interactive configuration
interactive_config() {
    echo ""
    print_info "Interactive Configuration"
    echo "=========================="
    echo ""
    
    # Ask for OpenAI API Key
    read -p "Enter your OpenAI API Key (or press Enter to skip): " OPENAI_KEY
    if [ -n "$OPENAI_KEY" ]; then
        # Update config.toml
        sed -i "s/api_key = \"\"/api_key = \"$OPENAI_KEY\"/" config/config.toml
        # Update .env
        sed -i "s/OPENAI_API_KEY=.*/OPENAI_API_KEY=$OPENAI_KEY/" .env
        print_success "OpenAI API Key configured"
    fi
    
    echo ""
    
    # Ask for installation type
    echo "Select installation type:"
    echo "1) Local (Python virtual environment)"
    echo "2) Docker (recommended for production)"
    echo "3) Both"
    read -p "Enter your choice [1-3]: " INSTALL_TYPE
    
    case $INSTALL_TYPE in
        1)
            print_info "Installing for local development..."
            setup_venv
            install_dependencies
            ;;
        2)
            print_info "Installing with Docker..."
            setup_docker
            ;;
        3)
            print_info "Installing both local and Docker..."
            setup_venv
            install_dependencies
            setup_docker
            ;;
        *)
            print_warning "Invalid choice, defaulting to local installation"
            setup_venv
            install_dependencies
            ;;
    esac
}

# Print final instructions
print_instructions() {
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}           Installation Complete!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Next steps:"
    echo ""
    echo "1. Configure your API keys in config/config.toml or .env"
    echo ""
    echo "2. Start the application:"
    echo ""
    echo "   Local development:"
    echo "   $ source venv/bin/activate"
    echo "   $ python web_run.py"
    echo ""
    echo "   Docker:"
    echo "   $ docker compose up -d"
    echo ""
    echo "3. Access the web interface at: http://localhost:8000"
    echo ""
    echo "4. (Optional) Access database admin at: http://localhost:8080"
    echo "   $ docker compose --profile development up -d"
    echo ""
    echo "For more information, see README.md"
    echo ""
}

# Main installation function
main() {
    print_banner
    
    # Get script directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
    
    # Change to project directory
    cd "$PROJECT_DIR"
    
    check_requirements
    create_directories
    setup_config
    interactive_config
    print_instructions
}

# Run main function
main "$@"
