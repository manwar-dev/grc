#!/bin/bash

################################################################################
# GRC Microservices Installation Script
#
# This script installs all dependencies and sets up the GRC microservices
# platform on a fresh Ubuntu/Debian-based Linux system.
#
# Services included:
#   - back (Port 9090)
#   - notification-service (Port 6060)
#   - user-service (Port 7070)
#   - regulator-service (Port 3030)
#   - strategic-plan-service
#   - kpis
#   - front (Vue.js Frontend)
#
# Requirements: Ubuntu 20.04+ or Debian 11+
# Run as: sudo bash install-grc-microservices.sh
################################################################################

set -e  # Exit on error

# Set non-interactive mode for all package installations
export DEBIAN_FRONTEND=noninteractive
export COMPOSER_ALLOW_SUPERUSER=1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run with sudo privileges"
    log_error "Please run: sudo bash $0"
    exit 1
fi

# Detect if running with sudo (SUDO_USER will be set if using sudo)
if [ -n "$SUDO_USER" ]; then
    log_info "Running with sudo (original user: $SUDO_USER)"
else
    log_info "Running as root user"
fi

# Configuration
PROJECT_DIR="/var/www/html/grc"
PHP_VERSION="8.2"
NODE_VERSION="20"
MONGODB_VERSION="7.0"

# Get user home directory (works with sudo)
ORIGINAL_USER=${SUDO_USER:-$USER}
USER_HOME=$(eval echo ~${ORIGINAL_USER})
if [ "$USER_HOME" = "~" ] || [ -z "$USER_HOME" ]; then
    USER_HOME=$(getent passwd ${ORIGINAL_USER} | cut -d: -f6)
fi
# Fallback to /home/ubuntu or /root if user home not found
if [ -z "$USER_HOME" ] || [ ! -d "$USER_HOME" ]; then
    if [ -n "$ORIGINAL_USER" ] && [ "$ORIGINAL_USER" != "root" ]; then
        USER_HOME="/home/${ORIGINAL_USER}"
    else
        USER_HOME="/root"
    fi
fi

# Default branch configuration
DEFAULT_BRANCH="v1.0.0"

# Get server IP and domain
SERVER_IP=$(hostname -I | awk '{print $1}' || curl -s ifconfig.me || echo "127.0.0.1")
SERVER_DOMAIN=""

log_info "Starting GRC Microservices Installation..."
log_info "Installation Directory: $PROJECT_DIR"

################################################################################
# 0. Configuration Setup
################################################################################
log_info "Step 0/13: Configuration setup..."

# Ask for domain name
echo ""
echo "=========================================="
echo "Server Configuration"
echo "=========================================="
echo ""
echo "Server IP detected: ${SERVER_IP}"
read -p "Enter your domain name (or press Enter to use IP: ${SERVER_IP}): " SERVER_DOMAIN
if [ -z "$SERVER_DOMAIN" ]; then
    SERVER_DOMAIN="$SERVER_IP"
    log_info "Using IP address: ${SERVER_DOMAIN}"
else
    log_info "Using domain: ${SERVER_DOMAIN}"
fi
echo ""

################################################################################
# 1. System Update
################################################################################
log_info "Step 1/13: Updating system packages..."
apt-get update -qq -y
apt-get upgrade -qq -y

################################################################################
# 2. Install Essential Tools
################################################################################
log_info "Step 2/13: Installing essential tools..."
apt-get install -qq -y \
    curl \
    wget \
    git \
    unzip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    build-essential

################################################################################
# 2.1. Setup Git Authentication
################################################################################
log_info "Step 2.1/13: Setting up Git authentication..."

# Function to install GitHub CLI
install_github_cli() {
    log_info "Installing GitHub CLI..."
    
    # Check if gh is already installed
    if command -v gh &> /dev/null; then
        log_info "GitHub CLI is already installed"
        gh --version
        return 0
    fi
    
    # Install GitHub CLI GPG key
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
        gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg
    
    if [ ! -f /usr/share/keyrings/githubcli-archive-keyring.gpg ]; then
        log_error "Failed to download GitHub CLI GPG key"
        return 1
    fi
    
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
        tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    
    apt-get update -y
    apt-get install -y gh
    
    # Verify installation
    if command -v gh &> /dev/null; then
        log_info "GitHub CLI installed successfully"
        gh --version
        return 0
    else
        log_error "Failed to install GitHub CLI"
        return 1
    fi
}

# Function to authenticate with GitHub CLI
authenticate_with_github_cli() {
    log_info "Authenticating with GitHub CLI..."
    
    # Switch to the original user (not root) for GitHub CLI auth
    # GitHub CLI doesn't work well as root
    ORIGINAL_USER=${SUDO_USER:-$USER}
    
    if [ "$ORIGINAL_USER" = "root" ] || [ -z "$ORIGINAL_USER" ]; then
        log_warn "Cannot use GitHub CLI as root. Switching to username/password method."
        return 1
    fi
    
    log_info "Note: GitHub CLI authentication will run as user: $ORIGINAL_USER"
    log_info "Please follow the prompts to authenticate..."
    
    # Run gh auth login as the original user
    if sudo -u "$ORIGINAL_USER" gh auth login; then
        log_info "GitHub CLI authentication successful"
        
        # Verify authentication
        if sudo -u "$ORIGINAL_USER" gh auth status &> /dev/null; then
            log_info "GitHub authentication verified"
            
            # Configure Git to use GitHub CLI credential helper
            log_info "Configuring Git to use GitHub CLI credential helper..."
            
            # Get the token from GitHub CLI for the original user
            GH_TOKEN=$(sudo -u "$ORIGINAL_USER" gh auth token 2>/dev/null)
            
            if [ -n "$GH_TOKEN" ]; then
                # Configure Git credential helper to use GitHub CLI
                git config --global credential.helper store
                
                # Store GitHub CLI token as credential for GitHub
                # Format: https://[username]:[token]@github.com
                GITHUB_USER=$(sudo -u "$ORIGINAL_USER" gh api user --jq .login 2>/dev/null || echo "git")
                mkdir -p "${USER_HOME}"
                echo "https://${GITHUB_USER}:${GH_TOKEN}@github.com" > "${USER_HOME}/.git-credentials"
                chmod 600 "${USER_HOME}/.git-credentials"
                # Also copy to root for git operations as sudo
                echo "https://${GITHUB_USER}:${GH_TOKEN}@github.com" > /root/.git-credentials
                chmod 600 /root/.git-credentials
                
                log_info "Git configured to use GitHub CLI credentials (user: ${GITHUB_USER})"
                return 0
            else
                log_warn "Could not retrieve GitHub CLI token, but authentication succeeded"
                log_warn "Git operations may prompt for credentials"
                return 0
            fi
        else
            log_error "GitHub authentication verification failed"
            return 1
        fi
    else
        log_error "GitHub CLI authentication failed"
        return 1
    fi
}

