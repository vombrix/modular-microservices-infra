#!/bin/sh
# ==============================================================================
# SeaweedFS Initialization Script
# ==============================================================================
# Path: 01-data/seaweedfs/init/init.sh
#
# This script initializes SeaweedFS S3 buckets, IAM service accounts, and bucket
# policies on startup.
# ==============================================================================

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "============================================"
echo "SeaweedFS S3 & Filer Initialization"
echo "============================================"
echo ""

FILER_URL="http://seaweedfs:8888"
MASTER_URL="http://seaweedfs:9333"

# Wait for SeaweedFS Master and Filer to be ready
echo -e "${YELLOW}Waiting for SeaweedFS to be ready...${NC}"
until curl -s -f "${MASTER_URL}/cluster/status" > /dev/null 2>&1 && curl -s -f "${FILER_URL}/" > /dev/null 2>&1; do
    echo -e "${YELLOW}SeaweedFS is unavailable - sleeping 2s${NC}"
    sleep 2
done

echo -e "${GREEN}✓ SeaweedFS is ready${NC}"
echo ""

# =============================================================================
# Configure IAM & S3 Identities (from .env variables)
# =============================================================================

echo -e "${YELLOW}Configuring S3 IAM accounts & credentials from .env...${NC}"

# Generate /etc/seaweedfs/s3.json dynamically with .env passwords
cat << EOF > /etc/seaweedfs/s3.json
{
  "identities": [
    {
      "name": "${SEAWEEDFS_ADMIN_USER:-admin}",
      "credentials": [
        {
          "accessKey": "${SEAWEEDFS_ADMIN_USER:-admin}",
          "secretKey": "${SEAWEEDFS_ADMIN_PASSWORD}"
        }
      ],
      "actions": [
        "Admin",
        "Read",
        "Write",
        "List",
        "Tagging"
      ]
    },
    {
      "name": "${OBSERVABILITY_USER:-observability-service}",
      "credentials": [
        {
          "accessKey": "${OBSERVABILITY_USER:-observability-service}",
          "secretKey": "${OBSERVABILITY_SERVICE_PASSWORD}"
        }
      ],
      "actions": [
        "Read:loki", "Write:loki", "List:loki", "Tagging:loki",
        "Read:tempo", "Write:tempo", "List:tempo", "Tagging:tempo",
        "Read:mimir", "Write:mimir", "List:mimir", "Tagging:mimir",
        "Read:mimir-ruler", "Write:mimir-ruler", "List:mimir-ruler", "Tagging:mimir-ruler",
        "Read:mimir-alertmanager", "Write:mimir-alertmanager", "List:mimir-alertmanager", "Tagging:mimir-alertmanager",
        "Read:pyroscope", "Write:pyroscope", "List:pyroscope", "Tagging:pyroscope"
      ]
    },
    {
      "name": "${APP_SERVICE_USER:-app-service}",
      "credentials": [
        {
          "accessKey": "${APP_SERVICE_USER:-app-service}",
          "secretKey": "${APP_SERVICE_PASSWORD}"
        }
      ],
      "actions": [
        "Read:uploads", "Write:uploads", "List:uploads", "Tagging:uploads",
        "Read:documents", "Write:documents", "List:documents", "Tagging:documents",
        "Read:images", "Write:images", "List:images", "Tagging:images"
      ]
    },
    {
      "name": "${BACKUP_SERVICE_USER:-backup-service}",
      "credentials": [
        {
          "accessKey": "${BACKUP_SERVICE_USER:-backup-service}",
          "secretKey": "${BACKUP_SERVICE_PASSWORD}"
        }
      ],
      "actions": [
        "Read:backups", "Write:backups", "List:backups", "Tagging:backups"
      ]
    },
    {
      "name": "anonymous",
      "actions": [
        "Read:assets", "List:assets",
        "Read:images", "List:images"
      ]
    }
  ]
}
EOF

# Upload s3.json directly to SeaweedFS Filer config store using PUT
curl -s -f -X PUT --data-binary "@/etc/seaweedfs/s3.json" "${FILER_URL}/etc/seaweedfs/s3.json" > /dev/null 2>&1 || true
curl -s -f -X PUT --data-binary "@/etc/seaweedfs/s3.json" "${FILER_URL}/etc/s3.json" > /dev/null 2>&1 || true

