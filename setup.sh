#!/bin/bash

# ============================================================================
# Microservices Infrastructure - Master Setup Script
# ============================================================================
# This script performs complete infrastructure initialization:
# 1. Creates Docker network
# 2. Creates all directory structures
# 3. Creates placeholder config files
# 4. Sets proper permissions
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
NETWORK_NAME="global-infra"
SUBNET="172.20.0.0/16"
GATEWAY="172.20.0.1"

# ============================================================================
# Helper Functions
# ============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

# ============================================================================
# Main Setup
# ============================================================================

print_header "Microservices Infrastructure Setup"

# Check if Docker is running
print_info "Checking Docker status..."
if ! docker info > /dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker first."
    exit 1
fi
print_success "Docker is running"

# ============================================================================
# Step 1: Create Docker Network
# ============================================================================

print_header "Step 1: Creating Docker Network"

if docker network ls | grep -q "$NETWORK_NAME"; then
    print_warning "Network '$NETWORK_NAME' already exists."
    read -p "Do you want to remove and recreate it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Removing existing network..."
        docker network rm "$NETWORK_NAME" 2>/dev/null || {
            print_error "Failed to remove network. Containers may still be connected."
            print_info "Run 'docker network inspect $NETWORK_NAME' to see connected containers."
            exit 1
        }
        print_success "Network removed"
    else
        print_info "Using existing network"
    fi
fi

if ! docker network ls | grep -q "$NETWORK_NAME"; then
    print_info "Creating external Docker network: $NETWORK_NAME"
    docker network create \
        --driver bridge \
        --subnet="$SUBNET" \
        --gateway="$GATEWAY" \
        --opt "com.docker.network.bridge.name=br-global-infra" \
        --opt "com.docker.network.bridge.enable_ip_masquerade=true" \
        --opt "com.docker.network.bridge.enable_icc=true" \
        --label "project=microservices-infra" \
        --label "environment=local-dev" \
        "$NETWORK_NAME" > /dev/null
    
    print_success "Network created successfully"
    print_info "Network: $NETWORK_NAME"
    print_info "Subnet: $SUBNET"
    print_info "Gateway: $GATEWAY"
fi

# ============================================================================
# Step 2: Create Directory Structure
# ============================================================================

print_header "Step 2: Creating Directory Structure"

print_info "Creating directories for all stacks..."

# Array of all directories to create
directories=(
    # 01-data stack
    "01-data/postgres/init"
    "01-data/postgres/data"
    "01-data/mongo/init"
    "01-data/mongo/data"
    "01-data/redis/data"
    "01-data/elasticsearch/data"
    "01-data/elasticsearch/config"
    "01-data/minio/data"
    "01-data/minio/config"
    "01-data/config/postgres"
    "01-data/config/redis"
    "01-data/config/mongo"
    
    # 02-messaging stack
    "02-messaging/kafka/data"
    "02-messaging/kafka/config"
    
    # 03-observability stack
    "03-observability/prometheus/data"
    "03-observability/prometheus/alerts"
    "03-observability/prometheus/config"
    "03-observability/loki/data"
    "03-observability/loki/config"
    "03-observability/tempo/data"
    "03-observability/tempo/config"
    "03-observability/grafana/data"
    "03-observability/grafana/provisioning/datasources"
    "03-observability/grafana/provisioning/dashboards"
    "03-observability/otel-collector/config"
    
    # 04-gateway stack
    "04-gateway/kong/plugins"
    "04-gateway/kong/declarative"
    "04-gateway/keycloak/themes"
    "04-gateway/keycloak/import"
    "04-gateway/nginx/conf.d"
    "04-gateway/nginx/ssl"
    "04-gateway/nginx/html"
    
    # 05-ops stack
    "05-ops/jenkins/data"
    "05-ops/jenkins/casc"
    "05-ops/portainer/data"
    "05-ops/trivy/cache"
)

for dir in "${directories[@]}"; do
    mkdir -p "$dir"
    print_success "Created: $dir"
done

# ============================================================================
# Step 3: Create Configuration Files (Placeholders)
# ============================================================================

print_header "Step 3: Creating Configuration Files"

print_info "Creating placeholder configuration files..."
print_warning "Note: These are empty placeholders to prevent Docker from creating directories"
print_warning "You must populate them with actual configuration content"