# Function to authenticate with username/password
authenticate_with_credentials() {
    log_info "Setting up Git authentication with username and password..."
    
    # Get Git username
    read -p "Enter your Git username (GitHub/GitLab username): " GIT_USERNAME
    
    if [ -z "$GIT_USERNAME" ]; then
        log_error "Git username is required"
        return 1
    fi
    
    # Get Git password or token
    echo "Note: For GitHub, use a Personal Access Token (PAT) instead of password"
    echo "Create a token at: https://github.com/settings/tokens"
    read -sp "Enter your Git password/token: " GIT_PASSWORD
    echo ""
    
    if [ -z "$GIT_PASSWORD" ]; then
        log_error "Git password/token is required"
        return 1
    fi
    
    # Configure Git credential helper
    git config --global credential.helper store
    
    # Store credentials (format: https://username:password@github.com)
    mkdir -p "${USER_HOME}"
    echo "https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com" > "${USER_HOME}/.git-credentials"
    chmod 600 "${USER_HOME}/.git-credentials"
    # Also copy to root for git operations as sudo
    echo "https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com" > /root/.git-credentials
    chmod 600 /root/.git-credentials
    
    # Set Git username
    git config --global user.name "$GIT_USERNAME"
    
    # Test authentication with a simple API call
    log_info "Testing Git authentication..."
    TEST_RESPONSE=$(curl -s -u "${GIT_USERNAME}:${GIT_PASSWORD}" https://api.github.com/user 2>&1)
    
    if echo "$TEST_RESPONSE" | grep -q '"login"'; then
        log_info "Git authentication verified successfully"
        return 0
    else
        log_warn "Could not verify Git authentication automatically"
        log_info "Credentials have been saved. Authentication will be tested when cloning repositories."
        log_info "If you encounter issues, verify your token has the correct permissions"
        return 0
    fi
}

# Ask user which authentication method to use
echo ""
echo "=========================================="
echo "Git Authentication Setup"
echo "=========================================="
echo ""
echo "Choose Git authentication method:"
echo "  1) GitHub CLI (gh auth login) - Recommended, more secure"
echo "  2) Username and Password/Token"
echo ""
read -p "Enter your choice (1 or 2): " AUTH_CHOICE

case $AUTH_CHOICE in
    1)
        log_info "Using GitHub CLI authentication..."
        if install_github_cli; then
            if authenticate_with_github_cli; then
                log_info "Git authentication setup completed using GitHub CLI"
            else
                log_warn "GitHub CLI authentication failed. Falling back to username/password method."
                if authenticate_with_credentials; then
                    log_info "Git authentication setup completed using username/password"
                else
                    log_error "Git authentication setup failed"
                    exit 1
                fi
            fi
        else
            log_warn "Failed to install GitHub CLI. Falling back to username/password method."
            if authenticate_with_credentials; then
                log_info "Git authentication setup completed using username/password"
            else
                log_error "Git authentication setup failed"
                exit 1
            fi
        fi
        ;;
    2)
        log_info "Using username/password authentication..."
        if authenticate_with_credentials; then
            log_info "Git authentication setup completed"
        else
            log_error "Git authentication setup failed"
            exit 1
        fi
        ;;
    *)
        log_error "Invalid choice. Please run the script again and select 1 or 2."
        exit 1
        ;;
esac

echo ""

################################################################################
# 3. Clone/Pull GRC Service Repositories
################################################################################
log_info "Step 3/13: Cloning/pulling GRC service repositories from GitHub..."

# Ask for branch to use for all repositories
echo ""
echo "=========================================="
echo "Branch Configuration"
echo "=========================================="
echo ""
read -p "Enter branch/tag to use for all repositories [default: ${DEFAULT_BRANCH}]: " REPO_BRANCH
REPO_BRANCH=${REPO_BRANCH:-$DEFAULT_BRANCH}
log_info "Using branch/tag: $REPO_BRANCH for all repositories"
echo ""