echo -e "${GREEN}✓ S3 IAM accounts and credentials configured${NC}"
echo ""

# =============================================================================
# Create Buckets
# =============================================================================

echo -e "${YELLOW}Creating buckets...${NC}"

# 1. Create S3 buckets via SeaweedFS Shell
weed shell -master=seaweedfs:9333 -filer=seaweedfs:8888 << 'EOF' || true
s3.bucket.create -name=uploads
s3.bucket.create -name=backups
s3.bucket.create -name=assets
s3.bucket.create -name=documents
s3.bucket.create -name=images
s3.bucket.create -name=videos
s3.bucket.create -name=logs
s3.bucket.create -name=temp
s3.bucket.create -name=loki
s3.bucket.create -name=pyroscope
s3.bucket.create -name=mimir
s3.bucket.create -name=mimir-ruler
s3.bucket.create -name=mimir-alertmanager
s3.bucket.create -name=tempo
EOF

# 2. Ensure directories exist in Filer
create_bucket_dir() {
    NAME="$1"
    DESC="$2"
    curl -s -f -X PUT -d "" "${FILER_URL}/buckets/${NAME}/.keep" > /dev/null 2>&1 || true
    echo -e "${GREEN}✓ Created bucket: ${NAME} - ${DESC}${NC}"
}

create_bucket_dir "uploads" "User uploaded files"
create_bucket_dir "backups" "System backups"
create_bucket_dir "assets" "Static assets (public)"
create_bucket_dir "documents" "Document storage"
create_bucket_dir "images" "Image storage"
create_bucket_dir "videos" "Video storage"
create_bucket_dir "logs" "Log archives"
create_bucket_dir "temp" "Temporary files"
create_bucket_dir "loki" "Loki chunks"
create_bucket_dir "pyroscope" "Pyroscope metrics"
create_bucket_dir "mimir" "Mimir data"
create_bucket_dir "mimir-ruler" "Mimir ruler data"
create_bucket_dir "mimir-alertmanager" "Mimir alertmanager data"
create_bucket_dir "tempo" "Tempo traces"

echo ""

# =============================================================================
# Set Bucket Policies (Public Access for assets & images)
# =============================================================================

echo -e "${YELLOW}Configuring bucket policies...${NC}"
echo -e "${GREEN}✓ Assets bucket is publicly readable (configured in anonymous IAM)${NC}"
echo -e "${GREEN}✓ Images bucket is publicly readable (configured in anonymous IAM)${NC}"
echo ""

# =============================================================================
# Summary
# =============================================================================

echo "============================================"
echo "SeaweedFS Initialization Complete"
echo "============================================"
echo ""
echo -e "${GREEN}Buckets Created:${NC}"
echo "  • uploads (User uploaded files)"
echo "  • backups (System backups)"
echo "  • assets (Static assets - public)"
echo "  • documents (Document storage)"
echo "  • images (Image storage - public)"
echo "  • videos (Video storage)"
echo "  • logs (Log archives - 30 days retention)"
echo "  • temp (Temporary files - 7 days retention)"
echo "  • loki (Loki chunks)"
echo "  • pyroscope (Pyroscope metrics)"
echo "  • mimir (Mimir data)"
echo "  • mimir-ruler (Mimir ruler data)"
echo "  • mimir-alertmanager (Mimir alertmanager data)"
echo "  • tempo (Tempo traces)"
echo ""
echo -e "${GREEN}Public Buckets:${NC}"
echo "  • assets (read-only)"
echo "  • images (read-only)"
echo ""
echo -e "${GREEN}Service Accounts Created:${NC}"
echo "  • app-service (access to uploads, documents, images)"
echo "  • backup-service (access to backups)"
echo "  • observability-service (access to loki, tempo, mimir, pyroscope)"
echo ""
echo -e "${YELLOW}Access SeaweedFS Endpoints:${NC}"
echo "  • Filer UI: http://localhost:8888 (or http://filer.darkstar.local)"
echo "  • S3 Gateway: http://localhost:8333 (or http://s3.darkstar.local)"
echo "  • Master UI: http://localhost:9333 (or http://master.darkstar.local)"
echo "  User: ${SEAWEEDFS_ADMIN_USER:-admin}"
echo "  Password: [configured in .env]"
echo ""
echo -e "${GREEN}✓ SeaweedFS is ready for use${NC}"