# Array of configuration files to create
config_files=(
    # PostgreSQL
    "01-data/postgres/init/01-init-databases.sh"
    "01-data/config/postgres/postgresql.conf"
    
    # Redis
    "01-data/config/redis/redis.conf"
    
    # MongoDB
    "01-data/config/mongo/mongod.conf"
    
    # Elasticsearch
    "01-data/elasticsearch/config/elasticsearch.yml"
    
    # Prometheus
    "03-observability/prometheus/config/prometheus.yml"
    
    # Loki
    "03-observability/loki/config/loki-config.yaml"
    
    # Tempo
    "03-observability/tempo/config/tempo-config.yaml"
    
    # OpenTelemetry Collector
    "03-observability/otel-collector/config/otel-collector-config.yaml"
    
    # Grafana
    "03-observability/grafana/provisioning/datasources/datasources.yml"
    "03-observability/grafana/provisioning/dashboards/dashboards.yml"
    
    # Kong
    "04-gateway/kong/declarative/kong.yml"
    
    # Keycloak
    "04-gateway/keycloak/import/realm-export.json"
    
    # Nginx
    "04-gateway/nginx/nginx.conf"
    "04-gateway/nginx/conf.d/default.conf"
    "04-gateway/nginx/html/index.html"
    
    # Jenkins
    "05-ops/jenkins/casc/jenkins.yaml"
)

for file in "${config_files[@]}"; do
    if [ ! -f "$file" ]; then
        touch "$file"
        print_success "Created: $file"
    else
        print_info "Already exists: $file"
    fi
done

# ============================================================================
# Step 4: Create .gitkeep Files
# ============================================================================

print_header "Step 4: Creating .gitkeep Files"

print_info "Creating .gitkeep files for empty directories..."

# Directories that should have .gitkeep
gitkeep_dirs=(
    "01-data/postgres/data"
    "01-data/mongo/data"
    "01-data/redis/data"
    "01-data/elasticsearch/data"
    "01-data/minio/data"
    "02-messaging/kafka/data"
    "02-messaging/zookeeper/data"
    "02-messaging/zookeeper/logs"
    "03-observability/prometheus/data"
    "03-observability/loki/data"
    "03-observability/tempo/data"
    "03-observability/grafana/data"
    "05-ops/jenkins/data"
    "05-ops/portainer/data"
    "05-ops/trivy/cache"
)

for dir in "${gitkeep_dirs[@]}"; do
    touch "$dir/.gitkeep"
    print_success "Created: $dir/.gitkeep"
done

# ============================================================================
# Step 5: Set Permissions
# ============================================================================

print_header "Step 5: Setting Permissions"

print_info "Making scripts executable..."

# Make all shell scripts executable
find . -type f -name "*.sh" -exec chmod +x {} \;
print_success "All .sh files are now executable"

# Make init script specifically executable
if [ -f "01-data/postgres/init/01-init-databases.sh" ]; then
    chmod +x "01-data/postgres/init/01-init-databases.sh"
    print_success "PostgreSQL init script is executable"
fi

# ============================================================================
# Step 6: Create Essential Helper Files
# ============================================================================

print_header "Step 6: Creating Helper Files"

# Create .env.example if it doesn't exist
if [ ! -f ".env.example" ]; then
    print_info "Creating .env.example template..."
    cat > .env.example << 'EOF'
# Microservices Infrastructure - Environment Variables Template
# Copy this file to .env and update with your values
# DO NOT commit .env to version control

# Network Configuration
NETWORK_NAME=global-infra
COMPOSE_PROJECT_NAME=microservices-infra

# PostgreSQL (Centralized)
POSTGRES_VERSION=18.4
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_USER=admin
POSTGRES_PASSWORD=change_me_admin_password
POSTGRES_DB=main_db
POSTGRES_MAX_CONNECTIONS=200

# Keycloak Database
KEYCLOAK_DB_NAME=keycloak
KEYCLOAK_DB_USER=keycloak
KEYCLOAK_DB_PASSWORD=change_me_keycloak_db_password

# Kong Database
KONG_DB_NAME=kong
KONG_DB_USER=kong
KONG_DB_PASSWORD=change_me_kong_db_password