# Function to clone individual service repositories directly
clone_grc_repositories() {
    log_info "Setting up GRC service repositories..."
    
    # Create project directory if it doesn't exist
    mkdir -p "$PROJECT_DIR"
    cd "$PROJECT_DIR"
    
    # Check if GitHub CLI is authenticated and available
    USE_GH_CLONE=false
    ORIGINAL_USER=${SUDO_USER:-$USER}
    if [ -n "$ORIGINAL_USER" ] && [ "$ORIGINAL_USER" != "root" ]; then
        if sudo -u "$ORIGINAL_USER" gh auth status &> /dev/null; then
            USE_GH_CLONE=true
            log_info "GitHub CLI authenticated - will use 'gh' commands for repository operations"
        fi
    fi
    
    # Define repositories (using the selected branch for all)
    declare -A REPO_URLS=(
        ["back"]="PKKSA/BackEndStarterKit"
        ["notification-service"]="PKKSA/NotificationAndLogsBackEnd"
        ["user-service"]="PKKSA/User-Service-BackEnd"
        ["regulator-service"]="PKKSA/Regulator-Service"
        ["strategic-plan-service"]="PKKSA/StrategicPlanService"
        ["kpis"]="PKKSA/kpis"
        ["front"]="PKKSA/Front-Stater-Kit"
    )
    
    # Configure Git safe directories to avoid dubious ownership errors when using sudo
    log_info "Configuring Git safe directories..."
    git config --global --add safe.directory "$PROJECT_DIR/back" 2>/dev/null || true
    git config --global --add safe.directory "$PROJECT_DIR/notification-service" 2>/dev/null || true
    git config --global --add safe.directory "$PROJECT_DIR/user-service" 2>/dev/null || true
    git config --global --add safe.directory "$PROJECT_DIR/regulator-service" 2>/dev/null || true
    git config --global --add safe.directory "$PROJECT_DIR/strategic-plan-service" 2>/dev/null || true
    git config --global --add safe.directory "$PROJECT_DIR/kpis" 2>/dev/null || true
    git config --global --add safe.directory "$PROJECT_DIR/front" 2>/dev/null || true
    git config --global --add safe.directory '*' 2>/dev/null || true
    
    # Configure Git to use credentials from GitHub CLI
    ORIGINAL_USER=${SUDO_USER:-$USER}
    if [ -n "$ORIGINAL_USER" ] && [ "$ORIGINAL_USER" != "root" ]; then
        # Try to get GitHub CLI token
        GH_TOKEN=$(sudo -u "$ORIGINAL_USER" gh auth token 2>/dev/null)
        if [ -n "$GH_TOKEN" ]; then
            GITHUB_USER=$(sudo -u "$ORIGINAL_USER" gh api user --jq .login 2>/dev/null || echo "")
            if [ -n "$GITHUB_USER" ]; then
                log_info "Configuring Git to use GitHub CLI credentials (user: ${GITHUB_USER})"
                git config --global credential.helper store
                mkdir -p "${USER_HOME}"
                echo "https://${GITHUB_USER}:${GH_TOKEN}@github.com" > "${USER_HOME}/.git-credentials"
                chmod 600 "${USER_HOME}/.git-credentials"
                # Also copy to root for git operations as sudo
                echo "https://${GITHUB_USER}:${GH_TOKEN}@github.com" > /root/.git-credentials
                chmod 600 /root/.git-credentials
            fi
        fi
    fi
    
    # Fallback to stored credentials if available
    if [ -f "${USER_HOME}/.git-credentials" ]; then
        git config --global credential.helper store
        # Also copy to root
        cp "${USER_HOME}/.git-credentials" /root/.git-credentials 2>/dev/null || true
        chmod 600 /root/.git-credentials
    elif [ -f /root/.git-credentials ]; then
        git config --global credential.helper store
    fi
    
    # Clone or update each repository
    for SERVICE in "${!REPO_URLS[@]}"; do
        REPO_SLUG="${REPO_URLS[$SERVICE]}"
        REPO_URL="https://github.com/${REPO_SLUG}.git"
        SERVICE_PATH="${PROJECT_DIR}/${SERVICE}"
        
        # Add safe directory for this specific service
        git config --global --add safe.directory "$SERVICE_PATH" 2>/dev/null || true
        
        log_info "Setting up ${SERVICE} repository..."
        
        if [ -d "$SERVICE_PATH/.git" ]; then
            log_info "Repository ${SERVICE} already exists. Updating to branch: ${REPO_BRANCH}..."
            cd "$SERVICE_PATH"
            
            # Fix remote URL if it has double slashes
            CURRENT_REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
            if [[ "$CURRENT_REMOTE" == *"//github"* ]]; then
                FIXED_REMOTE=$(echo "$CURRENT_REMOTE" | sed 's|//github|https://github|g' | sed 's|https://https://|https://|g')
                git remote set-url origin "$FIXED_REMOTE"
                log_info "Fixed remote URL for ${SERVICE}: $FIXED_REMOTE"
            fi
            
            # Update remote URL if needed
            git remote set-url origin "$REPO_URL" 2>/dev/null || git remote add origin "$REPO_URL"
            
            # Use gh to pull if authenticated, otherwise use git
            if [ "$USE_GH_CLONE" = true ]; then
                log_info "Using GitHub CLI to update ${SERVICE} to branch: ${REPO_BRANCH}..."
                # Fetch using gh
                if sudo -u "$ORIGINAL_USER" gh repo sync "$REPO_SLUG" --branch "$REPO_BRANCH" --force 2>/dev/null; then
                    # Checkout the branch
                    git fetch origin "$REPO_BRANCH" 2>/dev/null || git fetch origin
                    git checkout "$REPO_BRANCH" 2>/dev/null || git checkout -b "$REPO_BRANCH" "origin/$REPO_BRANCH" 2>/dev/null
                    git reset --hard "origin/$REPO_BRANCH" 2>/dev/null || true
                    log_info "${SERVICE} updated successfully using GitHub CLI (branch: ${REPO_BRANCH})"
                else
                    # Fallback to git pull
                    log_warn "GitHub CLI sync failed, falling back to git pull..."
                    git fetch origin "$REPO_BRANCH" 2>/dev/null || git fetch origin
                    git checkout "$REPO_BRANCH" 2>/dev/null || git checkout -b "$REPO_BRANCH" "origin/$REPO_BRANCH" 2>/dev/null
                    git pull origin "$REPO_BRANCH" 2>/dev/null || log_warn "Failed to pull for ${SERVICE}"
                fi
            else
                # Use regular git commands
                git fetch origin "$REPO_BRANCH" 2>/dev/null || git fetch origin
                git checkout "$REPO_BRANCH" 2>/dev/null || git checkout -b "$REPO_BRANCH" "origin/$REPO_BRANCH" 2>/dev/null
                git pull origin "$REPO_BRANCH" 2>/dev/null || log_warn "Failed to pull for ${SERVICE}"
            fi
            
            cd "$PROJECT_DIR"
        else
            log_info "Cloning ${SERVICE} from ${REPO_SLUG} (branch: ${REPO_BRANCH})..."
            
            # Remove directory if it exists but is not a git repo
            if [ -d "$SERVICE_PATH" ]; then
                log_warn "Directory $SERVICE_PATH exists but is not a git repository"
                rm -rf "$SERVICE_PATH"
            fi
            
            # Use gh to clone if authenticated, otherwise use git
            if [ "$USE_GH_CLONE" = true ]; then
                log_info "Using GitHub CLI to clone ${SERVICE}..."
                cd "$PROJECT_DIR"
                if sudo -u "$ORIGINAL_USER" gh repo clone "$REPO_SLUG" "$SERVICE" -- --branch "$REPO_BRANCH" 2>&1; then
                    # Fix ownership if needed
                    chown -R "$ORIGINAL_USER:$ORIGINAL_USER" "$SERVICE_PATH" 2>/dev/null || true
                    # Add safe directory after cloning
                    git config --global --add safe.directory "$SERVICE_PATH" 2>/dev/null || true
                    log_info "${SERVICE} cloned successfully using GitHub CLI (branch: ${REPO_BRANCH})"
                else
                    log_warn "GitHub CLI clone failed, falling back to git clone..."
                    # Fallback to git clone
                    if git clone -b "$REPO_BRANCH" "$REPO_URL" "$SERVICE" 2>&1; then
                        git config --global --add safe.directory "$SERVICE_PATH" 2>/dev/null || true
                        log_info "${SERVICE} cloned successfully (branch: ${REPO_BRANCH})"
                    else
                        log_error "Failed to clone ${SERVICE} from ${REPO_SLUG}"
                        log_error "Check if:"
                        log_error "  1. Repository exists: ${REPO_SLUG}"
                        log_error "  2. Branch '${REPO_BRANCH}' exists"
                        log_error "  3. Git authentication is working"
                        log_warn "Continuing with other repositories..."
                    fi
                fi
            else
                # Use regular git clone
                if git clone -b "$REPO_BRANCH" "$REPO_URL" "$SERVICE" 2>&1; then
                    git config --global --add safe.directory "$SERVICE_PATH" 2>/dev/null || true
                    log_info "${SERVICE} cloned successfully (branch: ${REPO_BRANCH})"
                else
                    log_error "Failed to clone ${SERVICE} from ${REPO_SLUG}"
                    log_error "Check if:"
                    log_error "  1. Repository exists: ${REPO_SLUG}"
                    log_error "  2. Branch '${REPO_BRANCH}' exists"
                    log_error "  3. Git authentication is working"
                    log_warn "Continuing with other repositories..."
                fi
            fi
        fi
    done
    
    # Verify all services are present
    log_info "Verifying service directories..."
    SERVICES=("back" "notification-service" "user-service" "regulator-service" "strategic-plan-service" "kpis" "front")
    MISSING_SERVICES=()
    
    for SERVICE in "${SERVICES[@]}"; do
        if [ ! -d "$PROJECT_DIR/$SERVICE" ]; then
            MISSING_SERVICES+=("$SERVICE")
        fi
    done
    
    if [ ${#MISSING_SERVICES[@]} -eq 0 ]; then
        log_info "All service directories are present"
        return 0
    else
        log_warn "Some service directories are missing: ${MISSING_SERVICES[*]}"
        log_warn "Continuing installation, but these services may not be set up correctly"
        return 0
    fi
}

# Configure Git to use credentials for submodules
configure_git_for_submodules() {
    log_info "Configuring Git for submodule authentication..."
    
    # Check if we're using GitHub CLI authentication
    ORIGINAL_USER=${SUDO_USER:-$USER}
    if [ "$ORIGINAL_USER" != "root" ] && [ -n "$ORIGINAL_USER" ]; then
        if sudo -u "$ORIGINAL_USER" gh auth status &> /dev/null; then
            log_info "GitHub CLI authentication detected"
            log_info "Submodules will use GitHub CLI authentication automatically"
            # Configure git to use GitHub CLI for authentication
            git config --global credential.helper store
            # GitHub CLI handles authentication, so submodules should work
            return 0
        fi
    fi
    
    # If using credential helper (username/password method)
    if [ -f /root/.git-credentials ]; then
        log_info "Configuring Git credential helper for submodules..."
        git config --global credential.helper store
        
        # Read credentials from stored file
        CREDENTIALS=$(cat /root/.git-credentials | grep "@github.com" | head -1)
        if [ -n "$CREDENTIALS" ]; then
            # Extract username and password/token from credentials
            # Format: https://username:password@github.com
            log_info "Credentials found, submodules will use authenticated URLs"
        fi
        return 0
    fi
    
    log_warn "No Git credentials found, submodules may fail to clone if repositories are private"
    return 0
}

# Run repository setup
configure_git_for_submodules

if clone_grc_repositories; then
    log_info "GRC service repositories setup completed successfully"
    echo ""
else
    log_error "Failed to setup GRC service repositories"
    log_error "Installation cannot continue without the repositories"
    exit 1
fi

################################################################################
# 4. Install PHP 8.2+
################################################################################
log_info "Step 4/13: Installing PHP ${PHP_VERSION}..."

# Add PHP repository
add-apt-repository -y ppa:ondrej/php
apt-get update -qq -y

# Install PHP and extensions
apt-get install -qq -y \
    php${PHP_VERSION} \
    php${PHP_VERSION}-cli \
    php${PHP_VERSION}-fpm \
    php${PHP_VERSION}-common \
    php${PHP_VERSION}-mysql \
    php${PHP_VERSION}-zip \
    php${PHP_VERSION}-gd \
    php${PHP_VERSION}-mbstring \
    php${PHP_VERSION}-curl \
    php${PHP_VERSION}-xml \
    php${PHP_VERSION}-bcmath \
    php${PHP_VERSION}-intl \
    php${PHP_VERSION}-mongodb \
    php${PHP_VERSION}-dev

# Verify PHP installation
php -v

################################################################################
# 5. Install Composer
################################################################################
log_info "Step 5/13: Installing Composer..."

EXPECTED_SIGNATURE="$(wget -q -O - https://composer.github.io/installer.sig)"
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
ACTUAL_SIGNATURE="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"

if [ "$EXPECTED_SIGNATURE" != "$ACTUAL_SIGNATURE" ]; then
    log_error "Invalid Composer installer signature"
    rm composer-setup.php
    exit 1
fi

php composer-setup.php --quiet --install-dir=/usr/local/bin --filename=composer --no-ansi
rm composer-setup.php

composer --version

################################################################################
# 6. Install MongoDB
################################################################################
log_info "Step 6/13: Installing MongoDB ${MONGODB_VERSION}..."

# Import MongoDB public GPG key (remove existing file first to avoid prompt)
rm -f /usr/share/keyrings/mongodb-server-${MONGODB_VERSION}.gpg 2>/dev/null
curl -fsSL https://www.mongodb.org/static/pgp/server-${MONGODB_VERSION}.asc | \
    gpg --batch --yes -o /usr/share/keyrings/mongodb-server-${MONGODB_VERSION}.gpg --dearmor

# Create MongoDB list file
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-${MONGODB_VERSION}.gpg ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/${MONGODB_VERSION} multiverse" | \
    tee /etc/apt/sources.list.d/mongodb-org-${MONGODB_VERSION}.list

# Update and install MongoDB
apt-get update -qq -y
apt-get install -qq -y mongodb-org

# Start and enable MongoDB
systemctl start mongod
systemctl enable mongod

# Verify MongoDB installation
mongod --version

# Wait for MongoDB to be ready
sleep 5

################################################################################
# 7. Install Node.js and npm
################################################################################
log_info "Step 7/13: Installing Node.js ${NODE_VERSION}..."

# Install Node.js LTS
curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -
apt-get install -qq -y nodejs

# Verify installation
node -v
npm -v

################################################################################
# 8. Install Supervisor
################################################################################
log_info "Step 8/13: Installing Supervisor..."

apt-get install -qq -y supervisor

# Start and enable Supervisor
systemctl start supervisor
systemctl enable supervisor >/dev/null 2>&1

# Verify Supervisor installation
supervisord --version

################################################################################
# 9. Install Web Server (Nginx)
################################################################################
log_info "Step 9/13: Installing Nginx..."

apt-get install -qq -y nginx

# Stop Nginx for now (will configure later)
systemctl stop nginx

# Function to ensure database config file exists with MongoDB configuration
ensure_database_config() {
    local SERVICE_PATH=$1
    local CONFIG_DIR="${SERVICE_PATH}/config"
    local DB_CONFIG_FILE="${CONFIG_DIR}/database.php"
    
    # Create config directory if it doesn't exist
    if [ ! -d "$CONFIG_DIR" ]; then
        log_info "Creating config directory for ${SERVICE_PATH}..."
        mkdir -p "$CONFIG_DIR"
    fi
    
    # Check if database.php exists
    if [ ! -f "$DB_CONFIG_FILE" ]; then
        log_info "Creating database.php config file for ${SERVICE_PATH}..."
        cat > "$DB_CONFIG_FILE" <<'DBCONFIG'
<?php

use Illuminate\Support\Str;

return [

    'default' => env('DB_CONNECTION', 'mongodb'),

    'connections' => [

        'sqlite' => [
            'driver' => 'sqlite',
            'url' => env('DATABASE_URL'),
            'database' => env('DB_DATABASE', database_path('database.sqlite')),
            'prefix' => '',
            'foreign_key_constraints' => env('DB_FOREIGN_KEYS', true),
        ],

        'mysql' => [
            'driver' => 'mysql',
            'url' => env('DATABASE_URL'),
            'host' => env('DB_HOST', '127.0.0.1'),
            'port' => env('DB_PORT', '3306'),
            'database' => env('DB_DATABASE', 'forge'),
            'username' => env('DB_USERNAME', 'forge'),
            'password' => env('DB_PASSWORD', ''),
            'unix_socket' => env('DB_SOCKET', ''),
            'charset' => 'utf8mb4',
            'collation' => 'utf8mb4_unicode_ci',
            'prefix' => '',
            'prefix_indexes' => true,
            'strict' => true,
            'engine' => null,
            'options' => extension_loaded('pdo_mysql') ? array_filter([
                PDO::MYSQL_ATTR_SSL_CA => env('MYSQL_ATTR_SSL_CA'),
            ]) : [],
        ],

        'pgsql' => [
            'driver' => 'pgsql',
            'url' => env('DATABASE_URL'),
            'host' => env('DB_HOST', '127.0.0.1'),
            'port' => env('DB_PORT', '5432'),
            'database' => env('DB_DATABASE', 'forge'),
            'username' => env('DB_USERNAME', 'forge'),
            'password' => env('DB_PASSWORD', ''),
            'charset' => 'utf8',
            'prefix' => '',
            'prefix_indexes' => true,
            'search_path' => 'public',
            'sslmode' => 'prefer',
        ],

        'mongodb' => [
            'driver'   => 'mongodb',
            'host'     => env('DB_HOST', '127.0.0.1'),
            'port'     => env('DB_PORT', 27017),
            'database' => env('DB_DATABASE'),
            'username' => env('DB_USERNAME'),
            'password' => env('DB_PASSWORD'),
            'options'  => [
                'ssl' => env('DB_SSL', false),
            ],
        ],

    ],

    'migrations' => 'migrations',

    'redis' => [
        'client' => env('REDIS_CLIENT', 'phpredis'),
        'options' => [
            'cluster' => env('REDIS_CLUSTER', 'redis'),
            'prefix' => env('REDIS_PREFIX', Str::slug(env('APP_NAME', 'laravel'), '_').'_database_'),
        ],
        'default' => [
            'url' => env('REDIS_URL'),
            'host' => env('REDIS_HOST', '127.0.0.1'),
            'username' => env('REDIS_USERNAME'),
            'password' => env('REDIS_PASSWORD'),
            'port' => env('REDIS_PORT', '6379'),
            'database' => env('REDIS_DB', '0'),
        ],
        'cache' => [
            'url' => env('REDIS_URL'),
            'host' => env('REDIS_HOST', '127.0.0.1'),
            'username' => env('REDIS_USERNAME'),
            'password' => env('REDIS_PASSWORD'),
            'port' => env('REDIS_PORT', '6379'),
            'database' => env('REDIS_CACHE_DB', '1'),
        ],
    ],

];
DBCONFIG
        log_info "database.php config file created with MongoDB configuration"
    else
        # Check if MongoDB connection exists in the file
        if ! grep -q "'mongodb' =>" "$DB_CONFIG_FILE" 2>/dev/null; then
            log_info "Adding MongoDB connection to existing database.php..."
            # Try to add MongoDB config before closing bracket of connections array
            # Find the last connection before the closing bracket
            if grep -q "'connections' =>" "$DB_CONFIG_FILE" 2>/dev/null; then
                # Use a safer approach: add MongoDB config after the last connection
                perl -i -pe "s/(]\s*,?\s*)$/'mongodb' => [\n            'driver'   => 'mongodb',\n            'host'     => env('DB_HOST', '127.0.0.1'),\n            'port'     => env('DB_PORT', 27017),\n            'database' => env('DB_DATABASE'),\n            'username' => env('DB_USERNAME'),\n            'password' => env('DB_PASSWORD'),\n            'options'  => [\n                'ssl' => env('DB_SSL', false),\n            ],\n        ],\n        \1/" "$DB_CONFIG_FILE" 2>/dev/null || log_warn "Could not automatically add MongoDB config"
            fi
        else
            log_info "MongoDB connection already configured in database.php"
        fi
    fi
}

################################################################################
# 10. Setup Laravel Microservices
################################################################################
log_info "Step 10/13: Setting up Laravel microservices..."

# Service configuration (port, database)
declare -A SERVICE_PORTS=(
    ["back"]="9090"
    ["notification-service"]="6060"
    ["user-service"]="7070"
    ["regulator-service"]="3030"
    ["strategic-plan-service"]="8080"
    ["kpis"]="5050"
)

declare -A SERVICE_DATABASES=(
    ["back"]="grc"
    ["notification-service"]="notification_grc_db"
    ["user-service"]="GRC_USER_SERVICE"
    ["regulator-service"]="GRC_Regulator_Service"
    ["strategic-plan-service"]="grc"
    ["kpis"]="grc-kpi"
)

# Function to configure .env file for a service
configure_service_env() {
    local SERVICE=$1
    local PORT=$2
    local DATABASE=$3
    local ENV_FILE="${PROJECT_DIR}/${SERVICE}/.env"
    
    if [ ! -f "$ENV_FILE" ]; then
        log_warn ".env file not found for ${SERVICE}, skipping configuration"
        return 1
    fi
    
    log_info "Configuring .env for ${SERVICE}..."
    
    # Determine protocol (http or https)
    PROTOCOL="http"
    if [[ "$SERVER_DOMAIN" != *"127.0.0.1"* ]] && [[ "$SERVER_DOMAIN" != *"localhost"* ]] && [[ "$SERVER_DOMAIN" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        PROTOCOL="http"
    elif [[ "$SERVER_DOMAIN" != *"127.0.0.1"* ]] && [[ "$SERVER_DOMAIN" != *"localhost"* ]]; then
        PROTOCOL="https"
    fi
    
    BASE_URL="${PROTOCOL}://${SERVER_DOMAIN}"
    SERVICE_URL="${BASE_URL}/api/${SERVICE}"
    
    # Update APP_URL
    if grep -q "^APP_URL=" "$ENV_FILE" 2>/dev/null; then
        sed -i "s|^APP_URL=.*|APP_URL=${BASE_URL}|" "$ENV_FILE"
    else
        echo "APP_URL=${BASE_URL}" >> "$ENV_FILE"
    fi
    
    # Update database configuration
    if grep -q "^DB_DATABASE=" "$ENV_FILE" 2>/dev/null; then
        sed -i "s|^DB_DATABASE=.*|DB_DATABASE=${DATABASE}|" "$ENV_FILE"
    else
        echo "DB_DATABASE=${DATABASE}" >> "$ENV_FILE"
    fi
    
    # Ensure MongoDB connection settings are properly configured
    # MongoDB connection requires: host, port, database, and optionally username/password
    if ! grep -q "^DB_CONNECTION=" "$ENV_FILE" 2>/dev/null; then
        echo "DB_CONNECTION=mongodb" >> "$ENV_FILE"
    else
        # Update if exists
        sed -i "s|^DB_CONNECTION=.*|DB_CONNECTION=mongodb|" "$ENV_FILE"
    fi
    
    if ! grep -q "^DB_HOST=" "$ENV_FILE" 2>/dev/null; then
        echo "DB_HOST=127.0.0.1" >> "$ENV_FILE"
    else
        sed -i "s|^DB_HOST=.*|DB_HOST=127.0.0.1|" "$ENV_FILE"
    fi
    
    if ! grep -q "^DB_PORT=" "$ENV_FILE" 2>/dev/null; then
        echo "DB_PORT=27017" >> "$ENV_FILE"
    else
        sed -i "s|^DB_PORT=.*|DB_PORT=27017|" "$ENV_FILE"
    fi
    
    # Ensure DB_DATABASE is set (required for MongoDB connection)
    if ! grep -q "^DB_DATABASE=" "$ENV_FILE" 2>/dev/null; then
        echo "DB_DATABASE=${DATABASE}" >> "$ENV_FILE"
    else
        sed -i "s|^DB_DATABASE=.*|DB_DATABASE=${DATABASE}|" "$ENV_FILE"
    fi
    
    # Set MongoDB username and password if not set (can be empty for local MongoDB)
    if ! grep -q "^DB_USERNAME=" "$ENV_FILE" 2>/dev/null; then
        echo "DB_USERNAME=" >> "$ENV_FILE"
    fi
    if ! grep -q "^DB_PASSWORD=" "$ENV_FILE" 2>/dev/null; then
        echo "DB_PASSWORD=" >> "$ENV_FILE"
    fi
    
    # Update service URLs based on service type
    case $SERVICE in
        "back")
            if grep -q "^USER_SERVICE_URL=" "$ENV_FILE" 2>/dev/null; then
                sed -i "s|^USER_SERVICE_URL=.*|USER_SERVICE_URL=${BASE_URL}/api/user-service|" "$ENV_FILE"
            fi
            if grep -q "^NOTIFICATION_SERVICE_URL=" "$ENV_FILE" 2>/dev/null; then
                sed -i "s|^NOTIFICATION_SERVICE_URL=.*|NOTIFICATION_SERVICE_URL=${BASE_URL}/api/notification-service|" "$ENV_FILE"
            fi
            ;;
        "notification-service")
            if grep -q "^USER_SERVICE_URL=" "$ENV_FILE" 2>/dev/null; then
                sed -i "s|^USER_SERVICE_URL=.*|USER_SERVICE_URL=${BASE_URL}/api/user-service|" "$ENV_FILE"
            fi
            # Configure Reverb WebSocket
            if grep -q "^REVERB_HOST=" "$ENV_FILE" 2>/dev/null; then
                sed -i "s|^REVERB_HOST=.*|REVERB_HOST=0.0.0.0|" "$ENV_FILE"
            else
                echo "REVERB_HOST=0.0.0.0" >> "$ENV_FILE"
            fi
            if grep -q "^REVERB_PORT=" "$ENV_FILE" 2>/dev/null; then
                sed -i "s|^REVERB_PORT=.*|REVERB_PORT=9000|" "$ENV_FILE"
            else
                echo "REVERB_PORT=9000" >> "$ENV_FILE"
            fi
            if grep -q "^REVERB_SCHEME=" "$ENV_FILE" 2>/dev/null; then
                sed -i "s|^REVERB_SCHEME=.*|REVERB_SCHEME=${PROTOCOL}|" "$ENV_FILE"
            else
                echo "REVERB_SCHEME=${PROTOCOL}" >> "$ENV_FILE"
            fi
            if ! grep -q "^BROADCAST_DRIVER=" "$ENV_FILE" 2>/dev/null; then
                echo "BROADCAST_DRIVER=reverb" >> "$ENV_FILE"
            fi
            ;;
        "user-service")
            if grep -q "^NOTIFICATION_SERVICE_URL=" "$ENV_FILE" 2>/dev/null; then
                sed -i "s|^NOTIFICATION_SERVICE_URL=.*|NOTIFICATION_SERVICE_URL=${BASE_URL}/api/notification-service|" "$ENV_FILE"
            fi
            ;;
        "regulator-service")
            if grep -q "^NOTIFICATION_SERVICE_URL=" "$ENV_FILE" 2>/dev/null; then
                sed -i "s|^NOTIFICATION_SERVICE_URL=.*|NOTIFICATION_SERVICE_URL=${BASE_URL}/api/notification-service|" "$ENV_FILE"
            fi
            if grep -q "^USER_SERVICE_URL=" "$ENV_FILE" 2>/dev/null; then
                sed -i "s|^USER_SERVICE_URL=.*|USER_SERVICE_URL=${BASE_URL}/api/user-service|" "$ENV_FILE"
            fi
            ;;
    esac
    
    log_info "${SERVICE} .env configured"
}

