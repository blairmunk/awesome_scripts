#!/bin/bash
# Automated Notesnook Self-Hosted Server Installation
# Based on guide: https://lemmy.world/post/24509570

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Functions for colored output
print_color() {
    printf "${1}%s${NC}\n" "$2"
}

print_step() {
    echo
    print_color $BLUE "📋 $1"
}

print_success() {
    print_color $GREEN "✅ $1"
}

print_warning() {
    print_color $YELLOW "⚠️  $1"
}

print_error() {
    print_color $RED "❌ $1"
}

print_info() {
    print_color $CYAN "ℹ️  $1"
}

print_header() {
    echo
    print_color $PURPLE "=========================================="
    print_color $PURPLE "$1"
    print_color $PURPLE "=========================================="
}

# Check that script is not run as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "Do not run this script as root!"
        print_warning "Run as a regular user with sudo privileges:"
        print_info "  ./notesnook-install.sh"
        exit 1
    fi
}

# Check sudo availability (but don't require running with sudo)
check_sudo() {
    print_step "Checking sudo privileges"
    
    # Check if user can use sudo
    if sudo -l &>/dev/null; then
        print_success "User can use sudo"
    else
        print_error "User cannot use sudo"
        print_info "Add user to sudo group:"
        print_info "  sudo usermod -aG sudo $USER"
        exit 1
    fi
    
    # Request sudo password if needed
    print_info "Enter sudo password to continue installation:"
    if ! sudo echo "Sudo privileges confirmed"; then
        print_error "Failed to obtain sudo privileges"
        exit 1
    fi
}

# Check operating system
check_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        if [[ "$ID" != "ubuntu" && "$ID_LIKE" != "*ubuntu*" && "$ID" != "debian" && "$ID_LIKE" != "*debian*" ]]; then
            print_warning "Script tested on Ubuntu24 Server. On $OS there might be issues."
            read -p "Continue? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    fi
}

# Function for user input
ask_input() {
    local prompt="$1"
    local var_name="$2"
    local default="$3"
    local is_password="$4"
    
    while true; do
        if [[ "$is_password" == "true" ]]; then
            read -s -p "$(printf "${CYAN}%s${NC}" "$prompt")" input
            echo
        else
            read -p "$(printf "${CYAN}%s${NC}" "$prompt")" input
        fi
        
        if [[ -n "$input" ]]; then
            declare -g "$var_name"="$input"
            break
        elif [[ -n "$default" ]]; then
            declare -g "$var_name"="$default"
            break
        else
            print_warning "This field is required!"
        fi
    done
}