# Application Database
APP_DB_NAME=app_db
APP_DB_USER=app_user
APP_DB_PASSWORD=change_me_app_db_password

# MongoDB
MONGO_VERSION=9.0
MONGO_INITDB_ROOT_USERNAME=mongoadmin
MONGO_INITDB_ROOT_PASSWORD=change_me_mongo_password

# Redis
REDIS_VERSION=8.2.8
REDIS_PASSWORD=change_me_redis_password
REDIS_MAX_MEMORY=256mb
REDIS_MAX_MEMORY_POLICY=allkeys-lru

# Add other service configurations as needed...
EOF
    print_success "Created .env.example"
fi

# Create .gitignore if it doesn't exist
if [ ! -f ".gitignore" ]; then
    print_info "Creating .gitignore..."
    cat > .gitignore << 'EOF'
# Environment & Secrets
.env
.env.local
*.secret

# Data Directories
*/*/data/
!*/*/data/.gitkeep

# Logs
*.log

# Temporary Files
*.tmp
.DS_Store
EOF
    print_success "Created .gitignore"
fi

# Create README placeholders for each stack if they don't exist
for stack in 01-data 02-messaging 03-observability 04-gateway 05-ops; do
    if [ ! -f "$stack/README.md" ]; then
        echo "# $(basename $stack) Stack" > "$stack/README.md"
        print_success "Created: $stack/README.md"
    fi
done

# ============================================================================
# Step 7: Verify Setup
# ============================================================================

print_header "Step 7: Verification"

print_info "Verifying setup..."

# Check network
if docker network inspect "$NETWORK_NAME" > /dev/null 2>&1; then
    print_success "Network '$NETWORK_NAME' exists and is accessible"
else
    print_error "Network verification failed"
fi

# Check directory structure
print_info "Checking directory structure..."
if [ -d "01-data" ] && [ -d "02-messaging" ] && [ -d "03-observability" ] && [ -d "04-gateway" ] && [ -d "05-ops" ]; then
    print_success "All stack directories exist"
else
    print_error "Some stack directories are missing"
fi

# Count created files
config_count=$(find . -type f \( -name "*.conf" -o -name "*.yml" -o -name "*.yaml" -o -name "*.json" \) | wc -l)
script_count=$(find . -type f -name "*.sh" | wc -l)

print_info "Configuration files created: $config_count"
print_info "Shell scripts found: $script_count"

# ============================================================================
# Completion Summary
# ============================================================================

print_header "Setup Complete!"

echo -e "${GREEN}✓ Docker network created: $NETWORK_NAME${NC}"
echo -e "${GREEN}✓ Directory structure created (5 stacks)${NC}"
echo -e "${GREEN}✓ Configuration file placeholders created${NC}"
echo -e "${GREEN}✓ Permissions set correctly${NC}"
echo -e "${GREEN}✓ Helper files created${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo -e "  1. Copy .env.example to .env and update passwords:"
echo -e "     ${CYAN}cp .env.example .env && nano .env${NC}"
echo ""
echo -e "  2. Populate configuration files with actual content:"
echo -e "     ${CYAN}# See documentation for each configuration file${NC}"
echo ""
echo -e "  3. Review and customize configurations for your needs"
echo ""
echo -e "  4. Start services:"
echo -e "     ${CYAN}./start-all.sh${NC}"
echo -e "     ${CYAN}# Or individually: cd 01-data && docker compose up -d${NC}"
echo ""
echo -e "${YELLOW}Important Files to Configure:${NC}"
echo -e "  • 01-data/config/postgres/postgresql.conf"
echo -e "  • 01-data/config/redis/redis.conf"
echo -e "  • 01-data/config/mongo/mongod.conf"
echo -e "  • 01-data/postgres/init/01-init-databases.sh"
echo -e "  • 03-observability/prometheus/config/prometheus.yml"
echo -e "  • 03-observability/loki/config/loki-config.yaml"
echo -e "  • 03-observability/otel-collector/config/otel-collector-config.yaml"
echo -e "  • 04-gateway/kong/declarative/kong.yml"
echo ""
echo -e "${GREEN}For detailed configuration guides, see the documentation in each stack directory.${NC}"
echo ""