# List of Laravel services
SERVICES=("back" "notification-service" "user-service" "regulator-service" "strategic-plan-service" "kpis")

for SERVICE in "${SERVICES[@]}"; do
    log_info "Setting up ${SERVICE}..."

    SERVICE_PATH="${PROJECT_DIR}/${SERVICE}"

    if [ ! -d "$SERVICE_PATH" ]; then
        log_warn "Service directory not found: ${SERVICE_PATH}"
        continue
    fi

    cd "$SERVICE_PATH"

    # Ensure git safe directory is set for this service (composer may need git)
    git config --global --add safe.directory "$SERVICE_PATH" 2>/dev/null || true

    # Ensure directory is writable by root (since we're running with sudo)
    # This is necessary for composer to write composer.lock and vendor directory
    chown -R root:root "$SERVICE_PATH" 2>/dev/null || true
    chmod -R u+w "$SERVICE_PATH" 2>/dev/null || true

    # Verify MongoDB extension is installed and enabled
    if php -m | grep -qi mongodb; then
        MONGODB_VERSION=$(php -r "echo phpversion('mongodb');" 2>/dev/null || echo "unknown")
        log_info "MongoDB PHP extension is installed (version: ${MONGODB_VERSION})"
    else
        log_warn "MongoDB PHP extension not found, installing via PECL..."
        # Install MongoDB extension via PECL if not found
        yes '' | pecl install mongodb 2>/dev/null || {
            log_error "Failed to install MongoDB extension via PECL"
            log_warn "Continuing with composer install, but MongoDB may not work..."
        }
        # Enable extension in PHP
        if [ -f "/etc/php/${PHP_VERSION}/cli/conf.d/" ]; then
            echo "extension=mongodb.so" | tee /etc/php/${PHP_VERSION}/cli/conf.d/20-mongodb.ini > /dev/null 2>&1
            if [ -d "/etc/php/${PHP_VERSION}/fpm/conf.d/" ]; then
                echo "extension=mongodb.so" | tee /etc/php/${PHP_VERSION}/fpm/conf.d/20-mongodb.ini > /dev/null 2>&1
            fi
        fi
    fi

    # Setup environment file if .env doesn't exist (BEFORE composer install/update)
    # Laravel post-install scripts need .env to be present
    if [ ! -f ".env" ]; then
        if [ -f ".env.example" ]; then
            log_info "Creating .env file from .env.example (before composer install)..."
            cp .env.example .env
        else
            log_warn ".env.example not found for ${SERVICE}, creating basic .env..."
            touch .env
        fi
    fi

    # Configure .env file with basic settings (needed for composer post-install scripts)
    SERVICE_PORT="${SERVICE_PORTS[$SERVICE]}"
    SERVICE_DB="${SERVICE_DATABASES[$SERVICE]}"
    configure_service_env "$SERVICE" "$SERVICE_PORT" "$SERVICE_DB"

    # Configure composer to allow insecure packages (for packages with security advisories)
    # This is necessary for packages like swiftmailer/swiftmailer that have known advisories
    # Set audit.block-insecure to false to allow packages with security advisories
    COMPOSER_ALLOW_SUPERUSER=1 composer config audit.block-insecure false 2>/dev/null || true
    # Also add swiftmailer advisories to ignore list if needed
    COMPOSER_ALLOW_SUPERUSER=1 composer config audit.ignore --json '["PKSA-tzjk-yn1s-49ds","PKSA-wtc8-zq3d-3wtm"]' 2>/dev/null || true

    # Install Composer dependencies
    log_info "Installing Composer dependencies for ${SERVICE}..."
    # Use --no-scripts initially to avoid Laravel post-install script errors before app key is generated
    INSTALL_EXIT_CODE=0
    if [ -f "composer.lock" ] && [ -f "composer.json" ]; then
        # Try install first WITHOUT ignoring platform requirements, but skip scripts
        COMPOSER_ALLOW_SUPERUSER=1 composer install --no-interaction --prefer-dist --optimize-autoloader --no-scripts --quiet --no-progress 2>&1 || INSTALL_EXIT_CODE=$?
        
        # If install failed due to platform requirements, try with ignore flag
        if [ ${INSTALL_EXIT_CODE} -ne 0 ]; then
            if composer install --dry-run --no-interaction --prefer-dist 2>&1 | grep -qi "ext-mongodb"; then
                log_info "MongoDB extension version mismatch detected, using --ignore-platform-req=ext-mongodb..."
                INSTALL_EXIT_CODE=0
                COMPOSER_ALLOW_SUPERUSER=1 composer install --no-interaction --prefer-dist --optimize-autoloader --no-scripts --ignore-platform-req=ext-mongodb --quiet --no-progress 2>&1 || INSTALL_EXIT_CODE=$?
            fi
            
            # If install still failed, try updating the lock file and retry
            if [ ${INSTALL_EXIT_CODE} -ne 0 ]; then
                log_info "Composer install failed for ${SERVICE}, attempting to update dependencies..."
                # First try to update just the lock file
                COMPOSER_ALLOW_SUPERUSER=1 composer update --lock --no-interaction --no-scripts --quiet --no-progress 2>/dev/null || true
                # If that doesn't work, do a full update
                log_info "Reinstalling dependencies after lock file update..."
                COMPOSER_ALLOW_SUPERUSER=1 composer install --no-interaction --prefer-dist --optimize-autoloader --no-scripts --ignore-platform-req=ext-mongodb --quiet --no-progress 2>&1 || {
                    log_warn "Composer install still failing, attempting full update for ${SERVICE}..."
                    COMPOSER_ALLOW_SUPERUSER=1 composer update --no-interaction --prefer-dist --optimize-autoloader --no-scripts --ignore-platform-req=ext-mongodb --quiet --no-progress
                }
            fi
        fi
    else
        # No lock file, use update to create one (install requires lock file)
        log_info "No composer.lock found for ${SERVICE}, running composer update..."
        # Try without ignore flag first, skip scripts
        COMPOSER_ALLOW_SUPERUSER=1 composer update --no-interaction --prefer-dist --optimize-autoloader --no-scripts --quiet --no-progress 2>&1 || {
            log_info "Composer update failed, trying with --ignore-platform-req=ext-mongodb..."
            COMPOSER_ALLOW_SUPERUSER=1 composer update --no-interaction --prefer-dist --optimize-autoloader --no-scripts --ignore-platform-req=ext-mongodb --quiet --no-progress
        }
    fi

    # Ensure database config file exists with MongoDB configuration
    # This must be done after composer install (so vendor exists) but before artisan commands
    if [ -f "artisan" ]; then
        log_info "Ensuring database.php config file exists with MongoDB configuration..."
        ensure_database_config "$SERVICE_PATH"
    fi

    # Generate application key (after composer install/update and .env is configured)
    if [ -f "artisan" ]; then
        log_info "Generating application key for ${SERVICE}..."
        # Try to generate key, but handle MongoDB connection errors gracefully
        # Some services might try to connect to MongoDB during bootstrap in AppServiceProvider
        # Ensure storage directories exist and have proper permissions before running artisan
        mkdir -p "${SERVICE_PATH}/storage/logs" "${SERVICE_PATH}/storage/framework/cache" "${SERVICE_PATH}/storage/framework/sessions" "${SERVICE_PATH}/storage/framework/views" 2>/dev/null || true
        chmod -R 775 "${SERVICE_PATH}/storage" 2>/dev/null || true
        chown -R www-data:www-data "${SERVICE_PATH}/storage" 2>/dev/null || true
        
        # Clear config cache to ensure new database config is loaded
        php artisan config:clear 2>/dev/null || true
        
        # Capture both stdout and stderr, and check exit code properly
        KEY_GEN_OUTPUT=$(php artisan key:generate --force --quiet 2>&1)
        KEY_GEN_EXIT=$?
        
        # Check for MongoDB connection errors or non-zero exit code
        if [ ${KEY_GEN_EXIT} -ne 0 ] || echo "$KEY_GEN_OUTPUT" | grep -qiE "mongodb|database.*not configured|InvalidArgumentException|connection.*mongodb"; then
            log_warn "Key generation failed (exit code: ${KEY_GEN_EXIT}), setting APP_KEY manually..."
            # Generate a 32-character random key (Laravel format)
            APP_KEY="base64:$(openssl rand -base64 32 | tr -d '\n' | head -c 44)"
            if grep -q "^APP_KEY=" "$ENV_FILE" 2>/dev/null; then
                sed -i "s|^APP_KEY=.*|APP_KEY=${APP_KEY}|" "$ENV_FILE"
            else
                echo "APP_KEY=${APP_KEY}" >> "$ENV_FILE"
            fi
            log_info "APP_KEY set manually for ${SERVICE}"
        else
            log_info "Application key generated successfully for ${SERVICE}"
        fi

        # Generate JWT secret
        log_info "Generating JWT secret for ${SERVICE}..."
        php artisan jwt:secret --force --quiet 2>/dev/null || log_warn "JWT secret generation skipped (not installed)"

        # Run Laravel post-install scripts manually (since we used --no-scripts during composer)
        log_info "Running Laravel post-install scripts for ${SERVICE}..."
        # Use APP_ENV=local to avoid database connection checks during package discovery
        APP_ENV=local composer run-script post-autoload-dump --no-interaction --quiet 2>/dev/null || {
            # Fallback: run package:discover directly with local environment
            APP_ENV=local php artisan package:discover --ansi 2>/dev/null || log_warn "Package discovery skipped (non-critical)"
        }
    fi

    # Set permissions
    log_info "Setting permissions for ${SERVICE}..."
    chown -R www-data:www-data "$SERVICE_PATH"
    chmod -R 755 "$SERVICE_PATH"
    chmod -R 775 "${SERVICE_PATH}/storage" 2>/dev/null || true
    chmod -R 775 "${SERVICE_PATH}/bootstrap/cache" 2>/dev/null || true

    log_info "${SERVICE} setup completed"
