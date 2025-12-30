#!/bin/bash

################################################################################
# PostgreSQL Database Initialization Script
# Description: Creates databases and users for Kong and Keycloak
# Execution: Auto-runs via /docker-entrypoint-initdb.d/ on first container start
################################################################################

set -e  # Exit immediately if a command exits with a non-zero status

# Color codes for logging
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INIT]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

################################################################################
# Environment Variable Validation
################################################################################

if [[ -z "${KONG_DB_NAME}" ]] || [[ -z "${KONG_DB_USER}" ]] || [[ -z "${KONG_DB_PASSWORD}" ]]; then
    log_error "Kong database environment variables are not set"
    exit 1
fi

if [[ -z "${KEYCLOAK_DB_NAME}" ]] || [[ -z "${KEYCLOAK_DB_USER}" ]] || [[ -z "${KEYCLOAK_DB_PASSWORD}" ]]; then
    log_error "Keycloak database environment variables are not set"
    exit 1
fi

################################################################################
# Database Creation Functions
################################################################################

create_kong_database() {
    log_info "Creating Kong database and user..."
    
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
        -- Create Kong user
        DO \$\$
        BEGIN
            IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = '${KONG_DB_USER}') THEN
                CREATE USER ${KONG_DB_USER} WITH PASSWORD '${KONG_DB_PASSWORD}';
            END IF;
        END
        \$\$;
        
        -- Create Kong database
        SELECT 'CREATE DATABASE ${KONG_DB_NAME} OWNER ${KONG_DB_USER}'
        WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${KONG_DB_NAME}')\gexec
        
        -- Grant privileges
        GRANT ALL PRIVILEGES ON DATABASE ${KONG_DB_NAME} TO ${KONG_DB_USER};
        
        -- Connect to Kong database and set up schema permissions
        \c ${KONG_DB_NAME}
        GRANT ALL ON SCHEMA public TO ${KONG_DB_USER};
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${KONG_DB_USER};
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${KONG_DB_USER};
EOSQL
    
    log_success "Kong database created successfully"
}

create_keycloak_database() {
    log_info "Creating Keycloak database and user..."
    
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
        -- Create Keycloak user
        DO \$\$
        BEGIN
            IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = '${KEYCLOAK_DB_USER}') THEN
                CREATE USER ${KEYCLOAK_DB_USER} WITH PASSWORD '${KEYCLOAK_DB_PASSWORD}';
            END IF;
        END
        \$\$;
        
        -- Create Keycloak database
        SELECT 'CREATE DATABASE ${KEYCLOAK_DB_NAME} OWNER ${KEYCLOAK_DB_USER}'
        WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${KEYCLOAK_DB_NAME}')\gexec
        
        -- Grant privileges
        GRANT ALL PRIVILEGES ON DATABASE ${KEYCLOAK_DB_NAME} TO ${KEYCLOAK_DB_USER};
        
        -- Connect to Keycloak database and set up schema permissions
        \c ${KEYCLOAK_DB_NAME}
        GRANT ALL ON SCHEMA public TO ${KEYCLOAK_DB_USER};
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${KEYCLOAK_DB_USER};
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${KEYCLOAK_DB_USER};
EOSQL
    
    log_success "Keycloak database created successfully"
}

create_extensions() {
    log_info "Creating PostgreSQL extensions..."
    
    # Extensions for Kong
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "${KONG_DB_NAME}" <<-EOSQL
        CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
        CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
EOSQL
    
    # Extensions for Keycloak
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "${KEYCLOAK_DB_NAME}" <<-EOSQL
        CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
EOSQL
    
    log_success "Extensions created successfully"
}

################################################################################
# Main Execution
################################################################################

main() {
    log_info "=========================================="
    log_info "Starting Database Initialization"
    log_info "=========================================="
    echo ""
    
    create_kong_database
    echo ""
    
    create_keycloak_database
    echo ""
    
    create_extensions
    echo ""
    
    log_success "=========================================="
    log_success "Database initialization completed!"
    log_success "=========================================="
    log_info "Created databases:"
    log_info "  - ${KONG_DB_NAME} (User: ${KONG_DB_USER})"
    log_info "  - ${KEYCLOAK_DB_NAME} (User: ${KEYCLOAK_DB_USER})"
}

main "$@"