# Email validation
validate_email() {
    local email="$1"
    if [[ $email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Domain validation
validate_domain() {
    local domain="$1"
    if [[ $domain =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        return 0
    else
        return 1
    fi
}

# Configuration collection
collect_config() {
    print_header "CONFIGURATION DATA COLLECTION"
    
    echo "This script will install Notesnook Self-Hosted Server"
    echo "The following subdomains are required for API services:"
    echo "  - auth.your-domain.com (authentication server)"
    echo "  - notes.your-domain.com (main API)"
    echo "  - events.your-domain.com (real-time events)"
    echo "  - mono.your-domain.com (public notes)"
    echo "  - files.your-domain.com (file storage)"
    echo
    print_info "Optionally, you can configure a subdomain for the web application"
    echo
    
    # Main domain input
    while true; do
        ask_input "Enter your main domain (e.g., your-domain.com): " DOMAIN
        if validate_domain "$DOMAIN"; then
            break
        else
            print_warning "Invalid domain format!"
        fi
    done
    
    # Web application setup
    print_step "Web Application Configuration"
    print_info "You can configure a separate subdomain for the Notesnook web interface"
    print_info "For example: nook.$DOMAIN (instead of using the main domain $DOMAIN)"
    echo
    
    while true; do
        ask_input "Configure separate subdomain for web application? (y/N) [N]: " SETUP_WEB_APP "N"
        if [[ "$SETUP_WEB_APP" =~ ^[YyNn]$ ]]; then
            break
        else
            print_warning "Enter Y or N"
        fi
    done
    
    if [[ "$SETUP_WEB_APP" =~ ^[Yy]$ ]]; then
        while true; do
            ask_input "Enter subdomain for web application (e.g., 'nook' for nook.$DOMAIN): " WEB_SUBDOMAIN "nook"
            if [[ "$WEB_SUBDOMAIN" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?$ ]]; then
                WEB_DOMAIN="$WEB_SUBDOMAIN.$DOMAIN"
                print_success "Web application will be available at: https://$WEB_DOMAIN"
                break
            else
                print_warning "Invalid subdomain format!"
            fi
        done
    else
        WEB_DOMAIN=""
    fi
    
    ask_input "Instance name [My Private Notesnook]: " INSTANCE_NAME "My Private Notesnook"
    
    # Registration disable
    while true; do
        ask_input "Disable new user registration? (true/false) [false]: " DISABLE_SIGNUPS_INPUT "false"
        if [[ "$DISABLE_SIGNUPS_INPUT" =~ ^(true|false)$ ]]; then
            DISABLE_SIGNUPS="$DISABLE_SIGNUPS_INPUT"
            break
        else
            print_warning "Enter true or false"
        fi
    done
    
    # Generate random API secret
    API_SECRET=$(openssl rand -hex 32)
    print_success "Generated API secret: $API_SECRET"
    
    print_step "SMTP Configuration (required for authentication)"
    print_info "For Gmail use app passwords: https://support.google.com/mail/answer/185833"
    
    # SMTP configuration
    while true; do
        ask_input "SMTP username (email): " SMTP_USERNAME
        if validate_email "$SMTP_USERNAME"; then
            break
        else
            print_warning "Invalid email format!"
        fi
    done
    
    ask_input "SMTP password: " SMTP_PASSWORD "true" "true"
    ask_input "SMTP host [smtp.gmail.com]: " SMTP_HOST "smtp.gmail.com"
    ask_input "SMTP port [587]: " SMTP_PORT "587"
    
    print_step "MinIO Configuration (file storage)"
    ask_input "MinIO username [admin]: " MINIO_USER "admin"
    
    # Generate MinIO password
    MINIO_PASSWORD=$(openssl rand -hex 16)
    print_success "Generated MinIO password: $MINIO_PASSWORD"
    
    # Configuration confirmation
    echo
    print_header "CONFIGURATION CONFIRMATION"
    echo "Main domain: $DOMAIN"
    echo "API subdomains:"
    echo "  - https://auth.$DOMAIN"
    echo "  - https://notes.$DOMAIN"
    echo "  - https://events.$DOMAIN"
    echo "  - https://mono.$DOMAIN"
    echo "  - https://files.$DOMAIN"
    
    if [[ -n "$WEB_DOMAIN" ]]; then
        echo "Web application:"
        echo "  - https://$WEB_DOMAIN"
    fi
    
    echo
    echo "Instance name: $INSTANCE_NAME"
    echo "Disable registration: $DISABLE_SIGNUPS"
    echo "SMTP: $SMTP_USERNAME@$SMTP_HOST:$SMTP_PORT"
    echo "MinIO: $MINIO_USER / $MINIO_PASSWORD"
    echo
    
    read -p "$(printf "${YELLOW}Continue installation with these settings? (y/N): ${NC}")" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Installation cancelled by user"
        exit 0
    fi
}

# System update
update_system() {
    print_step "System update"
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y curl wget gnupg lsb-release openssl net-tools dnsutils
    print_success "System updated"
}

# Docker installation
install_docker() {
    print_step "Docker installation"
    
    if command -v docker &> /dev/null && docker --version | grep -q "Docker version"; then
        print_success "Docker already installed: $(docker --version)"
    else
        # Install dependencies
        sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
        
        # Add Docker GPG key
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        
        # Add Docker repository
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Install Docker
        sudo apt update
        sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        
        # Start Docker
        sudo systemctl enable docker
        sudo systemctl start docker
        
        print_success "Docker installed: $(docker --version)"
    fi
    
    # Setup Docker permissions
    setup_docker_permissions
}

# Docker permissions setup
setup_docker_permissions() {
    print_step "Docker permissions setup"
    
    # Add user to docker group
    if ! groups $USER | grep -q docker; then
        print_info "Adding user $USER to docker group"
        sudo usermod -aG docker $USER
        print_success "User added to docker group"
    else
        print_success "User already in docker group"
    fi
    
    # Check Docker socket access
    if ! docker info >/dev/null 2>&1; then
        print_warning "Docker permissions not applied in current session"
        print_info "Applying docker group permissions for current session..."
        
        # Temporary solution - change socket permissions (not recommended for production)
        if [ -S "/var/run/docker.sock" ]; then
            sudo chmod 666 /var/run/docker.sock
            print_warning "Temporarily changed Docker socket permissions"
            print_info "Recommend to re-login after installation"
        fi
        
        # Check again
        if docker info >/dev/null 2>&1; then
            print_success "Docker accessible"
        else
            print_error "Failed to access Docker"
            print_info "Try re-logging and running the script again"
            exit 1
        fi
    else
        print_success "Docker accessible"
    fi
}

# Nginx and Certbot installation
install_nginx() {
    print_step "Nginx and Certbot installation"
    
    sudo apt install -y nginx certbot python3-certbot-nginx
    sudo systemctl enable nginx
    sudo systemctl start nginx
    
    print_success "Nginx installed: $(nginx -v 2>&1)"
    print_success "Certbot installed: $(certbot --version 2>&1 | head -n1)"
}

# Firewall configuration
configure_firewall() {
    print_step "Firewall configuration"
    
    # Check UFW status
    if ! command -v ufw &> /dev/null; then
        sudo apt install -y ufw
    fi
    
    # Allow SSH (careful!)
    sudo ufw allow ssh
    
    # Allow HTTP/HTTPS
    sudo ufw allow 'Nginx Full'
    
    # Allow Notesnook ports (for direct access if needed)
    sudo ufw allow 5264/tcp comment 'Notesnook API'
    sudo ufw allow 6264/tcp comment 'Notesnook Monograph'
    sudo ufw allow 7264/tcp comment 'Notesnook SSE'
    sudo ufw allow 8264/tcp comment 'Notesnook Identity'
    sudo ufw allow 9009/tcp comment 'MinIO API'
    sudo ufw allow 9090/tcp comment 'MinIO Console'
    
    # Enable firewall
    echo "y" | sudo ufw enable
    
    print_success "Firewall configured"
}

# Create directories
create_directories() {
    print_step "Directory creation"
    
    sudo mkdir -p /srv/Files/Notesnook/{db,s3,setup}
    sudo chown -R $USER:$USER /srv/Files/Notesnook
    
    # Create web application directory if needed
    if [[ -n "$WEB_DOMAIN" ]]; then
        sudo mkdir -p /var/www/notesnook-web
        sudo chown -R $USER:$USER /var/www/notesnook-web
    fi
    
    print_success "Directories created: /srv/Files/Notesnook/"
}

# Download Notesnook web application
download_web_app() {
    if [[ -n "$WEB_DOMAIN" ]]; then
        print_step "Creating Notesnook web application"
        
        # Go to web application directory
        cd /var/www/notesnook-web
        
        # Create a simple HTML page that redirects to official application
        # but configured to work with our server
        print_info "Creating Notesnook web application..."
        
        cat > index.html << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$INSTANCE_NAME</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 0;
            padding: 40px 20px;
            background: #f8f9fa;
            color: #2d3748;
            line-height: 1.6;
        }
        .container {
            max-width: 600px;
            margin: 0 auto;
            background: white;
            padding: 40px;
            border-radius: 12px;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
        }
        .logo {
            text-align: center;
            margin-bottom: 30px;
        }
        .logo h1 {
            color: #0560ff;
            font-size: 2.5em;
            margin: 0;
            font-weight: 700;
        }
        .subtitle {
            text-align: center;
            color: #718096;
            margin-bottom: 30px;
            font-size: 1.1em;
        }
        .info-box {
            background: #f7fafc;
            border: 1px solid #e2e8f0;
            border-radius: 8px;
            padding: 20px;
            margin: 20px 0;
        }
        .info-box h3 {
            margin-top: 0;
            color: #2d3748;
        }
        .server-url {
            background: #0560ff;
            color: white;
            padding: 15px;
            border-radius: 8px;
            text-align: center;
            font-family: monospace;
            font-size: 1.1em;
            margin: 20px 0;
        }
        .btn {
            display: inline-block;
            background: #0560ff;
            color: white;
            padding: 12px 24px;
            text-decoration: none;
            border-radius: 8px;
            font-weight: 600;
            margin: 10px 10px 10px 0;
            transition: background 0.2s;
        }
        .btn:hover {
            background: #0447cc;
        }
        .btn-secondary {
            background: #718096;
        }
        .btn-secondary:hover {
            background: #4a5568;
        }
        .instructions {
            margin-top: 30px;
        }
        .step {
            margin: 15px 0;
            padding-left: 20px;
        }
        .step:before {
            content: "→";
            color: #0560ff;
            font-weight: bold;
            margin-right: 10px;
            margin-left: -20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">
            <h1>📝 Notesnook</h1>
        </div>
        <div class="subtitle">
            $INSTANCE_NAME
        </div>
        
        <div class="info-box">
            <h3>🚀 Welcome to your private Notesnook server!</h3>
            <p>Your Notesnook sync server is configured and ready to use.</p>
        </div>

        <div class="server-url">
            https://notes.$DOMAIN
        </div>

        <div style="text-align: center;">
            <a href="https://app.notesnook.com" class="btn" target="_blank">
                Open Web App
            </a>
            <a href="https://notesnook.com/downloads" class="btn btn-secondary" target="_blank">
                Download Apps
            </a>
        </div>

        <div class="instructions">
            <h3>📱 Client Setup:</h3>
            <div class="step">Open Notesnook app (web, desktop or mobile)</div>
            <div class="step">Go to Settings → Sync Server</div>
            <div class="step">Enter URL: <strong>https://notes.$DOMAIN</strong></div>
            <div class="step">Create a new account or sign in to existing one</div>
        </div>

        <div class="info-box">
            <h3>🔗 Useful Links:</h3>
            <p><strong>API Server:</strong> <a href="https://notes.$DOMAIN/health">https://notes.$DOMAIN</a></p>
            <p><strong>Public Notes:</strong> <a href="https://mono.$DOMAIN">https://mono.$DOMAIN</a></p>
            <p><strong>Files (MinIO):</strong> <a href="https://files.$DOMAIN">https://files.$DOMAIN</a></p>
        </div>
    </div>

    <script>
        // Automatic sync server configuration for Notesnook web app
        if (window.location.search.includes('setup=true')) {
            localStorage.setItem('serverURL', 'https://notes.$DOMAIN');
            alert('Sync server configured: https://notes.$DOMAIN');
        }
    </script>
</body>
</html>
EOF
        
        print_success "Web application created in /var/www/notesnook-web/"
    fi
}

# Create configuration files
create_config_files() {
    print_step "Configuration files creation"
    
    cd /srv/Files/Notesnook/setup
    
    # Create .env file (use HTTPS immediately as certbot will auto-configure)
    cat > .env << EOL
# Instance Configuration
INSTANCE_NAME=$INSTANCE_NAME
DISABLE_SIGNUPS=$DISABLE_SIGNUPS
NOTESNOOK_API_SECRET=$API_SECRET

# SMTP Configuration (required for authentication)
SMTP_USERNAME=$SMTP_USERNAME
SMTP_PASSWORD=$SMTP_PASSWORD
SMTP_HOST=$SMTP_HOST
SMTP_PORT=$SMTP_PORT

# Public URLs (will be updated to HTTPS after SSL obtained)
AUTH_SERVER_PUBLIC_URL=https://auth.$DOMAIN/
NOTESNOOK_APP_PUBLIC_URL=https://notes.$DOMAIN/
MONOGRAPH_PUBLIC_URL=https://mono.$DOMAIN/
ATTACHMENTS_SERVER_PUBLIC_URL=https://files.$DOMAIN/

# MinIO Configuration
MINIO_ROOT_USER=$MINIO_USER
MINIO_ROOT_PASSWORD=$MINIO_PASSWORD
EOL

    # Create docker-compose.yml (from original guide)
    cat > docker-compose.yml << 'EOL'
x-server-discovery: &server-discovery
  NOTESNOOK_SERVER_PORT: 5264
  NOTESNOOK_SERVER_HOST: notesnook-server
  IDENTITY_SERVER_PORT: 8264
  IDENTITY_SERVER_HOST: identity-server
  SSE_SERVER_PORT: 7264
  SSE_SERVER_HOST: sse-server
  SELF_HOSTED: 1
  IDENTITY_SERVER_URL: ${AUTH_SERVER_PUBLIC_URL}
  NOTESNOOK_APP_HOST: ${NOTESNOOK_APP_PUBLIC_URL}

x-env-files: &env-files
  - .env

services:
  validate:
    image: vandot/alpine-bash
    entrypoint: /bin/bash
    env_file: *env-files
    command:
      - -c
      - |
        required_vars=(
          "INSTANCE_NAME"
          "NOTESNOOK_API_SECRET"
          "DISABLE_SIGNUPS"
          "SMTP_USERNAME"
          "SMTP_PASSWORD"
          "SMTP_HOST"
          "SMTP_PORT"
          "AUTH_SERVER_PUBLIC_URL"
          "NOTESNOOK_APP_PUBLIC_URL"
          "MONOGRAPH_PUBLIC_URL"
          "ATTACHMENTS_SERVER_PUBLIC_URL"
        )
        for var in "$${required_vars[@]}"; do
          if [ -z "$${!var}" ]; then
            echo "Error: Required environment variable $$var is not set."
            exit 1
          fi
        done
        echo "All required environment variables are set."
    restart: "no"

  notesnook-db:
    image: mongo:7.0.12
    hostname: notesnook-db
    volumes:
      - /srv/Files/Notesnook/db:/data/db
      - /srv/Files/Notesnook/db:/data/configdb
    networks:
      - notesnook
    command: --replSet rs0 --bind_ip_all
    depends_on:
      validate:
        condition: service_completed_successfully
    healthcheck:
      test: echo 'db.runCommand("ping").ok' | mongosh mongodb://localhost:27017 --quiet
      interval: 40s
      timeout: 30s
      retries: 3
      start_period: 60s

  initiate-rs0:
    image: mongo:7.0.12
    networks:
      - notesnook
    depends_on:
      - notesnook-db
    entrypoint: /bin/sh
    command:
      - -c
      - |
        mongosh mongodb://notesnook-db:27017 <<EOF
          rs.initiate();
          rs.status();
        EOF

  notesnook-s3:
    image: minio/minio:RELEASE.2024-07-29T22-14-52Z
    ports:
      - 9009:9000
      - 9090:9090
    networks:
      - notesnook
    volumes:
      - /srv/Files/Notesnook/s3:/data/s3
    environment:
      MINIO_BROWSER: "on"
    depends_on:
      validate:
        condition: service_completed_successfully
    env_file: *env-files
    command: server /data/s3 --console-address :9090
    healthcheck:
      test: timeout 5s bash -c ':> /dev/tcp/127.0.0.1/9000' || exit 1
      interval: 40s
      timeout: 30s
      retries: 3
      start_period: 60s

  setup-s3:
    image: minio/mc:RELEASE.2024-07-26T13-08-44Z
    depends_on:
      - notesnook-s3
    networks:
      - notesnook
    entrypoint: /bin/bash
    env_file: *env-files
    command:
      - -c
      - |
        until mc alias set minio http://notesnook-s3:9000/ ${MINIO_ROOT_USER:-minioadmin} ${MINIO_ROOT_PASSWORD:-minioadmin}; do
          sleep 1;
        done;
        mc mb minio/attachments -p

  identity-server:
    image: streetwriters/identity:latest
    ports:
      - 8264:8264
    networks:
      - notesnook
    env_file: *env-files
    depends_on:
      - notesnook-db
    healthcheck:
      test: wget --tries=1 -nv -q  http://localhost:8264/health -O- || exit 1
      interval: 40s
      timeout: 30s
      retries: 3
      start_period: 60s
    environment:
      <<: *server-discovery
      MONGODB_CONNECTION_STRING: mongodb://notesnook-db:27017/identity?replSet=rs0
      MONGODB_DATABASE_NAME: identity

  notesnook-server:
    image: streetwriters/notesnook-sync:latest
    ports:
      - 5264:5264
    networks:
      - notesnook
    env_file: *env-files
    depends_on:
      - notesnook-s3
      - setup-s3
      - identity-server
    healthcheck:
      test: wget --tries=1 -nv -q  http://localhost:5264/health -O- || exit 1
      interval: 40s
      timeout: 30s
      retries: 3
      start_period: 60s
    environment:
      <<: *server-discovery
      MONGODB_CONNECTION_STRING: mongodb://notesnook-db:27017/?replSet=rs0
      MONGODB_DATABASE_NAME: notesnook
      S3_INTERNAL_SERVICE_URL: "http://notesnook-s3:9000/"
      S3_INTERNAL_BUCKET_NAME: "attachments"
      S3_ACCESS_KEY_ID: "${MINIO_ROOT_USER:-minioadmin}"
      S3_ACCESS_KEY: "${MINIO_ROOT_PASSWORD:-minioadmin}"
      S3_SERVICE_URL: "${ATTACHMENTS_SERVER_PUBLIC_URL}"
      S3_REGION: "us-east-1"
      S3_BUCKET_NAME: "attachments"

  sse-server:
    image: streetwriters/sse:latest
    ports:
      - 7264:7264
    env_file: *env-files
    depends_on:
      - identity-server
      - notesnook-server
    networks:
      - notesnook
    healthcheck:
      test: wget --tries=1 -nv -q  http://localhost:7264/health -O- || exit 1
      interval: 40s
      timeout: 30s
      retries: 3
      start_period: 60s
    environment:
      <<: *server-discovery

  monograph-server:
    image: streetwriters/monograph:latest
    ports:
      - 6264:3000
    env_file: *env-files
    depends_on:
      - notesnook-server
    networks:
      - notesnook
    healthcheck:
      test: wget --tries=1 -nv -q  http://localhost:3000/api/health -O- || exit 1
      interval: 40s
      timeout: 30s
      retries: 3
      start_period: 60s
    environment:
      <<: *server-discovery
      API_HOST: http://notesnook-server:5264/
      PUBLIC_URL: ${MONOGRAPH_PUBLIC_URL}

networks:
  notesnook:
EOL
    
    print_success "Configuration files created"
}

# Pull Docker images
pull_images() {
    print_step "Downloading Docker images"
    
    cd /srv/Files/Notesnook/setup
    docker compose pull
    
    print_success "Docker images downloaded"
}

# Start services
start_services() {
    print_step "Starting Notesnook services"
    
    cd /srv/Files/Notesnook/setup
    
    # Start services
    docker compose up -d
    
    # Wait for startup
    print_info "Waiting for services to start (60 seconds)..."
    sleep 60
    
    print_success "Notesnook services started"
}

# Configure Nginx (HTTP + ACME challenge)
configure_nginx_http() {
    print_step "Configuring Nginx (HTTP + ACME challenge)"
    
    # Create ACME challenge directory
    sudo mkdir -p /var/www/html/.well-known/acme-challenge/
    sudo chown -R www-data:www-data /var/www/html/
    
    # Remove default site if exists
    sudo rm -f /etc/nginx/sites-enabled/default
    
    # Auth Server
    sudo tee /etc/nginx/sites-available/notesnook-auth > /dev/null << EOF
server {
    listen 80;
    server_name auth.$DOMAIN;

    # Let's Encrypt ACME challenge support
    location /.well-known/acme-challenge/ {
        root /var/www/html;
        try_files \$uri =404;
    }

    location / {
        proxy_pass http://127.0.0.1:8264;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

    # Notes Server
    sudo tee /etc/nginx/sites-available/notesnook-notes > /dev/null << EOF
server {
    listen 80;
    server_name notes.$DOMAIN;

    # Let's Encrypt ACME challenge support
    location /.well-known/acme-challenge/ {
        root /var/www/html;
        try_files \$uri =404;
    }

    location / {
        proxy_pass http://127.0.0.1:5264;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 3600;
        proxy_send_timeout 3600;
    }
}
EOF

    # Events Server
    sudo tee /etc/nginx/sites-available/notesnook-events > /dev/null << EOF
server {
    listen 80;
    server_name events.$DOMAIN;

    # Let's Encrypt ACME challenge support
    location /.well-known/acme-challenge/ {
        root /var/www/html;
        try_files \$uri =404;
    }

    location / {
        proxy_pass http://127.0.0.1:7264;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 3600;
        proxy_send_timeout 3600;
    }
}
EOF

    # Monograph Server
    sudo tee /etc/nginx/sites-available/notesnook-mono > /dev/null << EOF
server {
    listen 80;
    server_name mono.$DOMAIN;

    # Let's Encrypt ACME challenge support
    location /.well-known/acme-challenge/ {
        root /var/www/html;
        try_files \$uri =404;
    }

    location / {
        proxy_pass http://127.0.0.1:6264;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Caching for performance improvement
        proxy_cache_use_stale error timeout http_500 http_502 http_503 http_504;
        proxy_cache_valid 200 60m;
        expires 1h;
        add_header Cache-Control "public, no-transform";
    }
}
EOF

    # Files Server (MinIO)
    sudo tee /etc/nginx/sites-available/notesnook-files > /dev/null << EOF
server {
    listen 80;
    server_name files.$DOMAIN;

    # Let's Encrypt ACME challenge support
    location /.well-known/acme-challenge/ {
        root /var/www/html;
        try_files \$uri =404;
    }

    client_max_body_size 50M;

    location / {
        proxy_pass http://127.0.0.1:9009;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_buffering off;
    }
}
EOF

    # Web Application (if configured)
    if [[ -n "$WEB_DOMAIN" ]]; then
        sudo tee /etc/nginx/sites-available/notesnook-web > /dev/null << EOF
server {
    listen 80;
    server_name $WEB_DOMAIN;

    # Let's Encrypt ACME challenge support
    location /.well-known/acme-challenge/ {
        root /var/www/html;
        try_files \$uri =404;
    }

    root /var/www/notesnook-web;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }

    # Static files caching
    location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF
    fi

    # Enable configurations
    sudo ln -sf /etc/nginx/sites-available/notesnook-auth /etc/nginx/sites-enabled/
    sudo ln -sf /etc/nginx/sites-available/notesnook-notes /etc/nginx/sites-enabled/
    sudo ln -sf /etc/nginx/sites-available/notesnook-events /etc/nginx/sites-enabled/
    sudo ln -sf /etc/nginx/sites-available/notesnook-mono /etc/nginx/sites-enabled/
    sudo ln -sf /etc/nginx/sites-available/notesnook-files /etc/nginx/sites-enabled/
    
    if [[ -n "$WEB_DOMAIN" ]]; then
        sudo ln -sf /etc/nginx/sites-available/notesnook-web /etc/nginx/sites-enabled/
    fi

    # Test and reload Nginx
    if sudo nginx -t; then
        sudo systemctl reload nginx
        print_success "Nginx configurations set up"
    else
        print_error "Error in Nginx configuration"
        exit 1
    fi
}

# Check DNS records
check_dns_records() {
    print_step "Checking DNS records"
    
    subdomains=("auth" "notes" "events" "mono" "files")
    
    # Add web application if configured
    if [[ -n "$WEB_DOMAIN" ]]; then
        subdomains+=("$WEB_SUBDOMAIN")
    fi
    
    dns_issues=()
    
    for sub in "${subdomains[@]}"; do
        if [[ "$sub" == "$WEB_SUBDOMAIN" ]]; then
            full_domain="$WEB_DOMAIN"
        else
            full_domain="${sub}.${DOMAIN}"
        fi
        
        print_info "Checking DNS for $full_domain"
        
        if host "$full_domain" > /dev/null 2>&1; then
            # Get IP from DNS
            resolved_ip=$(host "$full_domain" | grep "has address" | awk '{print $4}' | head -n1)
            if [[ -n "$resolved_ip" ]]; then
                print_success "DNS record for $full_domain found: $resolved_ip"
            else
                print_error "DNS record for $full_domain not found"
                dns_issues+=("$full_domain")
            fi
        else
            print_error "DNS record for $full_domain not found"
            dns_issues+=("$full_domain")
        fi
    done
    
    if [ ${#dns_issues[@]} -gt 0 ]; then
        print_error "DNS records not found for:"
        for domain in "${dns_issues[@]}"; do
            echo "  - $domain"
        done
        echo
        print_warning "Create A-records in your DNS provider:"
        for sub in auth notes events mono files; do
            echo "  ${sub}.${DOMAIN}  A  $(curl -s ifconfig.me || echo 'YOUR_IP_ADDRESS')"
        done
        if [[ -n "$WEB_DOMAIN" ]]; then
            echo "  $WEB_DOMAIN  A  $(curl -s ifconfig.me || echo 'YOUR_IP_ADDRESS')"
        fi
        echo
        read -p "$(printf "${YELLOW}DNS records created? Continue? (y/N): ${NC}")" -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Installation paused. Create DNS records and run script again."
            exit 1
        fi
    fi
}

# Test HTTP accessibility
test_http_access() {
    print_step "Testing HTTP accessibility"
    
    # Create test file
    echo "notesnook-test" | sudo tee /var/www/html/.well-known/acme-challenge/test > /dev/null
    
    subdomains=("auth" "notes" "events" "mono" "files")
    if [[ -n "$WEB_DOMAIN" ]]; then
        subdomains+=("web")
    fi
    
    access_issues=()
    
    for sub in "${subdomains[@]}"; do
        if [[ "$sub" == "web" ]]; then
            full_domain="$WEB_DOMAIN"
            test_url="http://${full_domain}/.well-known/acme-challenge/test"
        else
            full_domain="${sub}.${DOMAIN}"
            test_url="http://${full_domain}/.well-known/acme-challenge/test"
        fi
        
        print_info "Testing $test_url"
        if curl -sf "$test_url" -m 10 > /dev/null 2>&1; then
            print_success "HTTP access to $full_domain works"
        else
            print_error "HTTP access to $full_domain does NOT work"
            access_issues+=("$full_domain")
        fi
    done
    
    # Remove test file
    sudo rm -f /var/www/html/.well-known/acme-challenge/test
    
    if [ ${#access_issues[@]} -gt 0 ]; then
        print_error "Accessibility issues:"
        for domain in "${access_issues[@]}"; do
            echo "  - $domain"
        done
        print_warning "Check DNS records and firewall settings"
        exit 1
    fi
}

# Get SSL certificates
get_ssl_certificates() {
    print_step "Obtaining SSL certificates"
    
    # Determine email for registration
    certbot_email_option="--email $SMTP_USERNAME"
    
    # Collect all domains for certificates
    domain_args=""
    domain_args="$domain_args -d auth.${DOMAIN}"
    domain_args="$domain_args -d notes.${DOMAIN}"
    domain_args="$domain_args -d events.${DOMAIN}"
    domain_args="$domain_args -d mono.${DOMAIN}"
    domain_args="$domain_args -d files.${DOMAIN}"
    
    if [[ -n "$WEB_DOMAIN" ]]; then
        domain_args="$domain_args -d $WEB_DOMAIN"
    fi
    
    print_info "Obtaining SSL certificates for all subdomains..."
    print_info "Domains: auth.$DOMAIN, notes.$DOMAIN, events.$DOMAIN, mono.$DOMAIN, files.$DOMAIN$([ -n "$WEB_DOMAIN" ] && echo ", $WEB_DOMAIN")"
    
    if sudo certbot --nginx --non-interactive --agree-tos $certbot_email_option $domain_args; then
        print_success "SSL certificates successfully obtained for all subdomains"
    else
        print_warning "Failed to obtain certificates for all domains at once, trying one by one..."
        
        # Obtain certificates one by one
        all_domains=("auth.$DOMAIN" "notes.$DOMAIN" "events.$DOMAIN" "mono.$DOMAIN" "files.$DOMAIN")
        if [[ -n "$WEB_DOMAIN" ]]; then
            all_domains+=("$WEB_DOMAIN")
        fi
        
        failed_domains=()
        for full_domain in "${all_domains[@]}"; do
            print_info "Obtaining certificate for $full_domain"
            
            if sudo certbot --nginx --non-interactive --agree-tos $certbot_email_option -d "$full_domain"; then
                print_success "Certificate for $full_domain obtained"
            else
                print_error "Failed to obtain certificate for $full_domain"
                failed_domains+=("$full_domain")
            fi
        done
        
        if [ ${#failed_domains[@]} -gt 0 ]; then
            print_error "Failed to obtain SSL certificates for:"
            for domain in "${failed_domains[@]}"; do
                echo "  - $domain"
            done
            print_warning "System will work over HTTP for problematic domains"
        fi
    fi
    
    # After obtaining certificates, certbot automatically updated Nginx configurations
    print_info "Certbot automatically updated Nginx configurations for HTTPS"
}

# Check SSL certificates status (FIXED)
check_ssl_certificates() {
    print_step "Checking SSL certificates status"
    
    all_domains=("auth.$DOMAIN" "notes.$DOMAIN" "events.$DOMAIN" "mono.$DOMAIN" "files.$DOMAIN")
    if [[ -n "$WEB_DOMAIN" ]]; then
        all_domains+=("$WEB_DOMAIN")
    fi
    
    for full_domain in "${all_domains[@]}"; do
        # Test actual HTTPS connectivity instead of just checking files
        print_info "Testing HTTPS connectivity for $full_domain"
        
        if curl -sf "https://$full_domain" -m 10 >/dev/null 2>&1; then
            print_success "HTTPS working for $full_domain"
        else
            # If HTTPS fails, check if certificate file exists
            cert_path="/etc/letsencrypt/live/${full_domain}/fullchain.pem"
            if [ -f "$cert_path" ]; then
                expiry=$(openssl x509 -enddate -noout -in "$cert_path" | cut -d= -f2)
                print_warning "SSL certificate for $full_domain exists but HTTPS not responding (expires: $expiry)"
            else
                print_warning "SSL certificate for $full_domain not found"
            fi
        fi
    done
}

# Restart Docker containers (no need to change .env, certbot already configured HTTPS)
restart_docker_services() {
    print_step "Restarting Docker containers"
    
    cd /srv/Files/Notesnook/setup
    
    # Simple restart without configuration changes
    docker compose restart
    
    print_success "Docker containers restarted"
}

# Check container status with Docker error handling
check_container_status() {
    print_step "Checking services status"
    
    cd /srv/Files/Notesnook/setup
    
    # Attempt to get container status
    if docker compose ps >/dev/null 2>&1; then
        docker compose ps
        print_success "Docker containers running"
    else
        print_warning "Issues accessing Docker"
        print_info "Checking Docker socket permissions..."
        
        # Check socket permissions
        if [ -S "/var/run/docker.sock" ]; then
            socket_perms=$(ls -la /var/run/docker.sock)
            print_info "Docker socket permissions: $socket_perms"
            
            # Temporarily fix permissions to complete installation
            sudo chmod 666 /var/run/docker.sock
            print_warning "Temporarily changed Docker socket permissions"
            
            # Try again
            if docker compose ps >/dev/null 2>&1; then
                docker compose ps
                print_success "Docker containers running"
                print_warning "Recommend re-login for correct Docker operation"
            else
                print_error "Failed to get container status"
            fi
        else
            print_error "Docker socket not found"
        fi
    fi
}

# Create management utilities
create_management_utilities() {
    print_step "Creating management utilities"
    
    cd /srv/Files/Notesnook/setup
    
    # Docker permissions fix script
    cat > fix-docker-permissions.sh << 'EOL'
#!/bin/bash
# Docker permissions fix script

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🔧 Fixing Docker permissions...${NC}"

# Restore proper socket permissions
sudo chmod 660 /var/run/docker.sock
sudo chown root:docker /var/run/docker.sock

# Check user group
if groups $USER | grep -q docker; then
    echo -e "${GREEN}✅ User in docker group${NC}"
else
    echo -e "${YELLOW}⚠️  Adding user to docker group${NC}"
    sudo usermod -aG docker $USER
fi

echo -e "${YELLOW}⚠️  Re-login to apply docker group permissions${NC}"
echo -e "${BLUE}Or execute: newgrp docker${NC}"
EOL

    # Monitoring script (updated with web application considerations)
    cat > monitor.sh << 'EOL'
#!/bin/bash
# Notesnook monitoring script

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

cd "$(dirname "$0")"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}     NOTESNOOK SERVER MONITORING       ${NC}"
echo -e "${BLUE}========================================${NC}"

echo -e "\n${BLUE}=== Container Status ===${NC}"
if docker compose ps >/dev/null 2>&1; then
    docker compose ps
else
    echo -e "${YELLOW}⚠️  Issues accessing Docker${NC}"
    echo -e "${YELLOW}Execute: ./fix-docker-permissions.sh${NC}"
    echo -e "${YELLOW}Or: sudo docker compose ps${NC}"
fi

echo -e "\n${BLUE}=== Disk Space Usage ===${NC}"
df -h /srv/Files/Notesnook/

echo -e "\n${BLUE}=== Local Endpoint Check ===${NC}"
endpoints=(
    "http://localhost:8264/health"
    "http://localhost:5264/health" 
    "http://localhost:7264/health"
    "http://localhost:3000/api/health"
)

for endpoint in "${endpoints[@]}"; do
    if curl -sf "$endpoint" -m 5 > /dev/null 2>&1; then
        echo -e "${GREEN}✅ $endpoint${NC}"
    else
        echo -e "${RED}❌ $endpoint${NC}"
    fi
done

# Check HTTPS endpoints
if [ -f .env ]; then
    source .env
    domain=$(echo "$AUTH_SERVER_PUBLIC_URL" | sed 's|https\?://auth\.||' | sed 's|/.*||')
    
    echo -e "\n${BLUE}=== HTTPS Endpoints Check ===${NC}"
    https_endpoints=(
        "https://auth.${domain}/health"
        "https://notes.${domain}/health"
        "https://events.${domain}/health"
        "https://mono.${domain}/api/health"
        "https://files.${domain}/"
    )
    
    for endpoint in "${https_endpoints[@]}"; do
        if curl -sf "$endpoint" -m 10 > /dev/null 2>&1; then
            echo -e "${GREEN}✅ $endpoint${NC}"
        else
            echo -e "${RED}❌ $endpoint${NC}"
        fi
    done
fi

echo -e "\n${BLUE}=== SSL Certificates ===${NC}"
if [ -f .env ]; then
    source .env
    domain=$(echo "$AUTH_SERVER_PUBLIC_URL" | sed 's|https\?://auth\.||' | sed 's|/.*||')
    
    subdomains=("auth" "notes" "events" "mono" "files")
    for sub in "${subdomains[@]}"; do
        full_domain="${sub}.${domain}"
        if curl -sf "https://$full_domain" -m 5 >/dev/null 2>&1; then
            echo -e "${GREEN}✅ HTTPS working for ${full_domain}${NC}"
        else
            echo -e "${YELLOW}⚠️  HTTPS issues for ${full_domain}${NC}"
        fi
    done
    
    # Check web application
    if [ -d "/var/www/notesnook-web" ]; then
        echo -e "${GREEN}✅ Web application configured${NC}"
    fi
fi

EOL

    # Other utilities (update.sh, backup.sh, renew-ssl.sh)
    cat > update.sh << 'EOL'
#!/bin/bash
# Notesnook update script

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

cd "$(dirname "$0")"

echo -e "${BLUE}🔄 Updating Notesnook server...${NC}"

# Create configuration backup
echo -e "${BLUE}📦 Creating configuration backup...${NC}"
cp .env .env.backup.$(date +%Y%m%d_%H%M%S)
cp docker-compose.yml docker-compose.yml.backup.$(date +%Y%m%d_%H%M%S)

# Download new images
echo -e "${BLUE}⬇️  Downloading Docker image updates...${NC}"
if docker compose pull >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Images downloaded${NC}"
else
    echo -e "${YELLOW}⚠️  Using sudo for docker commands${NC}"
    sudo docker compose pull
fi

# Restart with new images
echo -e "${BLUE}🔄 Restarting with new images...${NC}"
if docker compose down >/dev/null 2>&1 && docker compose up -d >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Services restarted${NC}"
else
    sudo docker compose down
    sudo docker compose up -d
fi

# Wait for startup
echo -e "${BLUE}⏱️  Waiting for services to start...${NC}"
sleep 30

# Check status
echo -e "${BLUE}✅ Checking status after update:${NC}"
if docker compose ps >/dev/null 2>&1; then
    docker compose ps
else
    sudo docker compose ps
fi

echo -e "${GREEN}✅ Update completed!${NC}"
EOL

    cat > backup.sh << 'EOL'
#!/bin/bash
# Notesnook backup script

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

cd "$(dirname "$0")"

BACKUP_DIR="/backups/notesnook-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo -e "${BLUE}📦 Creating Notesnook backup...${NC}"

# Stop services for consistent backup
echo -e "${BLUE}⏹️  Stopping services...${NC}"
if docker compose stop >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Services stopped${NC}"
else
    sudo docker compose stop
fi

# Copy data
echo -e "${BLUE}📁 Copying data...${NC}"
cp -r /srv/Files/Notesnook/db "$BACKUP_DIR/"
cp -r /srv/Files/Notesnook/s3 "$BACKUP_DIR/"
cp .env "$BACKUP_DIR/"
cp docker-compose.yml "$BACKUP_DIR/"

# Copy web application if exists
if [ -d "/var/www/notesnook-web" ]; then
    cp -r /var/www/notesnook-web "$BACKUP_DIR/"
fi

# Create archive
echo -e "${BLUE}🗜️  Creating archive...${NC}"
tar -czf "$BACKUP_DIR.tar.gz" -C "$(dirname "$BACKUP_DIR")" "$(basename "$BACKUP_DIR")"
rm -rf "$BACKUP_DIR"

# Start services
echo -e "${BLUE}▶️  Starting services...${NC}"
if docker compose up -d >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Services started${NC}"
else
    sudo docker compose up -d
fi

echo -e "${GREEN}✅ Backup created: $BACKUP_DIR.tar.gz${NC}"
echo -e "${YELLOW}💾 Size: $(du -h "$BACKUP_DIR.tar.gz" | cut -f1)${NC}"
EOL

    cat > renew-ssl.sh << 'EOL'
#!/bin/bash
# SSL certificates renewal script

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🔒 Renewing SSL certificates...${NC}"

# Renew certificates
if sudo certbot renew --quiet; then
    echo -e "${GREEN}✅ SSL certificates renewed${NC}"
    
    # Reload Nginx
    sudo systemctl reload nginx
    echo -e "${GREEN}✅ Nginx reloaded${NC}"
else
    echo -e "${RED}❌ Error renewing SSL certificates${NC}"
    exit 1
fi
EOL

    chmod +x *.sh
    
    print_success "Management utilities created:"
    print_info "  - fix-docker-permissions.sh : fix Docker permissions"
    print_info "  - monitor.sh               : system monitoring"
    print_info "  - update.sh                : service updates"
    print_info "  - backup.sh                : backup creation"
    print_info "  - renew-ssl.sh             : SSL certificate renewal"
}

# Final system check
final_system_check() {
    print_step "Final system check"
    
    cd /srv/Files/Notesnook/setup
    
    # Wait for full startup
    print_info "Waiting for full service startup (30 seconds)..."
    sleep 30
    
    # Check container status
    check_container_status
    
    # Check SSL certificates
    check_ssl_certificates
    
    # Check local endpoints
    echo
    print_info "Checking local endpoints:"
    local_endpoints=(
        "http://localhost:8264/health"
        "http://localhost:5264/health"
        "http://localhost:7264/health"
        "http://localhost:3000/api/health"
    )
    
    for endpoint in "${local_endpoints[@]}"; do
        if curl -sf "$endpoint" -m 10 > /dev/null 2>&1; then
            print_success "✅ $endpoint"
        else
            print_warning "❌ $endpoint (may need more time to start)"
        fi
    done
    
    # Check external HTTPS endpoints
    echo
    print_info "Checking external HTTPS endpoints:"
    
    https_endpoints=(
        "https://auth.${DOMAIN}/health"
        "https://notes.${DOMAIN}/health"
        "https://events.${DOMAIN}/health"
        "https://mono.${DOMAIN}/api/health"
    )
    
    if [[ -n "$WEB_DOMAIN" ]]; then
        https_endpoints+=("https://$WEB_DOMAIN/")
    fi
    
    for endpoint in "${https_endpoints[@]}"; do
        if curl -sf "$endpoint" -m 15 > /dev/null 2>&1; then
            print_success "✅ $endpoint"
        else
            print_warning "❌ $endpoint"
        fi
    done
}

# Display final information
show_final_info() {
    print_header "🎉 INSTALLATION COMPLETED!"
    
    source /srv/Files/Notesnook/setup/.env
    
    echo
    print_color $GREEN "✅ Notesnook Self-Hosted Server successfully installed!"
    echo
    
    print_color $CYAN "📋 SYSTEM INFORMATION:"
    echo "   Main domain: $DOMAIN"
    echo "   Instance name: $INSTANCE_NAME"
    echo "   Registration: $([ "$DISABLE_SIGNUPS" = "true" ] && echo "Disabled" || echo "Enabled")"
    echo
    
    print_color $CYAN "🌐 AVAILABLE SERVICES:"
    echo "   Authentication server: https://auth.$DOMAIN"
    echo "   API server:           https://notes.$DOMAIN" 
    echo "   Events (SSE):         https://events.$DOMAIN"
    echo "   Public notes:         https://mono.$DOMAIN"
    echo "   File storage:         https://files.$DOMAIN"
    echo "   MinIO console:        https://files.$DOMAIN ($MINIO_ROOT_USER / $MINIO_ROOT_PASSWORD)"
    
    if [[ -n "$WEB_DOMAIN" ]]; then
        echo "   Web application:      https://$WEB_DOMAIN"
    fi
    echo
    
    print_color $CYAN "🔧 USEFUL COMMANDS:"
    echo "   cd /srv/Files/Notesnook/setup"
    echo "   ./fix-docker-permissions.sh # Fix Docker permissions"
    echo "   ./monitor.sh                # System monitoring"
    echo "   ./update.sh                 # Service updates"
    echo "   ./backup.sh                 # Backup creation"
    echo "   ./renew-ssl.sh              # SSL certificate renewal"
    echo
    
    print_color $CYAN "📱 CLIENT SETUP:"
    echo "   1. Open Notesnook app (mobile or https://app.notesnook.com)"
    echo "   2. Go to Settings → Sync Server"
    echo "   3. Enter URL: https://notes.$DOMAIN"
    echo "   4. Create a new account or sign in to existing one"
    echo
    
    if [[ -n "$WEB_DOMAIN" ]]; then
        print_color $CYAN "🌍 WEB APPLICATION:"
        echo "   Open https://$WEB_DOMAIN in browser"
        echo "   There you'll find client setup instructions"
        echo
    fi
    
    print_color $YELLOW "⚠️  IMPORTANT NOTES:"
    echo "   • If Docker issues occur: ./fix-docker-permissions.sh"
    echo "   • Create regular backups: ./backup.sh"
    echo "   • Monitor system: ./monitor.sh"
    echo "   • Update services: ./update.sh"
    echo "   • Setup automatic SSL certificate renewal:"
    echo "     sudo crontab -e"
    echo "     0 12 * * * /srv/Files/Notesnook/setup/renew-ssl.sh"
    echo
    
    print_color $YELLOW "🔐 SECURITY:"
    echo "   • Configuration: /srv/Files/Notesnook/setup/.env"
    echo "   • MinIO username: $MINIO_ROOT_USER"
    echo "   • MinIO password: $MINIO_ROOT_PASSWORD" 
    echo "   • API secret saved in .env file"
    echo
    
    # Special warning about Docker permissions
    if [ -f "/var/run/docker.sock" ]; then
        current_perms=$(stat -c "%a" /var/run/docker.sock)
        if [ "$current_perms" = "666" ]; then
            echo
            print_color $RED "🚨 SECURITY WARNING:"
            print_warning "Docker socket permissions temporarily changed to complete installation"
            print_warning "Execute ./fix-docker-permissions.sh to fix this"
            print_warning "Or re-login to apply docker group permissions"
        fi
    fi
    
    print_color $GREEN "🎯 Ready to use!"
}

# Main function
main() {
    print_header "NOTESNOOK SELF-HOSTED SERVER INSTALLER v2.3"
    print_info "Automated installation of Notesnook sync server"
    print_info "Based on: https://sh.itjust.works/post/13411056"
    echo
    
    # Preliminary checks
    check_root
    check_sudo
    check_os
    
    # Configuration collection
    collect_config
    
    # Installation process
    update_system
    install_docker
    install_nginx
    configure_firewall
    create_directories
    download_web_app
    create_config_files
    pull_images
    start_services
    configure_nginx_http
    check_dns_records
    test_http_access
    get_ssl_certificates
    restart_docker_services
    create_management_utilities
    final_system_check
    show_final_info
    
    print_header "🚀 INSTALLATION SUCCESSFULLY COMPLETED!"
}

# Error handling
trap 'print_error "An error occurred at line $LINENO. Terminating."; exit 1' ERR

# Run main function
main "$@"