done

################################################################################
# 10.1. Setup Supervisor Queue Workers
################################################################################
log_info "Step 10.1/13: Setting up Supervisor queue workers for Laravel services..."

# List of services that need queue workers
QUEUE_SERVICES=("back" "notification-service" "user-service" "regulator-service" "strategic-plan-service" "kpis")

# Create Supervisor config directory if it doesn't exist
mkdir -p /etc/supervisor/conf.d

# Create logs directory
mkdir -p "${PROJECT_DIR}/logs"
chown -R www-data:www-data "${PROJECT_DIR}/logs"

# Create queue worker configuration for each service
for SERVICE in "${QUEUE_SERVICES[@]}"; do
    SERVICE_PATH="${PROJECT_DIR}/${SERVICE}"
    
    if [ ! -d "$SERVICE_PATH" ]; then
        log_warn "Service directory not found: ${SERVICE_PATH}, skipping queue worker setup"
        continue
    fi
    
    log_info "Creating Supervisor config for ${SERVICE} queue worker..."
    
    # Create Supervisor config file
    cat > /etc/supervisor/conf.d/grc-${SERVICE}-queue.conf <<EOF
[program:grc-${SERVICE}-queue]
process_name=%(program_name)s_%(process_num)02d
command=php ${SERVICE_PATH}/artisan queue:work mongodb --sleep=3 --tries=3 --max-time=3600
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
user=www-data
numprocs=2
redirect_stderr=true
stdout_logfile=${PROJECT_DIR}/logs/${SERVICE}-queue.log
stopwaitsecs=3600
EOF

    log_info "Supervisor config created for ${SERVICE} queue worker"
done

# Reload Supervisor configuration
supervisorctl reread
supervisorctl update

log_info "Queue workers configured and started for all services"

################################################################################
# 11. Setup Frontend (Vue.js)
################################################################################
log_info "Step 11/13: Setting up Frontend (Vue.js)..."

FRONT_PATH="${PROJECT_DIR}/front"

if [ -d "$FRONT_PATH" ]; then
    cd "$FRONT_PATH"

    # Determine protocol and base URL
    PROTOCOL="http"
    if [[ "$SERVER_DOMAIN" != *"127.0.0.1"* ]] && [[ "$SERVER_DOMAIN" != *"localhost"* ]] && [[ ! "$SERVER_DOMAIN" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        PROTOCOL="https"
    fi
    BASE_URL="${PROTOCOL}://${SERVER_DOMAIN}"
    API_BASE_URL="${BASE_URL}/api"
    WS_URL="${PROTOCOL}://${SERVER_DOMAIN}"
    
    log_info "Configuring frontend with domain: ${SERVER_DOMAIN}"

    # Update vue.config.js to define environment variables
    if [ -f "vue.config.js" ]; then
        log_info "Configuring vue.config.js..."
        cat > vue.config.js <<EOF
const { defineConfig } = require('@vue/cli-service')
module.exports = defineConfig({
  transpileDependencies: [
    'vuetify'
  ],
  chainWebpack: config => {
    config.plugin('define').tap(definitions => {
      Object.assign(definitions[0], {
        'process.env': {
          ...definitions[0]['process.env'],
          BASEPATH: JSON.stringify('${API_BASE_URL}'),
          USERSERVICE: JSON.stringify('${API_BASE_URL}/user-service'),
          WEBSOCKET_URL: JSON.stringify('${WS_URL}'),
          APP_URL: JSON.stringify('${BASE_URL}')
        }
      })
      return definitions
    })
  }
})
EOF
    else
        log_warn "vue.config.js not found, creating it..."
        cat > vue.config.js <<EOF
const { defineConfig } = require('@vue/cli-service')
module.exports = defineConfig({
  transpileDependencies: [
    'vuetify'
  ],
  chainWebpack: config => {
    config.plugin('define').tap(definitions => {
      Object.assign(definitions[0], {
        'process.env': {
          ...definitions[0]['process.env'],
          BASEPATH: JSON.stringify('${API_BASE_URL}'),
          USERSERVICE: JSON.stringify('${API_BASE_URL}/user-service'),
          WEBSOCKET_URL: JSON.stringify('${WS_URL}'),
          APP_URL: JSON.stringify('${BASE_URL}')
        }
      })
      return definitions
    })
  }
})
EOF
    fi

    # Create or update .env file if needed
    if [ -f ".env.example" ]; then
        if [ ! -f ".env" ]; then
            cp .env.example .env
        fi
        # Update .env with domain configuration
        if grep -q "^VITE_API_BASE_URL=" .env 2>/dev/null; then
            sed -i "s|^VITE_API_BASE_URL=.*|VITE_API_BASE_URL=${API_BASE_URL}|" .env
        else
            echo "VITE_API_BASE_URL=${API_BASE_URL}" >> .env
        fi
        if grep -q "^VITE_APP_URL=" .env 2>/dev/null; then
            sed -i "s|^VITE_APP_URL=.*|VITE_APP_URL=${BASE_URL}|" .env
        else
            echo "VITE_APP_URL=${BASE_URL}" >> .env
        fi
    fi

    log_info "Installing npm dependencies..."
    npm install --silent --no-progress

    log_info "Building frontend for production..."
    npm run build --silent

    # Set permissions
    chown -R www-data:www-data "$FRONT_PATH"
    chmod -R 755 "$FRONT_PATH"

    log_info "Frontend setup completed"
else
    log_warn "Frontend directory not found: ${FRONT_PATH}"
fi

################################################################################
# 12. Create MongoDB Databases
################################################################################
log_info "Step 12/13: Creating MongoDB databases..."

# Create databases using mongosh
mongosh --eval "
    use grc;
    db.createCollection('system');
    use notification_grc_db;
    db.createCollection('notifications');
    use GRC_USER_SERVICE;
    db.createCollection('users');
    use GRC_Regulator_Service;
    db.createCollection('regulators');
    use grc-kpi;
    db.createCollection('kpis');
"

log_info "MongoDB databases created"

################################################################################
# 12.5. Configure /etc/hosts for service hostnames
################################################################################
log_info "Step 12.4/13: Configuring /etc/hosts for service hostnames..."

# Backup /etc/hosts
cp /etc/hosts /etc/hosts.backup.$(date +%Y%m%d_%H%M%S)

# Service hostname mappings (service name -> hostname for /etc/hosts)
declare -A SERVICE_HOSTNAMES=(
    ["back"]="back-service"
    ["notification-service"]="notification-service"
    ["user-service"]="user-service"
    ["regulator-service"]="regulator-service"
    ["strategic-plan-service"]="strategic-plan-service"
    ["kpis"]="kpi-service"
)

log_info "Adding service hostnames to /etc/hosts..."

# Remove existing GRC service entries if any
sed -i '/# GRC Microservices Hostnames/,/# End GRC Microservices Hostnames/d' /etc/hosts

# Add GRC service hostnames
echo "" >> /etc/hosts
echo "# GRC Microservices Hostnames" >> /etc/hosts
for SERVICE in "${!SERVICE_HOSTNAMES[@]}"; do
    HOSTNAME="${SERVICE_HOSTNAMES[$SERVICE]}"
    # Remove any existing entry for this hostname first
    sed -i "/[[:space:]]${HOSTNAME}[[:space:]]*$/d" /etc/hosts
    sed -i "/^127\.0\.0\.1[[:space:]]\+${HOSTNAME}$/d" /etc/hosts
    # Add new entry
    echo "127.0.0.1 ${HOSTNAME}" >> /etc/hosts
    log_info "Added hostname: ${HOSTNAME} -> 127.0.0.1"
done
echo "# End GRC Microservices Hostnames" >> /etc/hosts

log_info "/etc/hosts configured with service hostnames"

################################################################################
# 12.5. Configure Nginx
################################################################################
log_info "Step 12.5/13: Configuring Nginx reverse proxy..."

# Determine protocol
PROTOCOL="http"
if [[ "$SERVER_DOMAIN" != *"127.0.0.1"* ]] && [[ "$SERVER_DOMAIN" != *"localhost"* ]] && [[ ! "$SERVER_DOMAIN" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    PROTOCOL="https"
fi

# Create Nginx configuration
NGINX_CONF="/etc/nginx/sites-available/grc"
NGINX_ENABLED="/etc/nginx/sites-enabled/grc"

log_info "Creating Nginx configuration for ${SERVER_DOMAIN}..."

# Remove default nginx site if exists
rm -f /etc/nginx/sites-enabled/default

# Create GRC Nginx configuration
cat > "$NGINX_CONF" <<EOF
# GRC Microservices Nginx Configuration
# Domain: ${SERVER_DOMAIN}

# Upstream definitions for Laravel services using hostnames from /etc/hosts
upstream grc_back {
    server back-service:9090;
}

upstream grc_notification_service {
    server notification-service:6060;
}

upstream grc_user_service {
    server user-service:7070;
}

upstream grc_regulator_service {
    server regulator-service:3030;
}

upstream grc_strategic_plan_service {
    server strategic-plan-service:8080;
}

upstream grc_kpis {
    server kpi-service:5050;
}

# WebSocket upstream for Laravel Reverb
upstream grc_websocket {
    server notification-service:9000;
}

server {
    listen 80;
    server_name ${SERVER_DOMAIN} _;

    # Frontend static files
    root ${PROJECT_DIR}/front/dist;
    index index.html;

    # Frontend routes
    location / {
        try_files \$uri \$uri/ /index.html;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }

    # API routes - Back service
    location /api/back {
        rewrite ^/api/back/(.*) /\$1 break;
        proxy_pass http://grc_back;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_redirect off;
    }

    # API routes - Notification service
    location /api/notification-service {
        rewrite ^/api/notification-service/(.*) /\$1 break;
        proxy_pass http://grc_notification_service;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_redirect off;
    }

    # API routes - User service
    location /api/user-service {
        rewrite ^/api/user-service/(.*) /\$1 break;
        proxy_pass http://grc_user_service;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_redirect off;
    }

    # API routes - Regulator service
    location /api/regulator-service {
        rewrite ^/api/regulator-service/(.*) /\$1 break;
        proxy_pass http://grc_regulator_service;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_redirect off;
    }

    # API routes - Strategic plan service
    location /api/strategic-plan-service {
        rewrite ^/api/strategic-plan-service/(.*) /\$1 break;
        proxy_pass http://grc_strategic_plan_service;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_redirect off;
    }

    # API routes - KPIs service
    location /api/kpis {
        rewrite ^/api/kpis/(.*) /\$1 break;
        proxy_pass http://grc_kpis;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_redirect off;
    }

    # WebSocket connection for Laravel Reverb
    location /app {
        proxy_pass http://grc_websocket;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 86400;
    }

    # Static files caching
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|woff|woff2|ttf|svg|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Max upload size
    client_max_body_size 100M;
}

EOF

# Enable the site
ln -sf "$NGINX_CONF" "$NGINX_ENABLED"

# Test Nginx configuration
log_info "Testing Nginx configuration..."
nginx -t >/dev/null 2>&1
if [ $? -eq 0 ]; then
    log_info "Nginx configuration is valid"
    systemctl reload nginx >/dev/null 2>&1 || systemctl start nginx >/dev/null 2>&1
    systemctl enable nginx >/dev/null 2>&1
    log_info "Nginx started and enabled"
else
    log_warn "Nginx configuration test failed. Please check the configuration manually."
    nginx -t
fi

################################################################################
# 13. Final Steps
################################################################################
log_info "Step 13/13: Finalizing installation..."
log_info "Installation completed successfully!"
echo ""
echo "=========================================="
echo "GRC Microservices Installation Summary"
echo "=========================================="
echo ""
echo "Installed Components:"
echo "  - PHP ${PHP_VERSION}"
echo "  - Composer $(composer --version --no-ansi 2>/dev/null | head -n1 || echo 'installed')"
echo "  - MongoDB ${MONGODB_VERSION}"
echo "  - Node.js $(node -v)"
echo "  - npm $(npm -v)"
echo "  - Nginx (configured with reverse proxy)"
echo "  - Supervisor (queue workers configured)"
echo ""
echo "Domain/Server: ${SERVER_DOMAIN}"
echo ""
echo "Services Setup:"
echo "  - back (Port 9090)"
echo "  - notification-service (Port 6060)"
echo "  - user-service (Port 7070)"
echo "  - regulator-service (Port 3030)"
echo "  - strategic-plan-service (Port 8080)"
echo "  - kpis (Port 5050)"
echo "  - front (Vue.js) - Built and configured"
echo ""
echo "MongoDB Databases Created:"
echo "  - grc"
echo "  - notification_grc_db"
echo "  - GRC_USER_SERVICE"
echo "  - GRC_Regulator_Service"
echo "  - grc-kpi"
echo ""
echo "Nginx Reverse Proxy Configuration:"
echo "  - Frontend: ${PROTOCOL}://${SERVER_DOMAIN}/"
echo "  - API Back: ${PROTOCOL}://${SERVER_DOMAIN}/api/back"
echo "  - API Notification: ${PROTOCOL}://${SERVER_DOMAIN}/api/notification-service"
echo "  - API User: ${PROTOCOL}://${SERVER_DOMAIN}/api/user-service"
echo "  - API Regulator: ${PROTOCOL}://${SERVER_DOMAIN}/api/regulator-service"
echo "  - API Strategic Plan: ${PROTOCOL}://${SERVER_DOMAIN}/api/strategic-plan-service"
echo "  - API KPIs: ${PROTOCOL}://${SERVER_DOMAIN}/api/kpis"
echo "  - WebSocket: ${PROTOCOL}://${SERVER_DOMAIN}/app"
echo ""
echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo ""
echo "1. Environment variables have been configured automatically"
echo "   All .env files have been set up with domain: ${SERVER_DOMAIN}"
echo ""
echo "2. Start the services using the provided script:"
echo "   bash ${PROJECT_DIR}/start-all-services.sh"
echo ""
echo "3. Check service status:"
echo "   bash ${PROJECT_DIR}/check-services-status.sh"
echo ""
echo "4. Queue workers are configured via Supervisor:"
echo "   Check status: sudo supervisorctl status"
echo "   View logs: tail -f ${PROJECT_DIR}/logs/*-queue.log"
echo ""
echo "5. Access the application:"
echo "   Frontend: ${PROTOCOL}://${SERVER_DOMAIN}"
echo ""
echo "6. Configure SSL certificates for production (if using domain):"
echo "   See INSTALLATION.md for SSL setup instructions"
echo ""
echo "For detailed instructions, see:"
echo "  ${PROJECT_DIR}/INSTALLATION.md"
echo ""
echo "=========================================="

